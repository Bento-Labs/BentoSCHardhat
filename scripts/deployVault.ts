import { ethers } from "hardhat";
import { VaultCore, BentoUSD, OracleRouter, UpgradableProxy, BentoUSDPlus } from "../typechain-types";

async function main() {
  // Configuration flags
  const deployNewBentoUSDFlag = false;
  const deployNewOracleRouterFlag = false;
  const deployNewVaultFlag = false;
  const setBentoUSDVaultFlag = false;
  const deployBentoUSDPlusFlag = false;
  const deployNewVaultInspectorFlag = true;

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
    bentoUSD = await ethers.getContractAt("BentoUSD", "0x0d34325E9357908C00240d08380d82a79a60a2a4") as BentoUSD;
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
    oracle = await ethers.getContractAt("OracleRouter", "0x0A7383cc00E2b886a65e024CD1B3dC99A601B858") as OracleRouter;
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
    vaultProxy = await ethers.getContractAt("UpgradableProxy", "0x1f26Cb844f42690b368f99D3d6C75DBe205f7732") as UpgradableProxy;
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

  if (deployNewVaultInspectorFlag) {
    const VaultInspector = await ethers.getContractFactory("VaultInspector");
    const vaultInspector = await VaultInspector.deploy(await vaultProxy.getAddress());
    await vaultInspector.waitForDeployment();
    console.log("--------------------------------")
    console.log("VaultInspector deployed at:", await vaultInspector.getAddress());
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