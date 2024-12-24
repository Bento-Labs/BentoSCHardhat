/* // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
// Since we cannot stake directly to Ethena from the staking vault, as then the unbonding period would be bound to one address, we use proxy to have separate unbonding periods for each user.
contract EthenaWalletProxy {
    address public ethenaVault;
    address public bentoUSDVault;

    constructor(address _ethenaVault, address _bentoUSDVault) {
        ethenaVault = _ethenaVault;
        bentoUSDVault = _bentoUSDVault;
    }
    
    // we don't need to implement deposit since we use batch deposit from the bentoUSDVault to Ethena
    function withdraw(uint256 _amount) external {
        require(msg.sender == bentoUSDVault, "Only bentoUSDVault can call withdraw");
        IERC4626(ethenaVault).withdraw(_amount, msg.sender, address(this));
    }
}
 */