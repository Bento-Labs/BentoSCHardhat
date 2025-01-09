// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {StableMath} from "../utils/StableMath.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {VaultAdmin} from "./VaultAdmin.sol";
import {BentoUSD} from "../BentoUSD.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EthenaWalletProxyManager} from "./EthenaWalletProxyManager.sol";
import {EthenaWalletProxy} from "../utils/EthenaWalletProxy.sol";
/**
 * @title VaultCore
 * @notice Core vault implementation for BentoUSD stablecoin system
 * @dev Handles minting, redeeming, and asset allocation operations
 */
contract VaultCore is Initializable, VaultAdmin, EthenaWalletProxyManager {
    using SafeERC20 for IERC20;
    using StableMath for uint256;
    uint256 public constant deviationTolerance = 1; // in percentage

    event Swap(
        address inputAsset,
        address outputAsset,
        address router,
        uint256 amount
    );

    event AssetAllocated(
        address asset,
        uint256 amount
    );

    error SwapFailed(string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === External State-Changing Functions ===
    
    function initialize(address _governor) public initializer {
        require(_governor != address(0), "Governor cannot be zero address");
        governor = _governor;
    }

    /**
     * @notice Mints BentoUSD tokens in exchange for a single supported asset
     * @param _recipient Address to receive minted BentoUSD
     * @param _asset Address of the input asset
     * @param _amount Amount of input asset to deposit
     * @param _minimumBentoUSDAmount Minimum acceptable BentoUSD output
     * @param _routers Array of DEX router addresses for swaps
     * @param _routerData Encoded swap data for each router
     */
    function mint(
        address _recipient,
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount,
        address[] calldata _routers,
        bytes[] calldata _routerData
    ) external {
        _mint(_recipient, _asset, _amount, _minimumBentoUSDAmount, _routers, _routerData);
    }

    /**
     * @notice Mints BentoUSD by depositing a proportional basket of all supported assets
     * @param _amount Total USD value to deposit
     * @param _minimumBentoUSDAmount Minimum acceptable BentoUSD output
     */
    function mintBasket(
        address _recipient,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount
    ) external {
        (uint256[] memory amounts, uint256 totalAmount) = getDepositAssetAmounts(_amount);
        for (uint256 i = 0; i < allAssets.length; i++) {
            address assetAddress = allAssets[i];
            IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), amounts[i]);
        }
        require(
            totalAmount > _minimumBentoUSDAmount,
            string(
                abi.encodePacked(
            "VaultCore: price deviation too high. Total value: ",
            Strings.toString(totalAmount),
            ", Minimum required: ",
                    Strings.toString(_minimumBentoUSDAmount)
                )
            )
        );
        BentoUSD(bentoUSD).mint(_recipient, totalAmount);
    }

    /**
     * @notice Redeems BentoUSD for liquid staking tokens of supported assets
     * @param _recipient Address to receive withdrawn assets
     * @param _amount Amount of BentoUSD to redeem
     */
    function redeemLTBasket(address _recipient, uint256 _amount) external {
        uint256[] memory ltAmounts = getOutputLTAmounts(_amount);
        require(IERC20(bentoUSD).balanceOf(msg.sender) >= _amount, "VaultCore: insufficient BentoUSD in user's wallet");
        BentoUSD(bentoUSD).burn(msg.sender, _amount);
        for (uint256 i = 0; i < allAssets.length; i++) {
            address assetAddress = allAssets[i];
            address ltToken = assetToAssetInfo[assetAddress].ltToken;
            require(IERC20(ltToken).balanceOf(address(this)) >= ltAmounts[i], "VaultCore: insufficient LT tokens in vault");
            IERC20(ltToken).safeTransfer(_recipient, ltAmounts[i]);
        }
    }

    function redeemUnderlyingBasket(address _recipient, uint256 _amount) external {
        _redeemUnderlyingBasket(_recipient, _amount);
    }

    /**
     * @notice Allocates excess assets in the vault to yield-generating strategies
     * @dev Can only be called by the governor
     */
    function allocate() external onlyGovernor {
        _allocate();
    }

    // === Internal State-Changing Functions ===

    function _mint(
        address _recipient,
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount,
        address[] calldata _routers,
        bytes[] calldata _routerData
    ) internal virtual {
        require(assetToAssetInfo[_asset].ltToken != address(0), "Asset is not supported");
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _routerData.length == allAssets.length,
            "Invalid router data length"
        );

        // store total weight into a memory variable to save gas
        uint256 _totalWeight = totalWeight;
        uint256 _allAssetsLength = allAssets.length;

        // store the total value of the basket
        uint256 totalValueOfBasket = 0;
        uint256 allAssetsLength = allAssets.length;
        // we iterate through all assets
        for (uint256 i = 0; i < allAssetsLength; i++) {
            address assetAddress = allAssets[i];
            // we only trade into assets that are not the asset we are depositing
            if (assetAddress != _asset) {
                AssetInfo memory asset = assetToAssetInfo[assetAddress];
                // get the balance of the asset before the trade
                uint256 balanceBefore = IERC20(assetAddress).balanceOf(
                    address(this)
                );
                // get asset price from oracle
                uint256 assetPrice = IOracle(oracleRouter).price(assetAddress);
                if (assetPrice > 1e18) {
                    assetPrice = 1e18;
                }
                _swap(_routers[i], _routerData[i]);
                // get the balance of the asset after the trade
                uint256 balanceAfter = IERC20(assetAddress).balanceOf(
                    address(this)
                );
                // get the amount of asset that is not in the balance after the trade
                uint256 outputAmount = balanceAfter - balanceBefore;
                emit Swap(
                    _asset,
                    assetAddress,
                    _routers[i],
                    outputAmount
                );
                uint256 expectedOutputAmount = (_amount * asset.weight) /
                    _totalWeight;
                uint256 deviation = (expectedOutputAmount > outputAmount)
                    ? expectedOutputAmount - outputAmount
                    : outputAmount - expectedOutputAmount;
                uint256 deviationPercentage = (deviation * 100) /
                    expectedOutputAmount;
                require(
                    deviationPercentage < deviationTolerance,
                    "VaultCore: deviation from desired weights too high"
                );
                totalValueOfBasket += (outputAmount * assetPrice) / 1e18;
            } else {
                uint256 assetPrice = IOracle(oracleRouter).price(assetAddress);
                totalValueOfBasket += (_amount * assetPrice) / 1e18;
            }
        }

        require(
            totalValueOfBasket > _minimumBentoUSDAmount,
            string(
                abi.encodePacked(
                    "VaultCore: price deviation too high. Total value: ",
                    Strings.toString(totalValueOfBasket),
                    ", Minimum required: ",
                    Strings.toString(_minimumBentoUSDAmount)
                )
            )
        );
        BentoUSD(bentoUSD).mint(_recipient, totalValueOfBasket);
    }

    function _swap(address _router, bytes calldata _routerData) internal {
        (bool success, bytes memory _data) = _router.call(_routerData);
        if (!success) {
            if (_data.length > 0) revert SwapFailed(string(_data));
            else revert SwapFailed("Unknown reason");
        }
    }

    function _redeemUnderlyingBasket(address _recipient, uint256 _amount) internal {
        uint256 allAssetsLength = allAssets.length;
        // first we try to withdraw from the buffer wallet inside the vault core
        // if not enough, we try to exchange the yield-bearing token to the underlying stable token
        for (uint256 i = 0; i < allAssetsLength; i++) {
            address assetAddress = allAssets[i];
            AssetInfo memory assetInfo = assetToAssetInfo[assetAddress];
            uint256 adjustedPrice = adjustPrice(IOracle(oracleRouter).price(assetAddress), true);
            uint256 amountToRedeem = (_amount *
                assetInfo.weight *
                1e18) / (totalWeight * adjustedPrice);
            // get the buffer balance
            uint256 amountInBuffer = IERC20(assetAddress).balanceOf(address(this));
            // we burn the BentoUSD tokens
            BentoUSD(bentoUSD).burn(msg.sender, _amount);
            if (amountInBuffer >= amountToRedeem) {
                // if the buffer has enough, we can just transfer the amount to the user
                IERC20(assetAddress).safeTransfer(_recipient, amountToRedeem);
            } else {
                // the missing amount is in underlying assets
                uint256 missingAmount = amountToRedeem - amountInBuffer;
                address ltToken = assetInfo.ltToken;
                if (assetInfo.strategyType == StrategyType.Generalized4626) {
                    // for ERC4626-compliant LTs we can withdraw directly
                    IERC4626(ltToken).withdraw(missingAmount, msg.sender, msg.sender);
                    IERC20(assetAddress).safeTransfer(_recipient, amountToRedeem);
                } else if (assetInfo.strategyType == StrategyType.Ethena) {
                    // the ethena wallet proxy corresponding to msg.sender
                    address ethenaWalletProxy = userToEthenaWalletProxy[msg.sender];
                    if (ethenaWalletProxy == address(0)) {
                        ethenaWalletProxy = address(new EthenaWalletProxy(ltToken, address(this)));
                        userToEthenaWalletProxy[msg.sender] = ethenaWalletProxy;
                    }
                    // we cannot withdraw yet, here we just start the unbonding period
                    commitWithdraw(msg.sender, missingAmount, ethenaWalletProxy);
                } else {
                    // for other types of LTs we perform the logics through a specialized strategy contract
                    // we need to send LTs to this strategy contract first
                    address strategy = assetInfo.strategy;
                    uint256 missingAmountInLT = IStrategy(strategy).convertToShares(missingAmount);
                    IERC20(ltToken).safeTransfer(strategy, missingAmountInLT);
                    IStrategy(strategy).redeem(_recipient, missingAmountInLT);
                    // the transfer of underlying assets to the user is done in the strategy contract
                }
            }
        }
    }

    function _redeemWithWaitingPeriod(uint256 _amount) internal {
        revert("VaultCore: redeemWithWaitingPeriod is not implemented");
    }

    function _allocate() internal virtual {
        uint256 allAssetsLength = allAssets.length;
        for (uint256 i = 0; i < allAssetsLength; ++i) {
            IERC20 asset = IERC20(allAssets[i]);
            uint256 assetBalance = asset.balanceOf(address(this));
            AssetInfo memory assetInfo = assetToAssetInfo[allAssets[i]];
            uint256 minimalAmount = assetInfo.minimalAmountInVault;
            if (assetBalance < minimalAmount) continue;
            // Multiply the balance by the vault buffer modifier and truncate
            // to the scale of the asset decimals
            uint256 allocateAmount = assetBalance - minimalAmount;

            // if the strategy is a generalized 4626 or ethena, we deposit into the lt token directly
            // otherwise we deposit into the strategy proxy
            if (assetInfo.strategyType == StrategyType.Generalized4626 || assetInfo.strategyType == StrategyType.Ethena) {
                IERC4626(assetInfo.ltToken).deposit(allocateAmount, address(this));
            } else {
                IStrategy(assetInfo.strategy).deposit(allocateAmount);
            }
            // the event should include how much LT tokens we get back
                emit AssetAllocated(
                    address(asset),
                    allocateAmount
                );
            }
        }

    // === Public/External View Functions ===

    /**
     * @notice Calculates the required amounts of each asset for a proportional deposit
     * @param desiredAmount Total USD value to be deposited
     * @return Array of asset amounts and total USD value
     */
    function getDepositAssetAmounts(uint256 desiredAmount) public view returns (uint256[] memory, uint256) {
        uint256 numberOfAssets = allAssets.length;
        uint256[] memory relativeWeights = new uint256[](numberOfAssets);
        uint256[] memory amounts = new uint256[](numberOfAssets);
        uint256 totalRelativeWeight = 0;
        for (uint256 i = 0; i < numberOfAssets; i++) {
            address assetAddress = allAssets[i];

            uint256 assetPrice = IOracle(oracleRouter).price(assetAddress);
            if (assetPrice > 1e18) {
                assetPrice = 1e18;
            }
            relativeWeights[i] = assetToAssetInfo[assetAddress].weight * assetPrice;
            totalRelativeWeight += relativeWeights[i];
        }
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < numberOfAssets; i++) {
            // we round it upwards to avoid rounding errors detrimental for the protocol
            amounts[i] = (desiredAmount * relativeWeights[i]) / totalRelativeWeight;
            totalAmount += amounts[i];
            amounts[i] = normalizeDecimals(IERC20Metadata(allAssets[i]).decimals(), amounts[i]);
        }
        return (amounts, totalAmount);
    }

    function getOutputLTAmounts(uint256 inputAmount) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](allAssets.length);
        address priceOracle = oracleRouter;
        for (uint256 i = 0; i < allAssets.length; i++) {
            address asset = allAssets[i];
            AssetInfo memory assetInfo = assetToAssetInfo[asset];
            // first we calculate the amount corresponding to the asset in USD 
            uint256 partialInputAmount = (inputAmount * assetInfo.weight) / totalWeight;
            uint256 adjustedPrice = adjustPrice(IOracle(priceOracle).price(asset), true);
            uint256 normalizedAmount = normalizeDecimals(assetInfo.decimals, partialInputAmount * 1e18 / adjustedPrice);
            amounts[i] = convertToLTAmount(normalizedAmount, asset, assetInfo.ltToken);
        }
        return amounts;
    }


    function convertToLTAmount(
        uint256 amount,
        address asset,
        address ltToken
    ) public view returns (uint256) {
        uint256 normalizedAmount = normalizeDecimals(assetToAssetInfo[asset].decimals, amount);
        return IERC4626(ltToken).convertToShares(normalizedAmount);
    }

    function getTotalValue() public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < allAssets.length; i++) {
            address asset = allAssets[i];
            // Get direct asset balance
            uint256 balance = IERC20(asset).balanceOf(address(this));
            
            // Get LT token balance and convert to underlying
            address ltToken = assetToAssetInfo[asset].ltToken;
            uint256 ltBalance = IERC20(ltToken).balanceOf(address(this));
            uint256 underlyingBalance = IERC4626(ltToken).convertToAssets(ltBalance);
            
            // Get total balance (direct + underlying from LT)
            uint256 totalBalance = balance + underlyingBalance;
            
            // Multiply by price to get USD value
            uint256 assetPrice = IOracle(oracleRouter).price(asset);
            totalValue += (totalBalance * assetPrice) / 1e18;
        }
        return totalValue;
    }

    // what is the purpose of this function?
    function getTokenToShareRatios() public view returns (uint256[] memory) {
        uint256 allAssetsLength = allAssets.length;
        uint256[] memory ratios = new uint256[](allAssetsLength);
        for (uint256 i = 0; i < allAssetsLength; i++) {
            address tokenAddress = allAssets[i];
            address ltToken = assetToAssetInfo[allAssets[i]].ltToken;
            uint256 unit = 10 ** IERC20Metadata(tokenAddress).decimals();
            ratios[i] = IERC4626(ltToken).convertToShares(unit);
        }
        return ratios;
    }

    // === Internal Pure Functions ===
    function adjustPrice(uint256 price, bool redeemFlag) internal pure returns (uint256) {
        if (redeemFlag) {
            if (price < 1e18) {
                price = 1e18;
            }
        } else {
            if (price > 1e18) {
                price = 1e18;
            }
        }
        return price;
    }

    function normalizeDecimals(uint8 assetDecimals, uint256 amount) internal pure returns (uint256) {
        if (assetDecimals < 18) {
            return amount / 10 ** (18 - assetDecimals);
        } else if (assetDecimals > 18) {
            return amount * 10 ** (assetDecimals - 18);
        }
        return amount;
    }
}
