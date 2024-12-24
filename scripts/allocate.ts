import { ethers } from "hardhat";
import { VaultCore } from "../typechain-types";

async function main() {
  // Get signer
  const [signer] = await ethers.getSigners();
  console.log("Signer address:", signer.address);

  // Contract addresses
  const vaultAddress = "0x11E5eAD5844d54E4cBa42E4b9037d62019D9668d";
  
  // Get contract instance
  const vault = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;

  // Print supported assets
  const vaultAssets = await vault.getAssets();
  console.log("\n=== Supported Assets ===");
  
  for (let i = 0; i < vaultAssets.length; i++) {
    const asset = await vault.allAssets(i);
    const assetInfo = vaultAssets[i];
    const token = await ethers.getContractAt("IERC20Metadata", asset) as IERC20Metadata;
    const ltToken = assetInfo.ltToken;
    const ltTokenContract = await ethers.getContractAt("IERC20Metadata", ltToken) as IERC20Metadata;

    console.log("\nAsset", i + 1);
    console.log("Name:", await token.name());
    console.log("Symbol:", await token.symbol());
    console.log("Address:", asset);
    console.log("ltToken:", ltToken);
    console.log("ltToken name:", await ltTokenContract.name());
    console.log("ltToken symbol:", await ltTokenContract.symbol());
    console.log("ltToken decimals:", await ltTokenContract.decimals());

    // Get asset balance in vault
    const balance = await token.balanceOf(vaultAddress);
    console.log("Balance in vault:", balance.toString());

    const ltBalance = await ltTokenContract.balanceOf(vaultAddress);
    console.log("ltToken balance in vault:", ltBalance.toString());

  }
  try {
    console.log("Calling allocate...");
    const tx = await vault.allocate();
    console.log("Transaction sent:", tx.hash);
    await tx.wait();
    console.log("Successfully allocated assets");

    // Print asset balances after allocation
    const assets = await vault.getAssets();
    console.log("\n=== Asset Balances After Allocation ===");
    
    for (let i = 0; i < vaultAssets.length; i++) {
        const asset = await vault.allAssets(i);
        const assetInfo = vaultAssets[i];
        const token = await ethers.getContractAt("IERC20Metadata", asset) as IERC20Metadata;
        const ltToken = assetInfo.ltToken;
        const ltTokenContract = await ethers.getContractAt("IERC20Metadata", ltToken) as IERC20Metadata;
    
        console.log("\nAsset", i + 1);
        console.log("Name:", await token.name());
        console.log("Symbol:", await token.symbol());
        console.log("Address:", asset);
        console.log("ltToken:", ltToken);
        console.log("ltToken name:", await ltTokenContract.name());
        console.log("ltToken symbol:", await ltTokenContract.symbol());
        console.log("ltToken decimals:", await ltTokenContract.decimals());
    
        // Get asset balance in vault
        const balance = await token.balanceOf(vaultAddress);
        console.log("Balance in vault:", balance.toString());
    
        const ltBalance = await ltTokenContract.balanceOf(vaultAddress);
        console.log("ltToken balance in vault:", ltBalance.toString());
    
      }
  } catch (error) {
    console.error("Error allocating assets:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });