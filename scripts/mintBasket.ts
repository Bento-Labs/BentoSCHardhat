import { ethers } from "hardhat";
import { addresses } from "./addresses";
import { VaultCore, BentoUSD } from "../typechain-types";

async function main() {
  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log("Signer address:", signer.address);

  // Get the VaultCore contract instance
  const vaultAddress = "0x1f26Cb844f42690b368f99D3d6C75DBe205f7732";
  console.log("Vault address:", vaultAddress);
  const vaultCore = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;
  const bentoUSDAddress = await vaultCore.bentoUSD();
  console.log("BentoUSD address:", bentoUSDAddress);
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;

  // Amount to deposit in USD (with 18 decimals)
  const depositAmount = ethers.parseEther("1000"); // 1000 USD
  
  // Set minimum BentoUSD amount (e.g., 99% of deposit to account for slippage)
  const minimumBentoUSD = depositAmount * BigInt(99) / BigInt(100);
  console.log("0")
  const bentoUSDBalanceBefore = await bentoUSD.balanceOf(signer.address);
  console.log("1")

  const assets = ["USDC", "DAI", "USDT", "USDe"];
  const depositAmounts = await vaultCore.getDepositAssetAmounts(depositAmount);
  console.log(depositAmounts);
  for (let i = 0; i < assets.length; i++) {
    const asset = assets[i];
    const token = await ethers.getContractAt("IERC20", addresses.mainnet[asset]);
    console.log(`approving asset ${asset}`)
    const depositAmount = depositAmounts[0][i];

    const allowance = await token.allowance(signer.address, vaultAddress);
    if (allowance < depositAmount * BigInt(2)) {
        let tx = await token.approve(vaultAddress, 0);
        await tx.wait();
        tx = await token.approve(vaultAddress, depositAmount * BigInt(2));
        await tx.wait();
    }
  }

  // check allowances
  for (let i = 0; i < assets.length; i++) {
    const asset = assets[i];
    const token = await ethers.getContractAt("IERC20", addresses.mainnet[asset]);
    const allowance = await token.allowance(signer.address, vaultAddress);
    console.log(`Allowance for ${asset}:`, allowance.toString());
  }

  console.log("Approved all assets");

  // Execute mintBasket transaction
  try {
    const tx = await vaultCore.mintBasket(
        signer.address,
      depositAmount,
      minimumBentoUSD
    );
    
    console.log("Transaction sent:", tx.hash);
    await tx.wait();
    console.log("Successfully minted basket");
    const bentoUSDBalanceAfter = await bentoUSD.balanceOf(signer.address);
    console.log("BentoUSD balance after:", bentoUSDBalanceAfter.toString());
    console.log("received BentoUSD:", bentoUSDBalanceAfter - bentoUSDBalanceBefore);
  } catch (error) {
    console.error("Error minting basket:", error);
  }

  // check lt balances of the vault
  for (let i = 0; i < assets.length; i++) {
    const asset = assets[i];
    const assetInfo = await vaultCore.assetToAssetInfo(addresses.mainnet[asset]);
    const ltToken = await ethers.getContractAt("IERC20", assetInfo.ltToken);
    const tokenBalance = await (await ethers.getContractAt("IERC20", addresses.mainnet[asset])).balanceOf(vaultAddress);
    const ltBalance = await ltToken.balanceOf(vaultAddress);
    console.log(`token balance for ${asset}:`, tokenBalance.toString());
    console.log(`lt token balance for ${asset}:`, ltBalance.toString());
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
