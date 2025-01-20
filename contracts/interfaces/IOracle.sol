// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IOracle {
    /**
     * @dev returns the asset price in USD, in 8 decimal digits.
     */
    function price(address asset) external view returns (uint256);
}
