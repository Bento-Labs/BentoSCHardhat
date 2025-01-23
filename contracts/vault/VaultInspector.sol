// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {VaultCore} from "./VaultCore.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AssetInfo} from "./VaultDefinitions.sol";

/**
 * @title VaultInspector
 * @notice This contract allows users to query information about assets and their configurations in the vault
 */
contract VaultInspector {
    VaultCore public vault;

    constructor(address _vault) {
        vault = VaultCore(_vault);
    }

    /**
     * @notice Retrieves the liquid token (ltToken) associated with a given asset
     * @param _asset The address of the asset
     * @return The address of the ltToken
     */
    function getLtToken(address _asset) public view returns (address) {
        (address _ltToken, , , , , ,  ) = vault.assetToAssetInfo(_asset);
        return _ltToken;
    }

    /**
     * @notice Retrieves the conversion ratios from tokens to shares for all assets in the vault
     * @return An array of conversion ratios
     */
    function getTokenToShareRatios() public view returns (uint256[] memory) {
        address[] memory allAssets = vault.getAllAssets();
        uint256 allAssetsLength = allAssets.length;
        uint256[] memory ratios = new uint256[](allAssetsLength);
        for (uint256 i = 0; i < allAssetsLength; ++i) {
            address tokenAddress = allAssets[i];
            address ltToken = getLtToken(tokenAddress);
            uint256 unit = 10 ** IERC20Metadata(tokenAddress).decimals();
            ratios[i] = IERC4626(ltToken).convertToShares(unit);
        }
        return ratios;
    }

    /**
     * @notice Retrieves the weights of all assets in the vault
     * @return An array of asset weights
     */
    function getWeights() public view returns (uint32[] memory) {
        address[] memory allAssets = vault.getAllAssets();
        uint32[] memory weights = new uint32[](allAssets.length);
        uint256 allAssetsLength = allAssets.length;
        for (uint256 i = 0; i < allAssetsLength; ++i) {
            ( , uint32 weight, , , , ,  ) = vault.assetToAssetInfo(allAssets[i]);
            weights[i] = weight;
        }
        return weights;
    }
}
