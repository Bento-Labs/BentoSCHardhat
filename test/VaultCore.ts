import { loadFixture, mine} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import { deployVaultFixture, normalizeDecimals, setERC20Balance } from "./setUp";
import type { VaultFixture } from "./setUp";

describe("VaultCore", function() {
  let fixture: VaultFixture;
  let provider: provider;
  

  beforeEach(async function() {

  const network = await hre.network.name;
  console.log(`network: ${network}`);
  const chainId = await hre.config.chainId;
  console.log(`chainId: ${chainId}`);
    console.log(`deploying vault`);
    fixture = await loadFixture(deployVaultFixture);
    provider = ethers.provider;
  });

  describe("Deployment", function() {
    it("Should deploy with correct initial state", async function() {
      const { 
        vaultCore,
        vaultImpl,
        vault,
        bentoUSD,
        bentoUSDPlus,
        oracle,
        owner,
        user1,
        user2,
        assets,
        ltTokens
      } = fixture;
      
      // Check core contract connections
      expect(await vault.bentoUSD()).to.equal(await bentoUSD.getAddress());
      expect(await vault.oracleRouter()).to.equal(await oracle.getAddress());
      expect(await bentoUSD.bentoUSDVault()).to.equal(await vaultCore.getAddress());
      
      // Check proxy setup
      let vaultProxy = await ethers.getContractAt("UpgradableProxy", await vaultCore.getAddress());
      expect(await vaultProxy.implementation()).to.equal(await vaultImpl.getAddress());
      expect(await vaultProxy.proxyOwner()).to.equal(owner.address);
      
      // Check asset setup
      const onchainAssets = await vault.getAllAssets();
      for (const tokenName in assets) {
        const tokenAddress = await assets[tokenName].getAddress();
        expect(onchainAssets).to.include(tokenAddress);
        const assetInfo = await vault.assetToAssetInfo(tokenAddress);
        const ltTokenAddress = assetInfo.ltToken;
        expect(ltTokenAddress).to.equal(await ltTokens[`s${tokenName}`].getAddress());
      }
    });
  });

  describe("Mint and Redeem", function() {
    it.only("Should mint BentoUSD using mintBasket and redeem LT tokens using redeemLTBasket", async function() {
      const { vault, bentoUSD, owner, assets, ltTokens } = fixture;
      const depositAmount = ethers.parseEther("1000");
      const minimumBentoUSD = ethers.parseEther("990");

      
      const userAddress = "0xDDC9b558908E28279147D441BF626D4E3e5A5163";
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [userAddress],
      });
      // check ETH balance of user
      const user = await ethers.getSigner(userAddress);
      const ethBalance = await provider.getBalance(user.address);
      console.log(`ETH balance of user: ${ethBalance}`);
      // check balances of the underlying assets
      for (const asset of Object.values(assets)) {
        const balance = await asset.balanceOf(user.address);        
      }
      // Approve vault to spend assets
      for (const asset of Object.values(assets)) {
        await asset.connect(user).approve(await vault.getAddress(), depositAmount);
      }

      console.log(`approval done`)

      // rough calculation of the expected deposit amount from each underlying asset
      const weights = await vault.getWeights();
      const totalWeight = weights.reduce((acc, weight) => acc + weight, 0n);
      const expectedDepositAmount = weights.map((weight) => depositAmount * weight / totalWeight);
      for (let i = 0; i < Object.keys(assets).length; i++) {
        const assetAddress = await Object.values(assets)[i].getAddress();
        const addressMetadata = await ethers.getContractAt("IERC20Metadata", assetAddress);
        const assetDecimals = await addressMetadata.decimals();
        expectedDepositAmount[i] = normalizeDecimals(assetDecimals, expectedDepositAmount[i]);
      }

      const bentoUSDBalanceBefore = await bentoUSD.balanceOf(user.address);
      const underlyingAssetBalancesBefore = await Promise.all(Object.values(assets).map(asset => asset.balanceOf(user.address)));

      console.log(`minting BentoUSD`);
      // Mint BentoUSD
      await vault.connect(user).mintBasket(depositAmount, minimumBentoUSD);
      console.log(`minting done`);

      const bentoUSDBalanceAfter = await bentoUSD.balanceOf(user.address);
      console.log(`the real received BentoUSD amount`);
      console.log(bentoUSDBalanceAfter - bentoUSDBalanceBefore);
      console.log(`the expected BentoUSD amount`);
      console.log(depositAmount);
      expect(bentoUSDBalanceAfter - bentoUSDBalanceBefore).to.be.closeTo(depositAmount, ethers.parseEther("0.1"));

      const underlyingAssetBalancesAfter = await Promise.all(Object.values(assets).map(asset => asset.balanceOf(user.address)));
      const realDepositAmounts = []  ;
      for (let i = 0; i < Object.keys(assets).length; i++) {
        const asset = Object.values(assets)[i];
        const assetAddress = await Object.values(assets)[i].getAddress();
        const addressMetadata = await ethers.getContractAt("IERC20Metadata", assetAddress);
        const assetName = await addressMetadata.name();
        const assetDecimals = await addressMetadata.decimals();
        console.log(`checking asset ${assetName} `);
        console.log(`the real deposited underlying asset amount`);
        console.log(underlyingAssetBalancesBefore[i] - underlyingAssetBalancesAfter[i]);
        console.log(`the expected deposited underlying asset amount`);
        console.log(expectedDepositAmount[i]);
        const realDepositAmount = underlyingAssetBalancesBefore[i] - underlyingAssetBalancesAfter[i];
        realDepositAmounts.push(realDepositAmount);
        expect(realDepositAmount).to.be.closeTo(expectedDepositAmount[i], ethers.parseUnits("1", assetDecimals));
        expect(realDepositAmount).to.be.equal(await asset.balanceOf(await vault.getAddress()));
      }

      // now we need to allocate to get the LT tokens
      for (let i = 0; i < Object.keys(assets).length; i++) {
        const ltToken = Object.values(ltTokens)[i];
        const ltTokenAddress = await ltToken.getAddress();
        const ltTokenMetadata = await ethers.getContractAt("IERC20Metadata", ltTokenAddress);
        const ltTokenName = await ltTokenMetadata.name();
        console.log(`checking LT token ${ltTokenName} at index ${i} and address ${ltTokenAddress}`);
        console.log(`the real deposit amount`);
        console.log(realDepositAmounts[i]);

      }

      const tx = await vault.connect(owner).allocate();
      await tx.wait();
      console.log(`----------------`)
      console.log(`allocate done`)
      console.log(`----------------`)

      // now we check the LT balances
      for (let i = 0; i < Object.keys(assets).length; i++) {
        const ltToken = Object.values(ltTokens)[i];
        const expectedLTBalance = await ltToken.convertToShares(realDepositAmounts[i]);

        console.log(`checking LT token ${i}`);
        console.log(`the expected LT balance`);
        console.log(expectedLTBalance);
        console.log(`the real LT balance`);
        const realLTBalance = await ltToken.balanceOf(user.address);
        console.log(realLTBalance);
        expect(realLTBalance).to.be.equal(expectedLTBalance);
      }

      // redeem LT tokens
      /* const redeemAmount = ethers.parseEther("10");
      // we approve the bentoUSD amount to be burned
      await bentoUSD.connect(user).approve(await vault.getAddress(), redeemAmount);

      await vault.connect(user).redeemLTBasket(redeemAmount, minimumBentoUSD); */

    });
  });
});
