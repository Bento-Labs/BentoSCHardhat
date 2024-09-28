// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/chainlink/AggregatorV3Interface.sol";
import { IOracle } from "../interfaces/IOracle.sol";
import { Helpers } from "../utils/Helpers.sol";
import { StableMath } from "../utils/StableMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// @notice Abstract functionality that is shared between various Oracle Routers
abstract contract OracleRouterBase is IOracle {
    using StableMath for uint256;
    using SafeCast for int256;

    uint256 internal constant MIN_DRIFT = 0.8e18;
    uint256 internal constant MAX_DRIFT = 1.2e18;
    address internal constant FIXED_PRICE =
        0x0000000000000000000000000000000000000001;
    // Maximum allowed staleness buffer above normal Oracle maximum staleness
    uint256 internal constant STALENESS_BUFFER = 1 days;
    mapping(address => uint8) internal decimalsCache;

    /**
     * @dev The price feed contract to use for a particular asset along with
     *      maximum data staleness
     * @param asset address of the asset
     * @return feedAddress address of the price feed for the asset
     * @return maxStaleness maximum acceptable data staleness duration
     */
    function feedMetadata(address asset)
        internal
        view
        virtual
        returns (address feedAddress, uint256 maxStaleness);

    /**
     * @notice Returns the total price in 18 digit unit for a given asset.
     * @param asset address of the asset
     * @return uint256 unit price for 1 asset unit, in 18 decimal fixed
     */
    function price(address asset)
        external
        view
        virtual
        override
        returns (uint256)
    {
        (address _feed, uint256 maxStaleness) = feedMetadata(asset);
        require(_feed != address(0), "Asset not available");
        require(_feed != FIXED_PRICE, "Fixed price feeds not supported");

        (, int256 _iprice, , uint256 updatedAt, ) = AggregatorV3Interface(_feed)
            .latestRoundData();

        require(
            updatedAt + maxStaleness >= block.timestamp,
            "Oracle price too old"
        );

        uint8 decimals = getDecimals(_feed);

        uint256 _price = _iprice.toUint256().scaleBy(18, decimals);
        if (shouldBePegged(asset)) {
            require(_price <= MAX_DRIFT, "Oracle: Price exceeds max");
            require(_price >= MIN_DRIFT, "Oracle: Price under min");
        }
        return _price;
    }

    function getDecimals(address _feed) internal view virtual returns (uint8) {
        uint8 decimals = decimalsCache[_feed];
        require(decimals > 0, "Oracle: Decimals not cached");
        return decimals;
    }

    /**
     * @notice Before an asset/feed price is fetches for the first time the
     *         decimals need to be cached. This is a gas optimization
     * @param asset address of the asset
     * @return uint8 corresponding asset decimals
     */
    function cacheDecimals(address asset) external returns (uint8) {
        (address _feed, ) = feedMetadata(asset);
        require(_feed != address(0), "Asset not available");
        require(_feed != FIXED_PRICE, "Fixed price feeds not supported");

        uint8 decimals = AggregatorV3Interface(_feed).decimals();
        decimalsCache[_feed] = decimals;
        return decimals;
    }

    function shouldBePegged(address _asset) internal view returns (bool) {
        string memory symbol = Helpers.getSymbol(_asset);
        bytes32 symbolHash = keccak256(abi.encodePacked(symbol));
        return
            symbolHash == keccak256(abi.encodePacked("DAI")) ||
            symbolHash == keccak256(abi.encodePacked("USDC")) ||
            symbolHash == keccak256(abi.encodePacked("USDT"));
    }
}

// @notice Oracle Router that denominates all prices in USD
contract OracleRouter is OracleRouterBase {
    /**
     * @dev The price feed contract to use for a particular asset along with
     *      maximum data staleness
     * @param asset address of the asset
     * @return feedAddress address of the price feed for the asset
     * @return maxStaleness maximum acceptable data staleness duration
     */
    function feedMetadata(address asset)
        internal
        pure
        virtual
        override
        returns (address feedAddress, uint256 maxStaleness)
    {
        /* + STALENESS_BUFFER is added in case Oracle for some reason doesn't
         * update on heartbeat and we add a generous buffer amount.
         */
        if (asset == 0x6B175474E89094C44Da98b954EedeAC495271d0F) {
            // https://data.chain.link/ethereum/mainnet/stablecoins/dai-usd
            // Chainlink: DAI/USD
            feedAddress = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
            maxStaleness = 1 hours + STALENESS_BUFFER;
        } else if (asset == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
            // Chainlink: USDC/USD
            feedAddress = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
            maxStaleness = 1 days + STALENESS_BUFFER;
        } else if (asset == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
            // https://data.chain.link/ethereum/mainnet/stablecoins/usdt-usd
            // Chainlink: USDT/USD
            feedAddress = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
            maxStaleness = 1 days + STALENESS_BUFFER;
        } else {
            revert("Asset not available");
        }
    }
}
