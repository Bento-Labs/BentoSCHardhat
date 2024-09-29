// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BentoToken VaultCore contract
 * @notice The Vault contract stores assets. On a deposit, BentoTokens will be minted
           and sent to the depositor. On a withdrawal, BentoTokens will be burned and
           assets will be sent to the withdrawer. 
 * @author Modified from Origin Protocol Inc by Le Anh Dung
 */

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { StableMath } from "../utils/StableMath.sol";
import { IOracle } from "../interfaces/IOracle.sol";
import { IGetExchangeRateToken } from "../interfaces/IGetExchangeRateToken.sol";
import { IDripper } from "../interfaces/IDripper.sol";

import "./VaultInitializer.sol";

contract VaultCore is VaultInitializer {
    using SafeERC20 for IERC20;
    using StableMath for uint256;

    uint256 public constant deviationTolerance = 1; // in percentage

    /**
     * @notice Deposit a supported asset and mint BentoUSD.
     * @param _asset Address of the asset being deposited
     * @param _amount Amount of the asset being deposited
     * @param _minimumOusdAmount Minimum OTokens to mint
     */
    function mint(
        address _asset,
        uint256 _amount,
        address _router,
        uint256 _minimumBentoUSDAmount
    ) external nonReentrant {
        _mint(_asset, _amount, _minimumBentoUSDAmount);
    }

    function _mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount,
        bytes[] calldata _routerData
    ) internal virtual {
        require(assets[_asset].isSupported, "Asset is not supported");
        require(_amount > 0, "Amount must be greater than 0");
        require(_routerData.length == allAssets.length, "Invalid router data length");

        // store total weight into a memory variable to save gas
        uint256 _totalWeight = totalWeight; 
        uint256 _allAssetsLength = allAssets.length;

        // store the total value of the basket
        uint256 totalValueOfBasket = 0;
        // we iterate through all assets
        for (uint256 i = 0; i < _allAssetsLength; i++) {
            address assetAddress = allAssets[i];
            // we only trade into assets that are not the asset we are depositing
            if (assetAddress !== _asset) {
                Asset memory asset = assets[assetAddress];
                // get the balance of the asset before the trade
                uint256 balanceBefore = IERC20(assetAddress).balanceOf(address(this));
                // get asset price from oracle
                uint256 assetPrice = IOracle(asset.oracle).getAssetPrice(assetAddress);
                if (assetPrice < 1e18) {
                    assetPrice = 1e18;
                }
                _swap(_router, _routerData[i]);
                // get the balance of the asset after the trade
                uint256 balanceAfter = IERC20(assetAddress).balanceOf(address(this));
                // get the amount of asset that is not in the balance after the trade
                uint256 outputAmount = balanceAfter - balanceBefore;
                uint256 expectedOutputAmount = _amount * asset.weight / _totalWeight;
                uint256 deviationPercentage = (expectedOutputAmount - outputAmount).abs() * 100 / expectedOutputAmount;
                require(deviationPercentage < deviationTolerance, "VaultCore: deviation from desired weights too high");
                totalValueOfBasket += outputAmount * assetPrice / 1e18;
            } else {
                uint256 assetPrice = IOracle(asset.oracle).getAssetPrice(assetAddress);
                totalValueOfBasket += _amount * assetPrice / 1e18;
            }
        }

        require(totalValueOfBasket > _minimumBentoUSDAmount, "VaultCore: slippage or price deviation too high");
        bentoUSD.mint(msg.sender, totalValueOfBasket);

        emit Mint(msg.sender, totalValueOfBasket);
    }

    function mintBasket(uint256 _amount, uint256 _minimumBentoUSDAmount) external {
        uint256 totalValueOfBasket = 0;
        for (uint256 i = 0; i < allAssets.length; i++) {
            address assetAddress = allAssets[i];
            uint256 amountToDeposit = _amount * assets[assetAddress].weight / totalWeight;
            
            uint256 assetPrice = IOracle(asset.oracle).getAssetPrice(assetAddress);
            if (assetPrice < 1e18) {
                assetPrice = 1e18;
            }
            totalValueOfBasket += amountToDeposit * assetPrice / 1e18;
        }
        require(totalValueOfBasket > _minimumBentoUSDAmount, "VaultCore: price deviation too high");
        bentoUSD.mint(msg.sender, totalValueOfBasket);
        emit Mint(msg.sender, totalValueOfBasket);
    }

    function _swap(
        address _router,
        bytes calldata _routerData
    ) internal {
        (bool success, bytes memory _data) =
            _router.call(_routerData);
        if (!success) {
            if (_data.length > 0) revert SwapFailed(string(_data));
            else revert SwapFailed("Unknown reason");
        }
        return _data;
    };
}
