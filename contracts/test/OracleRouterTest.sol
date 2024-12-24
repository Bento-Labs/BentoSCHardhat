// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../OracleRouter.sol";
import "../utils/StableMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract OracleRouterTest is OracleRouter {
    using StableMath for uint256;
    using SafeCast for int256;

    constructor(address initialOwner) OracleRouter(initialOwner) {
        // Any additional initialization logic can go here
    }

    function priceUnfiltered(address asset) public view returns (int256) {
        FeedInfo storage feedInfo = tokenToFeed[asset];
        address _feed = feedInfo.feedAddress;
        (, int256 _iprice, , uint256 updatedAt, ) = AggregatorV3Interface(_feed)
            .latestRoundData();
        return _iprice;
    }

    function priceScaled(address asset) public view returns (uint256) {
        FeedInfo storage feedInfo = tokenToFeed[asset];
        return
            priceUnfiltered(asset).toUint256().scaleBy(18, feedInfo.decimals);
    }
}
