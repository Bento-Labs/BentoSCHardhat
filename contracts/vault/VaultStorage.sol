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
        address ltToken;
        uint32 weight;
        uint8 decimals;
        bool isSupported;
        StrategyType strategyType;
        address strategy;
        uint256 minimalAmountInVault;
    }

    enum StrategyType {
        Generalized4626,
        Ethena,
        Other
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