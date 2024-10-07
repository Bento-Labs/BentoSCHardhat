import { expect } from "chai";
import { ethers } from "hardhat";
import { OracleRouter } from "../typechain-types/contracts/OracleRouter";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { addresses } from "../scripts/addresses";

describe("OracleRouter", function () {
  let oracleRouter: OracleRouter;
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;

  beforeEach(async function () {
    // Deploy the OracleRouter contract
    const OracleRouter = await ethers.getContractFactory("OracleRouter");
    [owner, addr1] = await ethers.getSigners();
    oracleRouter = await OracleRouter.deploy();
    await oracleRouter.deployed();

    // Add feeds for testing
    await oracleRouter.addFeed(
      addresses.mainnet.USDC,
      addresses.mainnet.USDC_USD_FEED,
      6,  // USDC has 6 decimals
      86400 // 1 day staleness
    );
    await oracleRouter.addFeed(
      addresses.mainnet.DAI,
      addresses.mainnet.DAI_USD_FEED,
      18, // DAI has 18 decimals
      3600 // 1 hour staleness
    );
    await oracleRouter.addFeed(
      addresses.mainnet.USDT,
      addresses.mainnet.USDT_USD_FEED,
      6,  // USDT has 6 decimals
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
        addresses.mainnet.USDT,
        addresses.mainnet.USDT_USD_FEED,
        6,
        86400
      )).to.not.be.reverted;

      // Non-owner should not be able to add a feed
      await expect(oracleRouter.connect(addr1).addFeed(
        addresses.mainnet.DAI,
        addresses.mainnet.DAI_USD_FEED,
        18,
        3600
      )).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("price", function () {
    it("should return the correct price for USDC", async function () {
      const price = await oracleRouter.price(addresses.USDC);
      expect(price).to.be.gt(0);
      expect(price).to.be.lte(ethers.utils.parseEther("1.1")); // MAX_DRIFT
      expect(price).to.be.gte(ethers.utils.parseEther("0.9")); // MIN_DRIFT
    });

    it("should return the correct price for WETH", async function () {
      const price = await oracleRouter.price(addresses.WETH);
      expect(price).to.be.gt(0);
      expect(price).to.be.lte(ethers.utils.parseEther("1.1")); // MAX_DRIFT
      expect(price).to.be.gte(ethers.utils.parseEther("0.9")); // MIN_DRIFT
    });

    it("should revert for an unsupported asset", async function () {
      await expect(oracleRouter.price(ethers.constants.AddressZero)).to.be.revertedWith("Asset not available");
    });

    it("should revert if the price is too old", async function () {
      // Increase time by more than the max staleness
      await ethers.provider.send("evm_increaseTime", [86401]); // 1 day + 1 second
      await ethers.provider.send("evm_mine", []);

      await expect(oracleRouter.price(addresses.USDC)).to.be.revertedWith("Oracle price too old");
    });
  });

  // ... existing tests ...
});
