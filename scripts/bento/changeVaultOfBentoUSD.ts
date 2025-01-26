import { ethers } from "hardhat";
import { BentoUSD } from "../../typechain-types";

async function main() {
  // Load deployed BentoUSD address
  const bentoUSDAddress = "0xfeD4BB1f4Ce7C74e23BE2B968E2962431726d4f3";
  const newVaultAddress = "0x2DC4Da4832604f886A81120dB11108057f6D6BAf";
  
  // Get signer
  const [signer] = await ethers.getSigners();
  
  // Get contract instance
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;
  
  console.log("Current BentoUSDVault:", await bentoUSD.bentoUSDVault());
  
  try {
    // Set new vault address
    const tx = await bentoUSD.setBentoUSDVault(newVaultAddress);
    console.log("Transaction sent:", tx.hash);
    
    // Wait for transaction confirmation
    await tx.wait();
    
    console.log("New BentoUSDVault set successfully");
    console.log("New BentoUSDVault:", await bentoUSD.bentoUSDVault());
  } catch (error) {
    console.error("Error setting new vault:", error);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
