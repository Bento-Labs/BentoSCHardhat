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

import { IStrategy } from "../interfaces/IStrategy.sol";
import { Governable } from "../governance/Governable.sol";
import { OUSD } from "../token/OUSD.sol";
import { Initializable } from "../utils/Initializable.sol";
import "../utils/Helpers.sol";

contract VaultStorage is Initializable, Governable {
    using SafeERC20 for IERC20;

    // Changed to fit into a single storage slot so the decimals needs to be recached
    struct Asset {
        // Note: OETHVaultCore doesn't use `isSupported` when minting,
        // redeeming or checking balance of assets.
        bool isSupported;
        uint8 decimals;
        uint8 weight;
    }

    uint256 public constant totalWeight;

    /// @dev mapping of supported vault assets to their configuration
    // slither-disable-next-line uninitialized-state
    mapping(address => Asset) internal assets;
    /// @dev list of all assets supported by the vault.
    // slither-disable-next-line uninitialized-state
    address[] internal allAssets;

    /// @notice pause operations that change the OToken supply.
    /// eg mint, redeem, allocate, mint/burn for strategy
    bool public capitalPaused = true;
    /// @notice Redemption fee in basis points. eg 50 = 0.5%
    uint256 public redeemFeeBps;
    /// @notice Percentage of assets to keep in Vault to handle (most) withdrawals. 100% = 1e18.
    uint256 public vaultBuffer;

    /// @dev Address of the bentoToken. eg bentoUSD .
    // slither-disable-next-line uninitialized-state
    BentoUSD internal bentoUSD;

    /// @notice Mapping of asset address to the Strategy that they should automatically
    // be allocated to
    // slither-disable-next-line uninitialized-state
    mapping(address => address) public assetDefaultStrategies;

    /// Withdrawal Queue Storage /////


}
