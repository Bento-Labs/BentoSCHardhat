// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {OFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/v1/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "./utils/Errors.sol";

contract BentoUSD is Ownable, OFT, Errors {
    address public bentoUSDVault;
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint) Ownable() {
        // Any additional initialization logic
    }

    // TODO: for mainnet we will need to remove the minting right from owner.
    function mint(address _to, uint256 _amount) public {
        if (msg.sender != bentoUSDVault && msg.sender != owner()) {
            revert Unauthorized();
        }
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        if (msg.sender != bentoUSDVault && msg.sender != owner()) {
            revert Unauthorized();
        }
        _burn(_from, _amount);
    }

    function setBentoUSDVault(address _bentoUSDVault) public onlyOwner {
        bentoUSDVault = _bentoUSDVault;
    }
}
