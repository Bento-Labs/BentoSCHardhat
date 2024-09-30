// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title bentoToken VaultAdmin contract
 * @notice The VaultAdmin contract makes configuration and admin calls on the vault.
 * @author Modified from Origin Protocol Inc by Le Anh Dung
 */

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StableMath } from "../utils/StableMath.sol";

import { IOracle } from "../interfaces/IOracle.sol";
import "./VaultStorage.sol";

contract VaultAdmin is VaultStorage {
    using SafeERC20 for IERC20;
    using StableMath for uint256;

    event AssetAdded(address indexed asset, uint8 decimals, uint8 weight);
    event AssetRemoved(address indexed asset);
    event AssetChanged(address indexed asset, uint8 decimals, uint8 weight);
    event OracleRouterUpdated(address indexed oracleRouter);
    event BentoUSDUpdated(address indexed bentoUSD);
    event GovernorUpdated(address indexed governor);
    event AssetWeightChanged(address indexed asset, uint8 oldWeight, uint8 newWeight);


    /***************************************
                 Configuration
    ****************************************/

    modifier onlyGovernor() {
        require(msg.sender == governor, "Only governor can call this function");
        _;
    }

    /**
     * @notice Set address of price provider.
     * @param _oracleRouter Address of price provider
     */
    function setOracleRouter(address _oracleRouter) external onlyGovernor {
        oracleRouter = _oracleRouter;
        emit OracleRouterUpdated(_oracleRouter);
    }

    function setBentoUSD(address _bentoUSD) external onlyGovernor {
        bentoUSD = _bentoUSD;
        emit BentoUSDUpdated(_bentoUSD);
    }
    /* setAsset is used to add a new asset to the vault.
    *  _asset: the address of the asset
    *  _decimals: the number of decimals of the asset
    *  _weight: the weight of the asset
    */
    function setAsset(address _asset, uint8 _decimals, uint8 _weight) external onlyGovernor {
        require(!assets[_asset].isSupported, "Asset is already supported");
        _changeAssetWeight(_asset, 0, _weight);
        assets[_asset].isSupported = true;
        assets[_asset].decimals = _decimals;
        allAssets.push(_asset);
        emit AssetAdded(_asset, _decimals, _weight);
    }

    /* removeAsset is used to remove an asset from the vault.
    *  _asset: the address of the asset
    */
    function removeAsset(address _asset) external onlyGovernor {
        require(assets[_asset].isSupported, "Asset is not supported");
        _changeAssetWeight(_asset, assets[_asset].weight, 0);
        assets[_asset].isSupported = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == _asset) {
                allAssets[i] = allAssets[allAssets.length - 1];
                allAssets.pop();
                break;
            }
        }
        emit AssetRemoved(_asset);
    }

    /* changeAsset is used to change the weight of an asset in the vault.
    *  _asset: the address of the asset
    *  _decimals: the new number of decimals of the asset
    *  _weight: the new weight of the asset
    */
    function changeAsset(address _asset, uint8 _decimals, uint8 _weight) external onlyGovernor {
        require(assets[_asset].isSupported, "Asset is not supported");
        _changeAssetWeight(_asset, assets[_asset].weight, _weight);
        assets[_asset].decimals = _decimals;
        emit AssetChanged(_asset, _decimals, _weight);
    }

    /* _changeAssetWeight is used to change the weight of an asset and also the totalWeight of all assets.
    *  _asset: the address of the asset
    *  _oldWeight: the old weight of the asset
    *  _newWeight: the new weight of the asset
    */
    function _changeAssetWeight(address _asset, uint8 _oldWeight, uint8 _newWeight) internal {
        totalWeight = totalWeight + _newWeight - _oldWeight;
        assets[_asset].weight = _newWeight;
        emit AssetWeightChanged(_asset, _oldWeight, _newWeight);
    }
}
