import { ethers } from "hardhat";
import { VaultCore, UpgradableProxy } from "../typechain-types";

async function main() {
  // Configuration flags
  const deployNewImplementation = false;
  const setNewImplementation = false;
  const transferImplementation = true;

  // Contract addresses
  const proxyAddress = "0xb120d26E6e36cE295Ec520c9d776EBBAeaf4436a";
  let newImplementationAddress = "0x4Afb649AE3b588608e218972A8a7AfD84DfD8D5d";

  // Get signer
  const [signer] = await ethers.getSigners();
  console.log("Current operator address:", signer.address);

  // Get proxy contract instance
  const proxy = await ethers.getContractAt("UpgradableProxy", proxyAddress) as UpgradableProxy;

  // Log current state
  console.log("Current implementation:", await proxy.implementation());
  console.log("New implementation:", await proxy.newImplementation());
  console.log("Current proxy owner:", await proxy.proxyOwner());

  try {
    if (deployNewImplementation) {
      // Deploy new implementation
      const VaultCore = await ethers.getContractFactory("VaultCore");
      const newImplementationContract = await VaultCore.deploy();

      newImplementationAddress = newImplementationContract.target;
      
      console.log("New implementation deployed at:", newImplementationAddress);
      
    }

    if (setNewImplementation) {
      // Set new implementation
      console.log("Setting new implementation to:", newImplementationAddress);
      const tx = await proxy.setNewImplementation(newImplementationAddress);
      await tx.wait();

      console.log("New implementation set, timelock started");
      console.log("Timelock ends at:", await proxy.timelock());
      console.log("Current time:", Math.floor(Date.now() / 1000));
    }

    if (transferImplementation) {
      // Transfer implementation
      const tx = await proxy.transferImplementation();
      await tx.wait();
      console.log("Implementation transferred to:", await proxy.implementation());
    }
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
