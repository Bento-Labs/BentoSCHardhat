// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IVaultCore {
    function assetToAssetInfo(address _asset) external view returns (address, uint256, uint256, uint256, uint256, uint256, uint256);
    function getWeights() external view returns (uint32[] memory);
    function getAllAssets() external view returns (address[] memory);
}