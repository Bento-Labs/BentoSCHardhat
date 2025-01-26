import { ethers } from "hardhat";
import { BentoUSD, BentoUSDPlus } from "../../typechain-types";

async function main() {
  // Get signer
  const [signer] = await ethers.getSigners();

  // Contract addresses from inspectVault.ts
  const bentoUSDAddress = "0xfeD4BB1f4Ce7C74e23BE2B968E2962431726d4f3";
  const bentoUSDPlusAddress = "0x36EDED206feFA357f274b60994a9Afa1c1194aEf";

  // Get contract instances
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;
  const bentoUSDPlus = await ethers.getContractAt("BentoUSDPlus", bentoUSDPlusAddress) as BentoUSDPlus;

  // Amount to stake (e.g., 100 BentoUSD)
  const stakeAmount = ethers.parseEther("1");

  try {
    // First approve BentoUSDPlus to spend our BentoUSD
    console.log("Approving BentoUSDPlus to spend BentoUSD...");
    const approveTx = await bentoUSD.approve(bentoUSDPlusAddress, stakeAmount);
    await approveTx.wait();
    console.log("Approval successful");

    // Now deposit BentoUSD into BentoUSDPlus vault
    console.log("Depositing BentoUSD into vault...");
    const depositTx = await bentoUSDPlus.deposit(stakeAmount, signer.address);
    await depositTx.wait();
    
    // Get balance of BentoUSD+ tokens
    const balance = await bentoUSDPlus.balanceOf(signer.address);
    console.log("Deposit successful!");
    console.log("BentoUSD+ balance:", ethers.formatEther(balance));
    
  } catch (error) {
    console.error("Error staking BentoUSD:", error);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
