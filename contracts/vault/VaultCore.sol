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
    // max signed int
    uint256 internal constant MAX_INT = 2**255 - 1;
    // max un-signed int
    uint256 internal constant MAX_UINT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /**
     * @dev Verifies that the deposits are not paused.
     */
    modifier whenNotCapitalPaused() {
        require(!capitalPaused, "Capital paused");
        _;
    }

    /**
     * @notice Deposit a supported asset and mint OTokens.
     * @param _asset Address of the asset being deposited
     * @param _amount Amount of the asset being deposited
     * @param _minimumOusdAmount Minimum OTokens to mint
     */
    function mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount
    ) external whenNotCapitalPaused nonReentrant {
        _mint(_asset, _amount, _minimumBentoUSDAmount);
    }

    function _mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount
    ) internal virtual {
        require(assets[_asset].isSupported, "Asset is not supported");
        require(_amount > 0, "Amount must be greater than 0");

        // store total weight into a memory variable to save gas
        uint256 _totalWeight = totalWeight; 
        uint256 _allAssetsLength = allAssets.length;
        uint256[] memory amountsToTrade = new uint256[](_allAssetsLength);

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
                amountsToTrade[i] = _amount * asset.weight / _totalWeight;
                // get asset price from oracle
                uint256 assetPrice = IOracle(asset.oracle).getAssetPrice(assetAddress);
                if (assetPrice < 1e18) {
                    assetPrice = 1e18;
                }
                // TODO: make the trade in cowswap
                // get the balance of the asset after the trade
                uint256 balanceAfter = IERC20(assetAddress).balanceOf(address(this));
                // get the amount of asset that is not in the balance after the trade
                uint256 amountTraded = balanceAfter - balanceBefore;
                totalValueOfBasket += amountTraded * assetPrice / 1e18;
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



    /**
     * @notice Withdraw a supported asset and burn OTokens.
     * @param _amount Amount of OTokens to burn
     * @param _minimumUnitAmount Minimum stablecoin units to receive in return
     */
    function _redeem(uint256 _amount, uint256 _minimumUnitAmount)
        internal
        virtual
    {
        
    }

    /**
     * @notice Withdraw a supported asset and burn all OTokens.
     * @param _minimumUnitAmount Minimum stablecoin units to receive in return
     */
    function redeemAll(uint256 _minimumUnitAmount)
        external
        whenNotCapitalPaused
        nonReentrant
    {
        _redeem(oUSD.balanceOf(msg.sender), _minimumUnitAmount);
    }

    /**
     * @notice Determine the total value of assets held by the vault and its
     *         strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function totalValue() external view virtual returns (uint256 value) {
        value = _totalValue();
    }

    /**
     * @dev Internal Calculate the total value of the assets held by the
     *         vault and its strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValue() internal view virtual returns (uint256 value) {
        return _totalValueInVault() + _totalValueInStrategies();
    }

    /**
     * @dev Internal to calculate total value of all assets held in Vault.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueInVault()
        internal
        view
        virtual
        returns (uint256 value)
    {
        uint256 assetCount = allAssets.length;
        for (uint256 y = 0; y < assetCount; ++y) {
            address assetAddr = allAssets[y];
            uint256 balance = IERC20(assetAddr).balanceOf(address(this));
            if (balance > 0) {
                value += _toUnits(balance, assetAddr);
            }
        }
    }

    /**
     * @dev Internal to calculate total value of all assets held in Strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueInStrategies() internal view returns (uint256 value) {
        uint256 stratCount = allStrategies.length;
        for (uint256 i = 0; i < stratCount; ++i) {
            value = value + _totalValueInStrategy(allStrategies[i]);
        }
    }

    /**
     * @dev Internal to calculate total value of all assets held by strategy.
     * @param _strategyAddr Address of the strategy
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueInStrategy(address _strategyAddr)
        internal
        view
        returns (uint256 value)
    {
        IStrategy strategy = IStrategy(_strategyAddr);
        uint256 assetCount = allAssets.length;
        for (uint256 y = 0; y < assetCount; ++y) {
            address assetAddr = allAssets[y];
            if (strategy.supportsAsset(assetAddr)) {
                uint256 balance = strategy.checkBalance(assetAddr);
                if (balance > 0) {
                    value += _toUnits(balance, assetAddr);
                }
            }
        }
    }

    /**
     * @notice Get the balance of an asset held in Vault and all strategies.
     * @param _asset Address of asset
     * @return uint256 Balance of asset in decimals of asset
     */
    function checkBalance(address _asset) external view returns (uint256) {
        return _checkBalance(_asset);
    }

    /**
     * @notice Get the balance of an asset held in Vault and all strategies.
     * @param _asset Address of asset
     * @return balance Balance of asset in decimals of asset
     */
    function _checkBalance(address _asset)
        internal
        view
        virtual
        returns (uint256 balance)
    {
        IERC20 asset = IERC20(_asset);
        balance = asset.balanceOf(address(this));
        uint256 stratCount = allStrategies.length;
        for (uint256 i = 0; i < stratCount; ++i) {
            IStrategy strategy = IStrategy(allStrategies[i]);
            if (strategy.supportsAsset(_asset)) {
                balance = balance + strategy.checkBalance(_asset);
            }
        }
    }

    /**
     * @notice Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned
     */
    function calculateRedeemOutputs(uint256 _amount)
        external
        view
        returns (uint256[] memory)
    {
        return _calculateRedeemOutputs(_amount);
    }

    /**
     * @dev Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned.
     * @return outputs Array of amounts respective to the supported assets
     */
    function _calculateRedeemOutputs(uint256 _amount)
        internal
        view
        virtual
        returns (uint256[] memory outputs)
    {
        // We always give out coins in proportion to how many we have,
        // Now if all coins were the same value, this math would easy,
        // just take the percentage of each coin, and multiply by the
        // value to be given out. But if coins are worth more than $1,
        // then we would end up handing out too many coins. We need to
        // adjust by the total value of coins.
        //
        // To do this, we total up the value of our coins, by their
        // percentages. Then divide what we would otherwise give out by
        // this number.
        //
        // Let say we have 100 DAI at $1.06  and 200 USDT at $1.00.
        // So for every 1 DAI we give out, we'll be handing out 2 USDT
        // Our total output ratio is: 33% * 1.06 + 66% * 1.00 = 1.02
        //
        // So when calculating the output, we take the percentage of
        // each coin, times the desired output value, divided by the
        // totalOutputRatio.
        //
        // For example, withdrawing: 30 OUSD:
        // DAI 33% * 30 / 1.02 = 9.80 DAI
        // USDT = 66 % * 30 / 1.02 = 19.60 USDT
        //
        // Checking these numbers:
        // 9.80 DAI * 1.06 = $10.40
        // 19.60 USDT * 1.00 = $19.60
        //
        // And so the user gets $10.40 + $19.60 = $30 worth of value.

        uint256 assetCount = allAssets.length;
        uint256[] memory assetUnits = new uint256[](assetCount);
        uint256[] memory assetBalances = new uint256[](assetCount);
        outputs = new uint256[](assetCount);

        // Calculate redeem fee
        if (redeemFeeBps > 0) {
            uint256 redeemFee = _amount.mulTruncateScale(redeemFeeBps, 1e4);
            _amount = _amount - redeemFee;
        }

        // Calculate assets balances and decimals once,
        // for a large gas savings.
        uint256 totalUnits = 0;
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddr = allAssets[i];
            uint256 balance = _checkBalance(assetAddr);
            assetBalances[i] = balance;
            assetUnits[i] = _toUnits(balance, assetAddr);
            totalUnits = totalUnits + assetUnits[i];
        }
        // Calculate totalOutputRatio
        uint256 totalOutputRatio = 0;
        for (uint256 i = 0; i < assetCount; ++i) {
            uint256 unitPrice = _toUnitPrice(allAssets[i], false);
            uint256 ratio = (assetUnits[i] * unitPrice) / totalUnits;
            totalOutputRatio = totalOutputRatio + ratio;
        }
        // Calculate final outputs
        uint256 factor = _amount.divPrecisely(totalOutputRatio);
        for (uint256 i = 0; i < assetCount; ++i) {
            outputs[i] = (assetBalances[i] * factor) / totalUnits;
        }
    }

    /***************************************
                    Pricing
    ****************************************/

    /**
     * @notice Returns the total price in 18 digit units for a given asset.
     *      Never goes above 1, since that is how we price mints.
     * @param asset address of the asset
     * @return price uint256: unit (USD / ETH) price for 1 unit of the asset, in 18 decimal fixed
     */
    function priceUnitMint(address asset)
        external
        view
        returns (uint256 price)
    {
        /* need to supply 1 asset unit in asset's decimals and can not just hard-code
         * to 1e18 and ignore calling `_toUnits` since we need to consider assets
         * with the exchange rate
         */
        uint256 units = _toUnits(
            uint256(1e18).scaleBy(_getDecimals(asset), 18),
            asset
        );
        price = (_toUnitPrice(asset, true) * units) / 1e18;
    }

    /**
     * @notice Returns the total price in 18 digit unit for a given asset.
     *      Never goes below 1, since that is how we price redeems
     * @param asset Address of the asset
     * @return price uint256: unit (USD / ETH) price for 1 unit of the asset, in 18 decimal fixed
     */
    function priceUnitRedeem(address asset)
        external
        view
        returns (uint256 price)
    {
        /* need to supply 1 asset unit in asset's decimals and can not just hard-code
         * to 1e18 and ignore calling `_toUnits` since we need to consider assets
         * with the exchange rate
         */
        uint256 units = _toUnits(
            uint256(1e18).scaleBy(_getDecimals(asset), 18),
            asset
        );
        price = (_toUnitPrice(asset, false) * units) / 1e18;
    }

    /***************************************
                    Utils
    ****************************************/

    /**
     * @dev Convert a quantity of a token into 1e18 fixed decimal "units"
     * in the underlying base (USD/ETH) used by the vault.
     * Price is not taken into account, only quantity.
     *
     * Examples of this conversion:
     *
     * - 1e18 DAI becomes 1e18 units (same decimals)
     * - 1e6 USDC becomes 1e18 units (decimal conversion)
     * - 1e18 rETH becomes 1.2e18 units (exchange rate conversion)
     *
     * @param _raw Quantity of asset
     * @param _asset Core Asset address
     * @return value 1e18 normalized quantity of units
     */
    function _toUnits(uint256 _raw, address _asset)
        internal
        view
        returns (uint256)
    {
        UnitConversion conversion = assets[_asset].unitConversion;
        if (conversion == UnitConversion.DECIMALS) {
            return _raw.scaleBy(18, _getDecimals(_asset));
        } else if (conversion == UnitConversion.GETEXCHANGERATE) {
            uint256 exchangeRate = IGetExchangeRateToken(_asset)
                .getExchangeRate();
            return (_raw * exchangeRate) / 1e18;
        } else {
            revert("Unsupported conversion type");
        }
    }

    /**
     * @dev Returns asset's unit price accounting for different asset types
     *      and takes into account the context in which that price exists -
     *      - mint or redeem.
     *
     * Note: since we are returning the price of the unit and not the one of the
     * asset (see comment above how 1 rETH exchanges for 1.2 units) we need
     * to make the Oracle price adjustment as well since we are pricing the
     * units and not the assets.
     *
     * The price also snaps to a "full unit price" in case a mint or redeem
     * action would be unfavourable to the protocol.
     *
     */
    function _toUnitPrice(address _asset, bool isMint)
        internal
        view
        returns (uint256 price)
    {
        UnitConversion conversion = assets[_asset].unitConversion;
        price = IOracle(priceProvider).price(_asset);

        if (conversion == UnitConversion.GETEXCHANGERATE) {
            uint256 exchangeRate = IGetExchangeRateToken(_asset)
                .getExchangeRate();
            price = (price * 1e18) / exchangeRate;
        } else if (conversion != UnitConversion.DECIMALS) {
            revert("Unsupported conversion type");
        }

        /* At this stage the price is already adjusted to the unit
         * so the price checks are agnostic to underlying asset being
         * pegged to a USD or to an ETH or having a custom exchange rate.
         */
        require(price <= MAX_UNIT_PRICE_DRIFT, "Vault: Price exceeds max");
        require(price >= MIN_UNIT_PRICE_DRIFT, "Vault: Price under min");

        if (isMint) {
            /* Never price a normalized unit price for more than one
             * unit of OETH/OUSD when minting.
             */
            if (price > 1e18) {
                price = 1e18;
            }
            require(price >= MINT_MINIMUM_UNIT_PRICE, "Asset price below peg");
        } else {
            /* Never give out more than 1 normalized unit amount of assets
             * for one unit of OETH/OUSD when redeeming.
             */
            if (price < 1e18) {
                price = 1e18;
            }
        }
    }

    function _getDecimals(address _asset)
        internal
        view
        returns (uint256 decimals)
    {
        decimals = assets[_asset].decimals;
        require(decimals > 0, "Decimals not cached");
    }

    /**
     * @notice Return the number of assets supported by the Vault.
     */
    function getAssetCount() public view returns (uint256) {
        return allAssets.length;
    }

    /**
     * @notice Gets the vault configuration of a supported asset.
     */
    function getAssetConfig(address _asset)
        public
        view
        returns (Asset memory config)
    {
        config = assets[_asset];
    }

    /**
     * @notice Return all vault asset addresses in order
     */
    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }

    /**
     * @notice Return the number of strategies active on the Vault.
     */
    function getStrategyCount() external view returns (uint256) {
        return allStrategies.length;
    }

    /**
     * @notice Return the array of all strategies
     */
    function getAllStrategies() external view returns (address[] memory) {
        return allStrategies;
    }

    /**
     * @notice Returns whether the vault supports the asset
     * @param _asset address of the asset
     * @return true if supported
     */
    function isSupportedAsset(address _asset) external view returns (bool) {
        return assets[_asset].isSupported;
    }

    /**
     * @dev Falldown to the admin implementation
     * @notice This is a catch all for all functions not declared in core
     */
    // solhint-disable-next-line no-complex-fallback
    fallback() external {
        bytes32 slot = adminImplPosition;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                sload(slot),
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function abs(int256 x) private pure returns (uint256) {
        require(x < int256(MAX_INT), "Amount too high");
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}
