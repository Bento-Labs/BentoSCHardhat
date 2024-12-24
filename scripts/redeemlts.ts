import { ethers } from "hardhat";
import { VaultCore, BentoUSD, OracleRouter, IERC4626 } from "../typechain-types";

async function main() {
  // Get signer
  const [signer] = await ethers.getSigners();

  // Contract addresses
  const vaultAddress = "0x11E5eAD5844d54E4cBa42E4b9037d62019D9668d";
  
  // Get contract instances
  const vault = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;
  const bentoUSDAddress = await vault.bentoUSD();
  const oracleRouterAddress = await vault.oracleRouter();
  const oracleRouter = await ethers.getContractAt("OracleRouter", oracleRouterAddress) as OracleRouter;
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;

  // Amount of BentoUSD to redeem (e.g., 100 BentoUSD)
  const redeemAmount = ethers.parseEther("100");
  const signerBalance = await bentoUSD.balanceOf(signer.address);
  console.log("Signer balance:", signerBalance.toString());

  try {
    // First approve vault to burn our BentoUSD
    console.log("Approving vault to burn BentoUSD...");
    console.log("bentoUSD:", bentoUSDAddress);
    console.log("redeemAmount:", redeemAmount.toString());
    const approveTx = await bentoUSD.approve(vaultAddress, redeemAmount);
    await approveTx.wait();
    console.log("Approval successful");


    // Get expected LT amounts before redeeming
    const expectedLTAmounts = await vault.getOutputLTAmounts(redeemAmount);
    console.log("Expected LT amounts:", expectedLTAmounts.map(amt => amt.toString()))
    // get current vault balances


    // Print received amounts
    const assets = await vault.getAssets();
    const weights = await vault.getWeights();
    const totalWeight = await vault.totalWeight();
    console.log("Total weight:", totalWeight);
    for (let i = 0; i < assets.length; i++) {
      const assetWeight = weights[i];
      console.log("Asset weight:", assetWeight);
      const partialInputAmount = redeemAmount * assetWeight / totalWeight;
      console.log("Partial input amount:", partialInputAmount);
      const assetAddress = await vault.allAssets(i);
      const assetPrice = await oracleRouter.price(assetAddress);
      console.log("Asset price:", assetPrice);
      console.log("Asset price is less than 1e18:", assetPrice < 1e18);
      const partialInputAmountAfterPrice = partialInputAmount * BigInt(1e18) / BigInt(assetPrice);
      console.log("Partial input amount after price:", partialInputAmountAfterPrice);
      const ltTokenAddress = assets[i].ltToken;
      const ltTokenContract = await ethers.getContractAt("IERC4626", ltTokenAddress) as IERC4626;
      const currentVaultLtBalance = await ltTokenContract.balanceOf(vaultAddress);
      console.log("Current vault LT balance:", currentVaultLtBalance);
      console.log("is vault balance more than expected?", currentVaultLtBalance > expectedLTAmounts[i]);
      const partialOutputAmount = await ltTokenContract.convertToShares(partialInputAmountAfterPrice);
      console.log("Partial output amount:", partialOutputAmount);
      const balance = await ltTokenContract.balanceOf(signer.address);
      console.log(`Received ${balance.toString()} of LT token ${ltTokenAddress}`);
    }


    // Execute redemption
    console.log("Redeeming BentoUSD for liquid staking tokens...");
    const tx = await vault.redeemLTBasket(redeemAmount, {gasLimit: 2_000_000});
    await tx.wait();
    
    console.log("Successfully redeemed BentoUSD for liquid staking tokens!");

  } catch (error) {
    console.error("Error redeeming LTs:", error);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
