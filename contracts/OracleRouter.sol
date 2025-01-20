// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IOracle} from "./interfaces/IOracle.sol";
import {AggregatorV3Interface} from "./interfaces/chainlink/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {StableMath} from "./utils/StableMath.sol";

contract OracleRouter is IOracle, Ownable {
    using StableMath for uint256;
    using SafeCast for int256;

    uint256 internal constant MIN_DRIFT = 0.9e18;
    uint256 internal constant MAX_DRIFT = 1.1e18;
    address internal constant FIXED_PRICE =
        0x0000000000000000000000000000000000000001;
    // Maximum allowed staleness buffer above normal Oracle maximum staleness
    uint256 internal constant STALENESS_BUFFER = 1 days;
    mapping(address => FeedInfo) public tokenToFeed;

    struct FeedInfo {
        uint8 decimals;
        address feedAddress;
        uint256 maxStaleness;
    }

    constructor(address initialOwner) Ownable() {
        // Any additional initialization logic can go here
    }

    function addFeed(
        address asset,
        address feedAddress,
        uint256 maxStaleness,
        uint8 decimals
    ) public onlyOwner {
        try AggregatorV3Interface(feedAddress).decimals() returns (uint8 feedDecimals) {
            require(feedDecimals == decimals, "Input decimals do not match feed decimals");
        } catch {
            // If decimals is not callable, use the input decimals
        }
        tokenToFeed[asset] = FeedInfo(decimals, feedAddress, maxStaleness);
    }

    /**
     * @notice Returns the total price in 18 digit unit for a given asset.
     * @param asset address of the asset
     * @return uint256 unit price for 1 asset unit, in 18 decimal fixed
     */
    function price(
        address asset
    ) external view virtual override returns (uint256) {
        FeedInfo storage feedInfo = tokenToFeed[asset];
        address _feed = feedInfo.feedAddress;
        uint8 decimals = feedInfo.decimals;
        uint256 maxStaleness = feedInfo.maxStaleness;
        require(_feed != address(0), "Asset not available");
        require(_feed != FIXED_PRICE, "Fixed price feeds not supported");
        

        (, int256 _iprice, , uint256 updatedAt, ) = AggregatorV3Interface(_feed)
            .latestRoundData();

        require(
            updatedAt + maxStaleness >= block.timestamp,
            "Oracle price too old"
        );

        uint256 _price = _iprice.toUint256().scaleBy(18, decimals);

        /// dev: split the checks for stablecoin and non-stablecoin
        /* require(_price <= MAX_DRIFT, "Oracle: Price exceeds max");
        require(_price >= MIN_DRIFT, "Oracle: Price under min"); */

        return _price;
    }
}
