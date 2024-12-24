import { ethers } from "hardhat";
import { VaultCore, BentoUSD, OracleRouter, UpgradableProxy, BentoUSDPlus } from "../typechain-types";

async function main() {
  // Configuration flags
  const deployNewBentoUSDFlag = true;
  const deployNewOracleRouterFlag = true;
  const deployNewVaultFlag = true;
  const setBentoUSDVaultFlag = true;
  const deployBentoUSDPlusFlag = true;

  // Get signer
  const [signer] = await ethers.getSigners();
  const owner = signer.address;

  console.log("deployer address is:", owner);
  console.log("deployer balance is:", await ethers.provider.getBalance(owner), "wei");

  // Deploy BentoUSD
  let bentoUSD: BentoUSD;
  if (deployNewBentoUSDFlag) {
    const BentoUSD = await ethers.getContractFactory("BentoUSD");
    bentoUSD = await BentoUSD.deploy(
      "BentoUSD",
      "BentoUSD",
      owner,
      owner
    ) as BentoUSD;
    await bentoUSD.waitForDeployment();
    console.log("--------------------------------")
    console.log("new BentoUSD deployed at:", await bentoUSD.getAddress());
    console.log("--------------------------------")
    // we create the bentoUSD instance again to get the normal contract instance and not tenderly contract instance
    bentoUSD = await ethers.getContractAt("BentoUSD", await bentoUSD.getAddress()) as BentoUSD;
  } else {
    bentoUSD = await ethers.getContractAt("BentoUSD", "0xF92D7eFab091368966aDBB5f34099833847dcF3b") as BentoUSD;
    console.log("BentoUSD already deployed at:", await bentoUSD.getAddress());
  }

  // Deploy OracleRouter
  let oracle: OracleRouter;
  if (deployNewOracleRouterFlag) {
    const OracleRouter = await ethers.getContractFactory("OracleRouter");
    oracle = await OracleRouter.deploy(owner);
    await oracle.waitForDeployment();
    console.log("--------------------------------")
    console.log("new OracleRouter deployed at:", await oracle.getAddress());
    console.log("--------------------------------")
  } else {
    oracle = await ethers.getContractAt("OracleRouter", "0x8274713D419da3531DfAe1e9ed89d6F9c359cc4d") as OracleRouter;
    console.log("OracleRouter already deployed at:", await oracle.getAddress());
  }

  // Deploy VaultCore implementation and proxy
  let vaultProxy: UpgradableProxy;
  let vaultImpl: VaultCore;

  if (deployNewVaultFlag) {
    const VaultCore = await ethers.getContractFactory("VaultCore");
    vaultImpl = await VaultCore.deploy();
    await vaultImpl.waitForDeployment();
    console.log("--------------------------------")
    console.log("new VaultCore implementation deployed at:", await vaultImpl.getAddress());
    console.log("--------------------------------")

    // Deploy VaultCore proxy
    const vaultData = vaultImpl.interface.encodeFunctionData("initialize", [owner]);
    const UpgradableProxy = await ethers.getContractFactory("UpgradableProxy");
    vaultProxy = await UpgradableProxy.deploy(
      owner,
      await vaultImpl.getAddress(),
      vaultData,
      10,
      true
    );
    await vaultProxy.waitForDeployment();
    console.log("--------------------------------")
    console.log("VaultCore proxy deployed at:", await vaultProxy.getAddress());
    console.log("--------------------------------")
  } else {
    vaultProxy = await ethers.getContractAt("UpgradableProxy", "0xb120d26E6e36cE295Ec520c9d776EBBAeaf4436a") as UpgradableProxy;
    vaultImpl = await ethers.getContractAt("VaultCore", "0xB001e62bA3c8B4797aC1D6950d723b627737a92E") as VaultCore;
    console.log("VaultCore implementation already deployed at:", await vaultImpl.getAddress());
    console.log("VaultCore proxy already deployed at:", await vaultProxy.getAddress());
  }

  if (setBentoUSDVaultFlag) {
    const tx = await bentoUSD.setBentoUSDVault(await vaultProxy.getAddress());
    await tx.wait();
    console.log("Vault in BentoUSD set to:", await vaultProxy.getAddress());
  } else {
    console.log("Vault in BentoUSD already set to:", await vaultProxy.getAddress());
  }

  if (deployBentoUSDPlusFlag) {
    const BentoUSDPlus = await ethers.getContractFactory("BentoUSDPlus");
    const bentoUSDPlus = await BentoUSDPlus.deploy(await bentoUSD.getAddress());
    await bentoUSDPlus.waitForDeployment();
    console.log("--------------------------------")
    console.log("BentoUSDPlus deployed at:", await bentoUSDPlus.getAddress());
    console.log("--------------------------------")
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 