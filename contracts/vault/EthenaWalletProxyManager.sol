// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title Generalized 4626 Strategy
 * @notice Investment strategy for ERC-4626 Tokenized Vaults
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { EthenaWalletProxy } from "../utils/EthenaWalletProxy.sol";
import {Errors} from "../utils/Errors.sol";

contract EthenaWalletProxyManager is Errors {
    using SafeERC20 for IERC20;

    mapping(address => address) public userToEthenaWalletProxy;

    /**
     * @dev commit to a withdrawal request in Ethena protocol, which triggers the unbonding period
     * @param _assetAmount Amount of asset to withdraw
     * @param _ethenaWalletProxy Address of the Ethena wallet proxy
     */
    function commitWithdraw(
        uint256 _assetAmount,
        address _ethenaWalletProxy
    ) internal virtual {
        if (_assetAmount == 0) {
            revert ZeroAmount();
        }
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

}
