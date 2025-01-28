import { ethers } from "hardhat";
import { VaultCore, UpgradableProxy } from "../../typechain-types";

async function main() {
  // Configuration flags
  // due to the timelock, it is better to call this script in two steps
  // first with true, true, false, then with false, false, true
  // we cannot use time.wait() either, because sometimes the tenderly fork doesn't update correctly for actions in the same script
  const deployNewImplementation = false;
  const setNewImplementation = false;
  const transferImplementation = true;

  // Contract addresses
  const proxyAddress = "0xfc5e87A876f0e1d46f00f201F459c390826f35E2";
  let newImplementationAddress = "0x2371bcd6fB5d0657aC23131cebFd259b96F87dDE";

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
      // we put this here for verification of the implementation contract
      await ethers.getContractAt("VaultCore", await proxy.newImplementation());
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
