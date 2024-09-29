// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title bentoToken VaultAdmin contract
 * @notice The VaultAdmin contract makes configuration and admin calls on the vault.
 * @author Modified from Origin Protocol Inc by Le Anh Dung
 */

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IOracle } from "../interfaces/IOracle.sol";
import "./VaultStorage.sol";

contract VaultAdmin is VaultStorage {
    using SafeERC20 for IERC20;
    using StableMath for uint256;
    /***************************************
                 Configuration
    ****************************************/

    /**
     * @notice Set address of price provider.
     * @param _priceProvider Address of price provider
     */
    function setPriceProvider(address _priceProvider) external onlyGovernor {
        priceProvider = _priceProvider;
        emit PriceProviderUpdated(_priceProvider);
    }
}
