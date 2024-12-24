// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract BentoUSDPlus is ERC4626 {
    constructor(
        IERC20 asset_
    ) ERC4626(asset_) ERC20("BentoUSD+", "BentoUSD+") {}

    // Optional: Override _decimalsOffset if you want to test different decimal offsets
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return 18 - IERC20Metadata(asset()).decimals();
    }
}