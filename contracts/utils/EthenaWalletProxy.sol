// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IStakedUSDe} from "../interfaces/IStakedUSDe.sol";
import {Errors} from "./Errors.sol";
// Since we cannot stake directly to Ethena from the staking vault, as then the unbonding period would be bound to one address, we use proxy to have separate unbonding periods for each user.

/**
 * @title EthenaWalletProxy
 * @notice Since we cannot stake directly to Ethena from the staking vault, as then the unbonding period would be bound to one address, we use proxy to have separate unbonding periods for each user. We don't need to implement deposit here because we use batch deposit from the bentoUSDVault to Ethena.
 */
contract EthenaWalletProxy is Errors {
    /// @notice Address of the Ethena vault (sUSDe)
    /// @dev On Ethereum mainnet it is ssumed to be at address 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497
    address public ethenaVault;
    address public bentoUSDVault;
    address public user;

    /**
     * @notice Initializes the EthenaWalletProxy contract
     * @param _ethenaVault The address of the Ethena vault
     * @param _bentoUSDVault The address of the BentoUSD vault
     * @param _user The address of the user owning the proxy
     */
    constructor(address _ethenaVault, address _bentoUSDVault, address _user) {
        ethenaVault = _ethenaVault;
        bentoUSDVault = _bentoUSDVault;
        user = _user;
    }
    
    /**
     * @notice Commits a withdrawal by triggering the cooldown period
     * @dev Only callable by the BentoUSD vault
     * @param _amount The amount to withdraw
     */
    function commitWithdraw(uint256 _amount) external {
        if (msg.sender != bentoUSDVault) {
            revert Unauthorized();
        }
        // there is a mitmatch between Ethena onchain code (which has only one parameter) and github repo (which has 2 parameters) for cooldownShares
        IStakedUSDe(ethenaVault).cooldownShares(_amount);
    }

    /**
     * @notice Withdraws the staked assets to a recipient
     * @dev Only callable by the owner of the wallet proxy
     * @param _recipient The address to receive the unstaked assets
     */
    function withdraw(address _recipient) external {
        if (msg.sender != user) {
            revert Unauthorized();
        }
        IStakedUSDe(ethenaVault).unstake(_recipient);
    }
}
