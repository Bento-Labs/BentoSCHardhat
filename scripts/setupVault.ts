import { ethers } from "hardhat";
import { VaultCore, BentoUSD, OracleRouter, Generalized4626Strategy } from "../typechain-types";
import { addresses } from "./addresses";

async function main() {
  // Configuration flags
  const setBentoUSD = true;
  const setOracleRouter = true;
  const setAssets = true;
  const setAssetPriceFeeds = true;
  const deployStrategies = true;
  const setAssetStrategies = true;
  const setLTToken = false;

  // Get signer
  const [signer] = await ethers.getSigners();
  const owner = signer.address;

  // Contract addresses
  const vaultAddress = "0x6ae08082387AaBcA74830054B1f3ba8a0571F9c6";
  const bentoUSDAddress = "0xE133Db4B5D0a6c69F05452E294de809e5b59e5f5";
  const oracleRouterAddress = "0x6BfB50ce7f9D383b713A399f453AF8290cf14a74";

  // Asset addresses from your Addresses.sol equivalent
  const DAIAddress = addresses.mainnet.DAI;
  const USDCAddress = addresses.mainnet.USDC;
  const USDTAddress = addresses.mainnet.USDT;
  const USDeAddress = addresses.mainnet.USDe;

  // Asset weights
  const DAIWeight = 250;
  const USDCWeight = 375;
  const USDTWeight = 125;
  const USDeWeight = 250;

  // Price feed addresses
  const DAI_USD_FEED = addresses.mainnet.DAI_USD_FEED;
  const USDC_USD_FEED = addresses.mainnet.USDC_USD_FEED;
  const USDT_USD_FEED = addresses.mainnet.USDT_USD_FEED;
  const USDe_USD_FEED = addresses.mainnet.USDe_USD_FEED;

  // Asset decimals
  const DAI_decimals = 18;
  const USDC_decimals = 6;
  const USDT_decimals = 6;
  const USDe_decimals = 18;

  // Staking token addresses
  const sDAIAddress = addresses.mainnet.sDAI;
  const sUSDCAddress = addresses.mainnet.sUSDC;
  const sUSDTAddress = addresses.mainnet.sUSDT;
  const sUSDeAddress = addresses.mainnet.sUSDe;

  // Get contract instances
  const vault = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;
  const oracleRouter = await ethers.getContractAt("OracleRouter", oracleRouterAddress) as OracleRouter;

  console.log("Setting up vault at address:", vaultAddress);

  if (setBentoUSD) {
    console.log("Setting bentoUSD to:", bentoUSDAddress);
    await vault.setBentoUSD(bentoUSDAddress);
  }

  if (setOracleRouter) {
    await vault.setOracleRouter(oracleRouterAddress);
  }

  if (setAssetPriceFeeds) {
    console.log("Adding price feeds to oracle router...");
    
    await oracleRouter.addFeed(
      DAIAddress,
      DAI_USD_FEED,
      86400, // 1 day staleness
      8     // decimals
    );

    await oracleRouter.addFeed(
      USDCAddress,
      USDC_USD_FEED,
      86400,
      8
    );

    await oracleRouter.addFeed(
      USDTAddress,
      USDT_USD_FEED,
      86400,
      8
    );

    await oracleRouter.addFeed(
      USDeAddress,
      USDe_USD_FEED,
      86400,
      8
    );
  }

  if (setAssets) {
    console.log("Setting assets in vault...");
    
    await vault.setAsset(
      USDCAddress,
      USDC_decimals,
      USDCWeight,
      sUSDCAddress
    );

    await vault.setAsset(
      DAIAddress,
      DAI_decimals,
      DAIWeight,
      sDAIAddress
    );

    await vault.setAsset(
      USDTAddress,
      USDT_decimals,
      USDTWeight,
      sUSDTAddress
    );

    await vault.setAsset(
      USDeAddress,
      USDe_decimals,
      USDeWeight,
      sUSDeAddress
    );
  }

  let strategies = {
    USDC: ethers.ZeroAddress,
    DAI: ethers.ZeroAddress,
    USDT: ethers.ZeroAddress,
    USDe: ethers.ZeroAddress
  };

  if (deployStrategies) {
    console.log("Deploying strategies...");
    
    const Strategy = await ethers.getContractFactory("Generalized4626Strategy");
    
    strategies.USDC = await Strategy.deploy(USDCAddress, sUSDCAddress, vaultAddress);
    await strategies.USDC.waitForDeployment();
    strategies.DAI = await Strategy.deploy(DAIAddress, sDAIAddress, vaultAddress);
    await strategies.DAI.waitForDeployment();
    strategies.USDT = await Strategy.deploy(USDTAddress, sUSDTAddress, vaultAddress);
    await strategies.USDT.waitForDeployment();
    strategies.USDe = await Strategy.deploy(USDeAddress, sUSDeAddress, vaultAddress);
    await strategies.USDe.waitForDeployment();
  }

  if (setAssetStrategies) {
    console.log("Setting asset strategies...");
    
    await vault.setStrategy(USDCAddress, strategies.USDC);
    await vault.setStrategy(DAIAddress, strategies.DAI);
    await vault.setStrategy(USDTAddress, strategies.USDT);
    await vault.setStrategy(USDeAddress, strategies.USDe);
  }

  if (setLTToken) {
    const vaultAssets = await vault.getAssets();
    console.log("\n=== Setting LT tokens ===");
    
    for (let i = 0; i < vaultAssets.length; i++) {
      const asset = await vault.allAssets(i);
      const assetInfo = vaultAssets[i];
      const assetStrategy = await vault.assetToStrategy(asset);
      const strategy = await ethers.getContractAt("Generalized4626Strategy", assetStrategy) as Generalized4626Strategy;
      const ltToken = await strategy.shareToken();
      
      await vault.changeAsset(asset, 18, assetInfo.weight, ltToken);
    }
  }

  console.log("Setup complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 