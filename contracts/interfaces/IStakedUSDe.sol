// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface to interact with sUSDe (StakedUSDeV2)
 */
interface IStakedUSDe {
    // on which 
    function cooldownAssets(uint256 assets) external returns (uint256 shares);

    function cooldownShares(uint256 shares) external returns (uint256 assets);
    function unstake(address receiver) external;
   function setCooldownDuration(uint24 duration) external;
}
