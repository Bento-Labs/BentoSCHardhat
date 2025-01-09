import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { addresses } from "../scripts/addresses";
import { 
  VaultCore, 
  BentoUSD, 
  OracleRouter, 
  IERC20,
  IERC4626,
  BentoUSDPlus,
  UpgradableProxy
} from "../typechain-types";


export interface VaultFixture {
  vaultCore: VaultCore;
  vaultImpl: VaultCore;
  vault: VaultCore;
  bentoUSD: BentoUSD;
  bentoUSDPlus: BentoUSDPlus;
  oracle: OracleRouter;
  owner: HardhatEthersSigner;
  user1: HardhatEthersSigner;
  user2: HardhatEthersSigner;
  assets: {
    USDC: IERC20;
    DAI: IERC20;
    USDT: IERC20;
    USDe: IERC20;
  };
  ltTokens: {
    sUSDC: IERC4626;
    sDAI: IERC4626;
    sUSDT: IERC4626;
    sUSDe: IERC4626;
  };
}

export async function deployVaultFixture(): Promise<VaultFixture> {
  const [owner, user1, user2] = await ethers.getSigners();

  // Deploy BentoUSD with all constructor parameters
  const BentoUSD = await ethers.getContractFactory("BentoUSD");
  let bentoUSD = await BentoUSD.deploy(
    "BentoUSD",           // name
    "BUSD",              // symbol
    owner.address,       // owner
    owner.address        // delegate
  ) as BentoUSD;

  bentoUSD = await ethers.getContractAt("BentoUSD", await bentoUSD.getAddress()) as BentoUSD;

  // Deploy Oracle
  const OracleRouter = await ethers.getContractFactory("OracleRouter");
  let oracle = await OracleRouter.deploy(owner.address);
  oracle = await ethers.getContractAt("OracleRouter", await oracle.getAddress()) as OracleRouter;
  // Deploy VaultCore implementation and proxy
  const VaultCoreFactory = await ethers.getContractFactory("VaultCore");
  const vaultImpl = await VaultCoreFactory.deploy();

  // Deploy VaultCore proxy
  const vaultData = vaultImpl.interface.encodeFunctionData("initialize", [owner.address]);
  const UpgradableProxy = await ethers.getContractFactory("UpgradableProxy");
  const vaultProxy = await UpgradableProxy.deploy(
    owner.address,
    await vaultImpl.getAddress(),
    vaultData,
    10,
    true
  );

  // Get vault instance through proxy
  const vault = await ethers.getContractAt("VaultCore", await vaultProxy.getAddress()) as VaultCore;

  // Update BentoUSD vault address to the proxy
  await bentoUSD.setBentoUSDVault(await vaultProxy.getAddress());

  // Set BentoUSD and Oracle in Vault
  await vault.setBentoUSD(await bentoUSD.getAddress());
  await vault.setOracleRouter(await oracle.getAddress());

  // Get existing tokens
  const assets = {
    USDC: await ethers.getContractAt("IERC20", addresses.mainnet.USDC),
    DAI: await ethers.getContractAt("IERC20", addresses.mainnet.DAI),
    USDT: await ethers.getContractAt("IERC20", addresses.mainnet.USDT),
    USDe: await ethers.getContractAt("IERC20", addresses.mainnet.USDe)
  };

  const ltTokens = {
    sUSDC: await ethers.getContractAt("IERC4626", addresses.mainnet.sUSDC),
    sDAI: await ethers.getContractAt("IERC4626", addresses.mainnet.sDAI),
    sUSDT: await ethers.getContractAt("IERC4626", addresses.mainnet.sUSDT),
    sUSDe: await ethers.getContractAt("IERC4626", addresses.mainnet.sUSDe)
  };

  // Deploy BentoUSDPlus
  const BentoUSDPlus = await ethers.getContractFactory("BentoUSDPlus");
  const bentoUSDPlus = await BentoUSDPlus.deploy(await bentoUSD.getAddress());

  // Set up assets in vault with weights
  const DAIWeight = 250;
  const USDCWeight = 375;
  const USDTWeight = 125;
  const USDeWeight = 250;

  await vault.setAsset(
    addresses.mainnet.USDC,
    6,
    USDCWeight,
    addresses.mainnet.sUSDC,
    0, // Generalized4626
    ethers.ZeroAddress,
    ethers.parseUnits("1000", 6)
  );

  await vault.setAsset(
    addresses.mainnet.DAI,
    18,
    DAIWeight,
    addresses.mainnet.sDAI,
    0,
    ethers.ZeroAddress,
    ethers.parseEther("1000")
  );

  await vault.setAsset(
    addresses.mainnet.USDT,
    6,
    USDTWeight,
    addresses.mainnet.sUSDT,
    0,
    ethers.ZeroAddress,
    ethers.parseUnits("1000", 6)
  );

  await vault.setAsset(
    addresses.mainnet.USDe,
    18,
    USDeWeight,
    addresses.mainnet.sUSDe,
    1, // Ethena
    ethers.ZeroAddress,
    ethers.parseEther("1000")
  );

  // Set up oracle price feeds
  await oracle.addFeed(
    addresses.mainnet.DAI,
    addresses.mainnet.DAI_USD_FEED,
    86400, // 1 day staleness
    8     // decimals
  );

  await oracle.addFeed(
    addresses.mainnet.USDC,
    addresses.mainnet.USDC_USD_FEED,
    86400,
    8
  );

  await oracle.addFeed(
    addresses.mainnet.USDT,
    addresses.mainnet.USDT_USD_FEED,
    86400,
    8
  );

  await oracle.addFeed(
    addresses.mainnet.USDe,
    addresses.mainnet.USDe_USD_FEED,
    86400,
    8
  );

  return {
    vaultCore: await ethers.getContractAt("VaultCore", await vaultProxy.getAddress()),
    vaultImpl,
    vault,
    bentoUSD,
    bentoUSDPlus,
    oracle,
    owner,
    user1,
    user2,
    assets,
    ltTokens
  };
}

const toBytes32 = (bn: bigint) => {
    // make sure that the number is a bigint
    const _bn = ethers.toBigInt(bn);
    return ethers.zeroPadValue("0x" + _bn.toString(16), 32);
  };

export async function setERC20Balance(tokenAddress: string, account: string, balance: bigint) {
    // The storage slot for the balances mapping in a standard ERC20 contract
    const slotIndex = 0; // This is usually 0, but verify with your contract
  
    // Calculate the storage slot
    const slot = ethers.solidityPackedKeccak256(
      ["address", "uint256"],
      [account, slotIndex]
    );


  
    // Set the balance
    await ethers.provider.send("hardhat_setStorageAt", [
      tokenAddress,
      slot,
      toBytes32(balance)
    ]);
  }

  export function normalizeDecimals(assetDecimals: bigint, amount: bigint) {
    if (assetDecimals < 18) {
      return amount / BigInt(10 ** (Number(18) - Number(assetDecimals)));
    } else if (assetDecimals > 18) {
      return amount * BigInt(10 ** (Number(assetDecimals) - Number(18)));
    }
    return amount;
  }