// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStakedUSDe} from "../interfaces/IStakedUSDe.sol";
// Since we cannot stake directly to Ethena from the staking vault, as then the unbonding period would be bound to one address, we use proxy to have separate unbonding periods for each user.
contract EthenaWalletProxy {
    address public ethenaVault;
    // ethenaVault is sUSDe (StakedUSDeV2) assumed to be at address 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497
    // due to the unbonding period of sUSDe, we cannot withdraw directly, but we need to trigger this period by calling cooldownAssets or cooldownShares first
    address public bentoUSDVault;

    constructor(address _ethenaVault, address _bentoUSDVault) {
        ethenaVault = _ethenaVault;
        bentoUSDVault = _bentoUSDVault;
    }
    
    // we don't need to implement deposit since we use batch deposit from the bentoUSDVault to Ethena
    function commitWithdraw(uint256 _amount) external {
        require(msg.sender == bentoUSDVault, "Only bentoUSDVault can call withdraw");
        IStakedUSDe(ethenaVault).cooldownShares(_amount, msg.sender);
    }
}
