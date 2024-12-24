// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BentoToken VaultStorage contract
 * @notice The VaultStorage contract defines the storage for the Vault contracts
 * @author Le Anh Dung, Bento Labs
 */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract VaultStorage {
    using SafeERC20 for IERC20;

    // Changed to fit into a single storage slot so the decimals needs to be recached
    struct Asset {
        bool isSupported;
        uint8 decimals;
        uint32 weight;
        address ltToken;
    }

    uint256 public totalWeight;

    address public governor;
    address public bentoUSD;
    address public oracleRouter;

    /// @dev mapping of supported vault assets to their configuration
    // slither-disable-next-line uninitialized-state
    mapping(address => Asset) public assets;
    /// @dev list of all assets supported by the vault.
    // slither-disable-next-line uninitialized-state
    address[] public allAssets;

    mapping(address => address) public ltTokenToAsset;
    /// @dev amount of asset we want to keep in the vault to cover for fast redemption
    mapping(address => uint256) public minimalAmountInVault;

    mapping(address => address) public assetToStrategy;

    function getWeights() public view returns (uint32[] memory) {
        uint32[] memory weights = new uint32[](allAssets.length);
        for (uint256 i = 0; i < allAssets.length; i++) {
            weights[i] = assets[allAssets[i]].weight;
        }
        return weights;
    }

    function getAssets() public view returns (Asset[] memory) {
        Asset[] memory _assets = new Asset[](allAssets.length);
        for (uint256 i = 0; i < allAssets.length; i++) {
            _assets[i] = assets[allAssets[i]];
        }
        return _assets;
    }
}