// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IOracle} from "./interfaces/IOracle.sol";
import {AggregatorV3Interface} from "./interfaces/chainlink/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {StableMath} from "./utils/StableMath.sol";
import {Errors} from "./utils/Errors.sol";

/**
 * @title OracleRouter
 * @notice Manages price feeds for various assets and provides price data
 */
contract OracleRouter is IOracle, Ownable, Errors {
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
        transferOwnership(initialOwner);
    }

    /**
     * @notice Adds a new price feed for an asset
     * @param asset The address of the asset
     * @param feedAddress The address of the price feed
     * @param maxStaleness The maximum staleness allowed for the feed
     * @param decimals The number of decimals for the asset price
     */
    function addFeed(
        address asset,
        address feedAddress,
        uint256 maxStaleness,
        uint8 decimals
    ) public onlyOwner {
        try AggregatorV3Interface(feedAddress).decimals() returns (uint8 feedDecimals) {
            if (feedDecimals != decimals) {
                revert Inconsistency();
            }
        } catch {
            // If decimals is not callable, use the input decimals
            // i.e. we do nothing here, hence it's empty
        }
        tokenToFeed[asset] = FeedInfo(decimals, feedAddress, maxStaleness);
    }

    /**
     * @notice Returns the total price in 18 digit unit for a given asset
     * @param asset The address of the asset
     * @return uint256 Unit price for 1 asset unit, in 18 decimal fixed
     */
    function price(
        address asset
    ) external view virtual override returns (uint256) {
        FeedInfo storage feedInfo = tokenToFeed[asset];
        address _feed = feedInfo.feedAddress;
        uint8 decimals = feedInfo.decimals;
        uint256 maxStaleness = feedInfo.maxStaleness;
        if (_feed == address(0)) {
            revert ZeroAddress();
        }
        if (_feed == FIXED_PRICE) {
            revert NotSupported();
        }
        

        (, int256 _iprice, , uint256 updatedAt, ) = AggregatorV3Interface(_feed)
            .latestRoundData();

        if (updatedAt + maxStaleness < block.timestamp) {
            revert StalePrice();
        }

        uint256 _price = _iprice.toUint256().scaleBy(18, decimals);

        /// TODO: split the checks for stablecoin and non-stablecoin
        /* require(_price <= MAX_DRIFT, "Oracle: Price exceeds max");
        require(_price >= MIN_DRIFT, "Oracle: Price under min"); */

        return _price;
    }
}
