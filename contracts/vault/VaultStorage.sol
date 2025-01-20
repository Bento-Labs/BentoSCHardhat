// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title BentoToken VaultStorage contract
 * @notice The VaultStorage contract defines the storage for the Vault contracts
 * @author Le Anh Dung, Bento Labs
 */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {AssetInfo, StrategyType} from "./VaultDefinitions.sol";
import {VaultErrors} from "./VaultErrors.sol";

contract VaultStorage is VaultErrors {
    using SafeERC20 for IERC20;



    uint256 public totalWeight;

    address public governor;
    address public bentoUSD;
    address public bentoUSDPlus;
    address public oracleRouter;

    /// @dev mapping of supported vault assets to their configuration
    // slither-disable-next-line uninitialized-state
    mapping(address => AssetInfo) public assetToAssetInfo;
    /// @dev list of all assets supported by the vault.
    // slither-disable-next-line uninitialized-state
    address[] public allAssets;

    function getAssetInfos() public view returns (AssetInfo[] memory) {
        AssetInfo[] memory _assets = new AssetInfo[](allAssets.length);
        for (uint256 i = 0; i < allAssets.length; i++) {
            _assets[i] = assetToAssetInfo[allAssets[i]];
        }
        return _assets;
    }

    function getAllAssets() public view returns (address[] memory) {
        return allAssets;
    }
}
