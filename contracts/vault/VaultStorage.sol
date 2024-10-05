// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title OToken VaultStorage contract
 * @notice The VaultStorage contract defines the storage for the Vault contracts
 * @author Origin Protocol Inc
 */

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract VaultStorage {
    using SafeERC20 for IERC20;

    // Changed to fit into a single storage slot so the decimals needs to be recached
    struct Asset {
        // Note: OETHVaultCore doesn't use `isSupported` when minting,
        // redeeming or checking balance of assets.
        bool isSupported;
        uint8 decimals;
        uint8 weight;
        address LtToken;
    }

    uint256 public totalWeight;

    address public governor;
    address public bentoUSD;
    address public oracleRouter;

    /// @dev mapping of supported vault assets to their configuration
    // slither-disable-next-line uninitialized-state
    mapping(address => Asset) internal assets;
    /// @dev list of all assets supported by the vault.
    // slither-disable-next-line uninitialized-state
    address[] internal allAssets;

    mapping(address => address) public ltTokenToAsset;

    /// @dev Address of the bentoToken. eg bentoUSD .
    // slither-disable-next-line uninitialized-state

}
