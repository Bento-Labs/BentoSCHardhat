// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {OracleRouter} from "../OracleRouter.sol";
import {AggregatorV3Interface} from "../interfaces/chainlink/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// smart contract to provide a price feed (in USD denomination) for an ERC4626 vault
contract ERC4626Feed is AggregatorV3Interface {

    // oracle router to get the price of the underlying asset
    OracleRouter public immutable oracleRouter;
    // the corresponding ERC4626 vault
    IERC4626 public immutable vault;
    // the underlying asset of the vault
    address public immutable underlyingAsset;

    uint8 private immutable _decimals;
    uint private immutable ONE;
    uint private immutable ONE_UNDERLYING;
    string private _description;

    constructor(address _oracleRouter, address _vault, string memory description_) {
        oracleRouter = OracleRouter(_oracleRouter);
        vault = IERC4626(_vault);
        underlyingAsset = vault.asset();
        _decimals = 18; // Standard for most price feeds
        ONE = 10 ** _decimals;
        ONE_UNDERLYING = 10 ** IERC20Metadata(underlyingAsset).decimals();
        _description = description_;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 /* _roundId */) external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        // We don't track historical rounds, so we'll return the latest for any roundId
        return latestRoundData();
    }

    function latestRoundData() public view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        uint256 price = getPrice();
        uint256 timestamp = block.timestamp;

        return (
            uint80(1), // We don't track rounds, so always return 1
            int256(price),
            timestamp,
            timestamp,
            uint80(1)
        );
    }

    function getPrice() public view returns (uint256) {
        uint256 assetPrice = oracleRouter.price(underlyingAsset);
        uint256 assetsPerShare = vault.convertToAssets(ONE);
        return (assetPrice * assetsPerShare) / ONE_UNDERLYING;
    }
}
