import { ethers } from "hardhat";
import { VaultCore, BentoUSD, OracleRouter, IERC4626, VaultInspector } from "../typechain-types";
// script to call the function 
async function main() {
  // Get signer
  const [signer] = await ethers.getSigners();

  // Contract addresses
  const vaultAddress = "0x1f26Cb844f42690b368f99D3d6C75DBe205f7732";
  const vault = await ethers.getContractAt("VaultCore", vaultAddress);
  const userAddress = signer.address;
  const ethenaWalletProxyAddress = await vault.userToEthenaWalletProxy(userAddress);
  console.log("Ethena wallet proxy address:", ethenaWalletProxyAddress);
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
