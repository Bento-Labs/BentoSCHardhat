import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { 
  VaultCore, 
  BentoUSD, 
  OracleRouter, 
  Generalized4626Strategy,
  EthenaStrategy,
  IERC20,
  IERC4626
} from "../../typechain-types";

export interface VaultFixture {
  vault: VaultCore;
  bentoUSD: BentoUSD;
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
  strategies: {
    USDC: Generalized4626Strategy;
    DAI: Generalized4626Strategy;
    USDT: Generalized4626Strategy;
    USDe: EthenaStrategy;
  };
}

export async function deployVaultFixture(): Promise<VaultFixture> {
  // Get signers
  const [owner, user1, user2] = await ethers.getSigners();

  // Deploy BentoUSD
  const BentoUSD = await ethers.getContractFactory("BentoUSD");
  const bentoUSD = await BentoUSD.deploy();
  await bentoUSD.initialize("BentoUSD", "BUSD", owner.address);

  // Deploy Oracle
  const OracleRouter = await ethers.getContractFactory("OracleRouter");
  const oracle = await OracleRouter.deploy(owner.address);

  // Deploy Vault
  const VaultCore = await ethers.getContractFactory("VaultCore");
  const vault = await VaultCore.deploy();
  await vault.initialize(owner.address);

  // Set BentoUSD and Oracle in Vault
  await vault.setBentoUSD(await bentoUSD.getAddress());
  await vault.setOracleRouter(await oracle.getAddress());

  // Deploy mock tokens and their yield-bearing versions
  const MockToken = await ethers.getContractFactory("MockERC20");
  const MockYieldToken = await ethers.getContractFactory("MockERC4626");

  // Deploy USDC and sUSDC
  const USDC = await MockToken.deploy("USD Coin", "USDC", 6);
  const sUSDC = await MockYieldToken.deploy(
    await USDC.getAddress(),
    "Staked USDC",
    "sUSDC"
  );

  // Deploy DAI and sDAI
  const DAI = await MockToken.deploy("Dai Stablecoin", "DAI", 18);
  const sDAI = await MockYieldToken.deploy(
    await DAI.getAddress(),
    "Staked DAI",
    "sDAI"
  );

  // Deploy USDT and sUSDT
  const USDT = await MockToken.deploy("Tether USD", "USDT", 6);
  const sUSDT = await MockYieldToken.deploy(
    await USDT.getAddress(),
    "Staked USDT",
    "sUSDT"
  );

  // Deploy USDe and sUSDe
  const USDe = await MockToken.deploy("Ethena USDe", "USDe", 18);
  const sUSDe = await MockYieldToken.deploy(
    await USDe.getAddress(),
    "Staked USDe",
    "sUSDe"
  );

  // Deploy strategies
  const Generalized4626Strategy = await ethers.getContractFactory("Generalized4626Strategy");
  const EthenaStrategy = await ethers.getContractFactory("EthenaStrategy");

  const strategies = {
    USDC: await Generalized4626Strategy.deploy(
      await USDC.getAddress(),
      await sUSDC.getAddress(),
      await vault.getAddress()
    ),
    DAI: await Generalized4626Strategy.deploy(
      await DAI.getAddress(),
      await sDAI.getAddress(),
      await vault.getAddress()
    ),
    USDT: await Generalized4626Strategy.deploy(
      await USDT.getAddress(),
      await sUSDT.getAddress(),
      await vault.getAddress()
    ),
    USDe: await EthenaStrategy.deploy(
      await USDe.getAddress(),
      await sUSDe.getAddress(),
      await vault.getAddress()
    )
  };

  // Set up assets in vault
  const weights = {
    USDC: 2500, // 25%
    DAI: 2500,  // 25%
    USDT: 2500, // 25%
    USDe: 2500  // 25%
  };

  // Add assets to vault
  await vault.setAsset(
    await USDC.getAddress(),
    6,
    weights.USDC,
    await sUSDC.getAddress(),
    0, // Generalized4626
    await strategies.USDC.getAddress(),
    ethers.parseUnits("1000", 6)
  );

  await vault.setAsset(
    await DAI.getAddress(),
    18,
    weights.DAI,
    await sDAI.getAddress(),
    0, // Generalized4626
    await strategies.DAI.getAddress(),
    ethers.parseEther("1000")
  );

  await vault.setAsset(
    await USDT.getAddress(),
    6,
    weights.USDT,
    await sUSDT.getAddress(),
    0, // Generalized4626
    await strategies.USDT.getAddress(),
    ethers.parseUnits("1000", 6)
  );

  await vault.setAsset(
    await USDe.getAddress(),
    18,
    weights.USDe,
    await sUSDe.getAddress(),
    1, // Ethena
    await strategies.USDe.getAddress(),
    ethers.parseEther("1000")
  );

  // Set up oracle prices (1:1 for stablecoins)
  await oracle.setPrice(await USDC.getAddress(), ethers.parseEther("1"));
  await oracle.setPrice(await DAI.getAddress(), ethers.parseEther("1"));
  await oracle.setPrice(await USDT.getAddress(), ethers.parseEther("1"));
  await oracle.setPrice(await USDe.getAddress(), ethers.parseEther("1"));

  return {
    vault,
    bentoUSD,
    oracle,
    owner,
    user1,
    user2,
    assets: {
      USDC,
      DAI,
      USDT,
      USDe
    },
    ltTokens: {
      sUSDC,
      sDAI,
      sUSDT,
      sUSDe
    },
    strategies
  };
}