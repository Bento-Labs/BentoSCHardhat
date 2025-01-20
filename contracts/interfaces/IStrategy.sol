// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title Platform interface to integrate with lending platform like Compound, AAVE etc.
 */
interface IStrategy {
    /**
     * @dev Deposit the given asset to platform
     * @param _amount Amount to deposit
     */
    function deposit(uint256 _amount) external;

    /**
     * @dev Withdraw given asset from Lending platform
     */
    function withdraw(
        address _recipient,
        address _asset,
        uint256 _amount
    ) external;

    /**
     * @dev Liquidate all assets in strategy and return them to Vault.
     */
    function withdrawAll() external;
    function convertToShares(uint256 _amount) external returns (uint256);
    function redeem(address _recipient, uint256 _amount) external;
}
