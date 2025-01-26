// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;
import {AssetInfo} from "../vault/VaultDefinitions.sol";

interface IVaultCore {
    function assetToAssetInfo(address _asset) external view returns (AssetInfo memory);
    function getWeights() external view returns (uint32[] memory);
    function getAllAssets() external view returns (address[] memory);
}