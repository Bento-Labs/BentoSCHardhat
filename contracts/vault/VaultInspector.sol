// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VaultCore} from "./VaultCore.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {AssetInfo} from "./VaultDefinitions.sol";

contract VaultInspector {
    VaultCore public vault;

    constructor(address _vault) {
        vault = VaultCore(_vault);
    }

    function getLtToken(address _asset) public view returns (address) {
        (address _ltToken, , , , , ,  ) = vault.assetToAssetInfo(_asset);
        return _ltToken;
    }

        // what is the purpose of this function?
    function getTokenToShareRatios() public view returns (uint256[] memory) {
        address[] memory allAssets = vault.getAllAssets();
        uint256 allAssetsLength = allAssets.length;
        uint256[] memory ratios = new uint256[](allAssetsLength);
        for (uint256 i = 0; i < allAssetsLength; i++) {
            address tokenAddress = allAssets[i];
            address ltToken = getLtToken(tokenAddress);
            uint256 unit = 10 ** IERC20Metadata(tokenAddress).decimals();
            ratios[i] = IERC4626(ltToken).convertToShares(unit);
        }
        return ratios;
    }

    function getWeights() public view returns (uint32[] memory) {
        address[] memory allAssets = vault.getAllAssets();
        uint32[] memory weights = new uint32[](allAssets.length);
        for (uint256 i = 0; i < allAssets.length; i++) {
            ( , uint32 weight, , , , ,  ) = vault.assetToAssetInfo(allAssets[i]);
            weights[i] = weight;
        }
        return weights;
    }


}
