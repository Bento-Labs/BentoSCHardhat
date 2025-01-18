// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title bentoToken VaultAdmin contract
 * @notice The VaultAdmin contract makes configuration and admin calls on the vault.
 * @author Le Anh Dung
 */

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableMath} from "../utils/StableMath.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "./VaultStorage.sol";
import {AssetInfo, StrategyType} from "./VaultDefinitions.sol";

contract VaultAdmin is VaultStorage {
    using SafeERC20 for IERC20;
    using StableMath for uint256;

    event AssetAdded(address indexed asset, uint32 weight);
    event AssetRemoved(address indexed asset);

    /***************************************
                 Configuration
    ****************************************/

    modifier onlyGovernor() {
        if (msg.sender != governor) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @notice Set address of price provider.
     * @param _oracleRouter Address of price provider
     */
    function setOracleRouter(address _oracleRouter) external onlyGovernor {
        oracleRouter = _oracleRouter;
    }

    function setBentoUSD(address _bentoUSD) external onlyGovernor {
        bentoUSD = _bentoUSD;
    }

    function setBentoUSDPlus(address _bentoUSDPlus) external onlyGovernor {
        bentoUSDPlus = _bentoUSDPlus;
    }

    /* setAsset is used to add a new asset to the vault.
     *  _asset: the address of the asset
     *  _decimals: the number of decimals of the asset
     *  _weight: the weight of the asset
     *  _ltToken: the address of the underlying token
     *  _strategyType: the type of the strategy
     *  _strategy: the address of the strategy
     *  _minimalAmountInVault: the minimal amount of the asset in the vault
     */
    function setAsset(
        address _asset,
        uint8 _decimals,
        uint32 _weight,
        address _ltToken,
        StrategyType _strategyType,
        address _strategy,
        uint256 _minimalAmountInVault
    ) external onlyGovernor {
        if (_asset == address(0) || _ltToken == address(0)) {
            revert ZeroAddress();
        }
        // if the asset is not supported, add it to the list
        if (assetToAssetInfo[_asset].ltToken == address(0)) {
            allAssets.push(_asset);
            assetToAssetInfo[_asset].index = uint8(allAssets.length - 1);
        }
        // change the weight and also the total weight
        uint32 oldWeight = assetToAssetInfo[_asset].weight;
        _changeAssetWeight(_asset, oldWeight, _weight);
        
        AssetInfo storage asset = assetToAssetInfo[_asset];
        asset.ltToken = _ltToken;
        asset.weight = _weight;
        // this is the decimals of the underlying asset
        // we try to get the decimals from onchain source if possible
        try IERC20Metadata(_asset).decimals() returns (uint8 decimals_) {
            if (decimals_ != _decimals) {
                revert Inconsistency();
            }
            asset.decimals = decimals_;
        } catch {
            asset.decimals = _decimals;
        }
        asset.strategyType = _strategyType;
        if (_strategyType == StrategyType.Generalized4626 || _strategyType == StrategyType.Ethena) {
            if (_strategy != address(0)) {
                revert DefaultValueRequired();
            }
        } else {
            if (_strategy == address(0)) {
                revert Inconsistency();
            }
        }
        if (_strategyType != StrategyType.Other) {
            if (IERC4626(_ltToken).asset() != _asset) {
                revert Inconsistency();
            }
        }
        asset.minimalAmountInVault = _minimalAmountInVault;

        emit AssetAdded(_asset, _weight);
    }

    /* removeAsset is used to remove an asset from the vault.
     *  _asset: the address of the asset
     */
    function removeAsset(address _asset) external onlyGovernor {
        if (assetToAssetInfo[_asset].ltToken == address(0)) {
            revert ZeroAddress();
        }
        _changeAssetWeight(_asset, assetToAssetInfo[_asset].weight, 0);
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == _asset) {
                allAssets[i] = allAssets[allAssets.length - 1];
                // since we move the last element to the current position, we need to update the index of the new last element
                assetToAssetInfo[allAssets[i]].index = uint8(i);
                allAssets.pop();
                break;
            }
        }
        emit AssetRemoved(_asset);
    }

    /* _changeAssetWeight is used to change the weight of an asset and also the totalWeight of all assets.
     *  _asset: the address of the asset
     *  _oldWeight: the old weight of the asset
     *  _newWeight: the new weight of the asset
     */
    function _changeAssetWeight(
        address _asset,
        uint32 _oldWeight,
        uint32 _newWeight
    ) internal {
        totalWeight = totalWeight + _newWeight - _oldWeight;
        assetToAssetInfo[_asset].weight = _newWeight;
    }
}
