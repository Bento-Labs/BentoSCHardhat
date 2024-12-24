import { expect } from "chai";
import { ethers } from "hardhat";
import { OracleRouterTest } from "../typechain-types/contracts/test/OracleRouterTest";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addresses } from "../scripts/addresses";

describe.only("OracleRouter", function () {
  let oracleRouter: OracleRouterTest;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    // Deploy the OracleRouterTest contract
    const OracleRouterTest = await ethers.getContractFactory("OracleRouterTest");
    [owner, addr1] = await ethers.getSigners();
    oracleRouter = await OracleRouterTest.deploy(owner.address) as OracleRouterTest;
    await oracleRouter.deploymentTransaction()?.wait(); // Wait for the deployment to be mined

    // Add feeds for testing
    await oracleRouter.addFeed(
      addresses.mainnet.USDC,
      addresses.mainnet.USDC_USD_FEED,
      86400 // 1 day staleness
    );
    await oracleRouter.addFeed(
      addresses.mainnet.DAI,
      addresses.mainnet.DAI_USD_FEED,
      3600 // 1 hour staleness
    );
    await oracleRouter.addFeed(
      addresses.mainnet.USDT,
      addresses.mainnet.USDT_USD_FEED,
      86400 // 1 day staleness
    );
  });

  describe("Ownership", function () {
    it("should set the deployer as the owner", async function () {
      const contractOwner = await oracleRouter.owner();
      expect(contractOwner).to.equal(owner.address);
    });

    it("should allow only owner to add price feed", async function () {
      // Owner should be able to add a feed
      await expect(oracleRouter.connect(owner).addFeed(
        addresses.mainnet.USDC,
        addresses.mainnet.USDC_USD_FEED,
        86400 // 1 day staleness
      )).to.not.be.reverted;

      // Non-owner should not be able to add a feed
      await expect(oracleRouter.connect(addr1).addFeed(
        addresses.mainnet.DAI,
        addresses.mainnet.DAI_USD_FEED,
        3600 // 1 hour staleness
      )).to.be.revertedWithCustomError(oracleRouter, "OwnableUnauthorizedAccount");
    });
  });

  describe("price", function () {
    it("should return the correct prices for USDC, DAI, and USDT", async function () {
        const usdcPriceUnfiltered = await oracleRouter.priceUnfiltered(addresses.mainnet.USDC);
        console.log("USDC price unfiltered:", usdcPriceUnfiltered.toString());
        const usdcPriceScaled = await oracleRouter.priceScaled(addresses.mainnet.USDC);
        console.log("USDC price scaled:", usdcPriceScaled.toString());
      const usdcPrice = await oracleRouter.price(addresses.mainnet.USDC);
      const daiPrice = await oracleRouter.price(addresses.mainnet.DAI);
      const usdtPrice = await oracleRouter.price(addresses.mainnet.USDT);

      console.log("USDC price:", usdcPrice.toString());
      console.log("DAI price:", daiPrice.toString());
      console.log("USDT price:", usdtPrice.toString());

      // Check USDC price
      expect(usdcPrice).to.be.gt(0);
      expect(usdcPrice).to.be.lte(ethers.utils.parseEther("1.1")); // MAX_DRIFT
      expect(usdcPrice).to.be.gte(ethers.utils.parseEther("0.9")); // MIN_DRIFT

      // Check DAI price
      expect(daiPrice).to.be.gt(0);
      expect(daiPrice).to.be.lte(ethers.utils.parseEther("1.1")); // MAX_DRIFT
      expect(daiPrice).to.be.gte(ethers.utils.parseEther("0.9")); // MIN_DRIFT

      // Check USDT price
      expect(usdtPrice).to.be.gt(0);
      expect(usdtPrice).to.be.lte(ethers.utils.parseEther("1.1")); // MAX_DRIFT
      expect(usdtPrice).to.be.gte(ethers.utils.parseEther("0.9")); // MIN_DRIFT
    });

    it("should revert for an unsupported asset", async function () {
      await expect(oracleRouter.price(ethers.constants.AddressZero)).to.be.revertedWith("Asset not available");
    });

    it("should revert if the price is too old", async function () {
      // Increase time by more than the max staleness
      await ethers.provider.send("evm_increaseTime", [86401]); // 1 day + 1 second
      await ethers.provider.send("evm_mine", []);

      await expect(oracleRouter.price(addresses.mainnet.USDC)).to.be.revertedWith("Oracle price too old");
    });
  });

  // ... existing tests ...
});
