import { ethers } from "hardhat";
import { VaultCore, BentoUSD, BentoUSDPlus, OracleRouter, IERC20, IERC20Metadata } from "../../typechain-types";

async function main() {
  // Load deployed vault address
  const vaultAddress = "0xb120d26E6e36cE295Ec520c9d776EBBAeaf4436a";
  const bentoUSDPlusAddress = "0x36EDED206feFA357f274b60994a9Afa1c1194aEf";
  
  // Get contract instances
  const vault = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;
  
  // Get BentoUSD and OracleRouter addresses from vault
  const bentoUSDAddress = await vault.bentoUSD();
  const oracleRouterAddress = await vault.oracleRouter();
  
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;
  const bentoUSDPlus = await ethers.getContractAt("BentoUSDPlus", bentoUSDPlusAddress) as BentoUSDPlus;
  const oracle = await ethers.getContractAt("OracleRouter", oracleRouterAddress) as OracleRouter;

  // Print basic vault info
  console.log("=== Vault Configuration ===");
  console.log("Vault address:", vaultAddress);
  console.log("BentoUSD address:", bentoUSDAddress);
  console.log("BentoUSD totalSupply:", (await bentoUSD.totalSupply()).toString());
  console.log("Vault stored in BentoUSD:", await bentoUSD.bentoUSDVault());
  console.log("Oracle Router address:", oracleRouterAddress);
  console.log("Governor address:", await vault.governor());
  console.log("BentoUSD+ address:", bentoUSDPlusAddress);
  console.log("underlying asset:", await bentoUSDPlus.asset());
  
  const bentoUSDPlusMetadata = await ethers.getContractAt("IERC20Metadata", bentoUSDPlusAddress) as IERC20Metadata;
  console.log("BentoUSD+ name:", await bentoUSDPlusMetadata.name());
  console.log("BentoUSD+ symbol:", await bentoUSDPlusMetadata.symbol());
  console.log("BentoUSD+ decimals:", await bentoUSDPlusMetadata.decimals());

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
    console.log("Decimals:", assetInfo.decimals);
    console.log("Weight:", assetInfo.weight.toString(), "%");
    console.log("Strategy:", await vault.assetToStrategy(asset));
    console.log("ltToken:", ltToken);
    console.log("ltToken name:", await ltTokenContract.name());
    console.log("ltToken symbol:", await ltTokenContract.symbol());
    console.log("ltToken decimals:", await ltTokenContract.decimals());

    // Get asset balance in vault
    const balance = await token.balanceOf(vaultAddress);
    console.log("Balance in vault:", balance.toString());

    // Get price from oracle
    try {
      const price = await oracle.price(asset);
      console.log("Price (USD):", price.toString());
    } catch (error) {
      console.log("Price: Error getting price");
    }
  }

  // Inspect specific address
  const addressToInspect = "0x3cA5f5caa07b47c5c6c85afC684A482d2cE9a5e4";
  const desiredMintAmount = ethers.parseEther("10"); // 10 tokens with 18 decimals
  
  console.log("=== Inspecting address:", addressToInspect, "===");
  
  // Get amounts to deposits
  const [amounts, totalAmount] = await vault.getDepositAssetAmounts(desiredMintAmount);
  
  // Check approvals for each asset
  for (let i = 0; i < amounts.length; i++) {
    const amount = amounts[i];
    const asset = await vault.allAssets(i);
    const token = await ethers.getContractAt("IERC20", asset) as IERC20;
    const tokenMetadata = await ethers.getContractAt("IERC20Metadata", asset) as IERC20Metadata;
    
    const allowance = await token.allowance(addressToInspect, vault.address);
    console.log("Allowance for asset", i, ":", allowance.toString());
    console.log("Asset name is", await tokenMetadata.name());
    console.log("Amount to deposit:", amount.toString());
    console.log("Has approved enough:", allowance >= amount);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
