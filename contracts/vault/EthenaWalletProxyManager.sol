// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Generalized 4626 Strategy
 * @notice Investment strategy for ERC-4626 Tokenized Vaults
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { EthenaWalletProxy } from "../utils/EthenaWalletProxy.sol";
import "hardhat/console.sol";


contract EthenaWalletProxyManager {
    using SafeERC20 for IERC20;

    mapping(address => address) public userToEthenaWalletProxy;

    /**
     * @dev commit to a withdrawal request in Ethena protocol, which triggers the unbonding period
     * @param _recipient Address to receive withdrawn asset
     * @param _assetAmount Amount of asset to withdraw
     */
    function commitWithdraw(
        address _recipient,
        uint256 _assetAmount,
        address _ethenaWalletProxy
    ) internal virtual {
        require(_assetAmount > 0, "Must withdraw something");
        require(_recipient != address(0), "Must specify recipient");
        // slither-disable-next-line unused-return
        EthenaWalletProxy(_ethenaWalletProxy).commitWithdraw(_assetAmount);
    }
    /** Function to withdraw from Ethena protocol after the unbonding period is over
     * @param _recipient Address to receive withdrawn asset
     */
    function withdrawFromEthena(address _recipient) external {
        address _ethenaWalletProxy = userToEthenaWalletProxy[msg.sender];
        EthenaWalletProxy(_ethenaWalletProxy).withdraw(_recipient);
    }

    /**
     * @dev Remove all assets from platform and send them to Vault contract.
     */
    /* function withdrawAll()
        external
        virtual
        onlyAdmin
    {
        uint256 shareBalance = IERC20(shareToken).balanceOf(address(this));
        uint256 assetAmount = IERC4626(shareToken).redeem(
            shareBalance,
            admin,
            address(this)
        );
    }

    function approveVault(address _vault) external onlyAdmin {
        IERC20(assetToken).safeIncreaseAllowance(_vault, type(uint256).max);
    } */
}
