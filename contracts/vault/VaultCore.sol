// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

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
import {AssetInfo, StrategyType} from "./VaultDefinitions.sol";

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
        require(_governor != address(0), "1");
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
    function mintWithOneToken(
        address _recipient,
        address _asset,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount,
        address[] calldata _routers,
        bytes[] calldata _routerData
    ) external {
        // Implementation here
    }

    /**
     * @notice Mints BentoUSD by depositing a proportional basket of all supported assets
     * @param _recipient Address to receive minted BentoUSD
     * @param _amount Total USD value to deposit
     * @param _minimumBentoUSDAmount Minimum acceptable BentoUSD output
     */
    function mintBasket(
        address _recipient,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount
    ) public {
        (uint256[] memory amounts, uint256 totalAmount) = getDepositAssetAmounts(_amount);
        for (uint256 i = 0; i < allAssets.length; i++) {
            address assetAddress = allAssets[i];
            IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), amounts[i]);
        }
        require(
            totalAmount > _minimumBentoUSDAmount,
            string(
                abi.encodePacked(
                    "2",
                    Strings.toString(totalAmount),
                    ",",
                    Strings.toString(_minimumBentoUSDAmount)
                )
            )
        );
        BentoUSD(bentoUSD).mint(_recipient, totalAmount);
    }

    /**
     * @notice Mints BentoUSD and stakes it in BentoUSDPlus
     * @param _recipient Address to receive staked BentoUSDPlus
     * @param _amount Total USD value to deposit
     * @param _minimumBentoUSDAmount Minimum acceptable BentoUSD output
     */
    function mintWithBasketAndStake(
        address _recipient,
        uint256 _amount,
        uint256 _minimumBentoUSDAmount
    ) external {
        mintBasket(address(this), _amount, _minimumBentoUSDAmount);
        BentoUSD(bentoUSD).approve(address(bentoUSDPlus), _amount);
        IERC4626(bentoUSDPlus).deposit(_amount, _recipient);
    }

    /**
     * @notice Redeems BentoUSD for liquid staking tokens of supported assets
     * @param _recipient Address to receive withdrawn assets
     * @param _amount Amount of BentoUSD to redeem
     */
    function redeemLTBasket(address _recipient, uint256 _amount) external {
        uint256[] memory ltAmounts = getOutputLTAmounts(_amount);
        BentoUSD(bentoUSD).burn(msg.sender, _amount);
        for (uint256 i = 0; i < allAssets.length; i++) {
            address assetAddress = allAssets[i];
            address ltToken = assetToAssetInfo[assetAddress].ltToken;
            require(IERC20(ltToken).balanceOf(address(this)) >= ltAmounts[i], "4");
            IERC20(ltToken).safeTransfer(_recipient, ltAmounts[i]);
        }
    }

    /**
     * @notice Redeems BentoUSD for underlying assets
     * @param _recipient Address to receive withdrawn assets
     * @param _amount Amount of BentoUSD to redeem
     */
    function redeemUnderlyingBasket(address _recipient, uint256 _amount) external {
        uint256 allAssetsLength = allAssets.length;
        // we burn the BentoUSD tokens
        BentoUSD(bentoUSD).burn(msg.sender, _amount);
        // first we try to withdraw from the buffer wallet inside the vault core
        // if not enough, we try to exchange the yield-bearing token to the underlying stable token
        for (uint256 i = 0; i < allAssetsLength; i++) {
            address assetAddress = allAssets[i];
            AssetInfo memory assetInfo = assetToAssetInfo[assetAddress];
            uint256 adjustedPrice = adjustPrice(IOracle(oracleRouter).price(assetAddress), true);
            uint256 amountToRedeem = (_amount *
                assetInfo.weight *
                1e18) / (totalWeight * adjustedPrice);
            // we need to scale the decimals
            amountToRedeem = scaleDecimals(amountToRedeem, 18, assetInfo.decimals);
            // get the buffer balance
            uint256 amountInBuffer = IERC20(assetAddress).balanceOf(address(this));
            if (amountInBuffer >= amountToRedeem) {
                // if the buffer has enough, we can just transfer the amount to the user
                IERC20(assetAddress).safeTransfer(_recipient, amountToRedeem);
            } else {
                // the missing amount is in underlying assets
                uint256 missingAmount = amountToRedeem - amountInBuffer;
                address ltToken = assetInfo.ltToken;
                if (assetInfo.strategyType == StrategyType.Generalized4626) {
                    // for ERC4626-compliant LTs we can withdraw directly
                    // msg.sender is the receiver and this contract is currently holding the LTs
                    IERC4626(ltToken).withdraw(missingAmount, msg.sender, address(this));
                } else if (assetInfo.strategyType == StrategyType.Ethena) {
                    // the ethena wallet proxy corresponding to msg.sender
                    address ethenaWalletProxy = userToEthenaWalletProxy[msg.sender];
                    if (ethenaWalletProxy == address(0)) {
                        ethenaWalletProxy = address(new EthenaWalletProxy(ltToken, address(this)));
                        userToEthenaWalletProxy[msg.sender] = ethenaWalletProxy;
                    }

                    // we cannot withdraw yet, here we just start the unbonding period
                    uint256 missingAmountInLT = IERC4626(ltToken).convertToShares(missingAmount);
                    IERC4626(ltToken).transfer(ethenaWalletProxy, missingAmountInLT);
                    commitWithdraw(missingAmountInLT, ethenaWalletProxy);
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

    /**
     * @notice Allocates excess assets in the vault to yield-generating strategies
     * @dev Can only be called by the governor
     */
    function allocate() external onlyGovernor {
        _allocate();
    }

    // === Internal State-Changing Functions ===

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
                address ltToken = assetInfo.ltToken;
                // if the asset is USDT, we need to set the allowance to 0 first
                if (address(asset) == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
                    asset.safeApprove(ltToken, 0);
                } 
                asset.safeApprove(ltToken, allocateAmount);
                IERC4626(ltToken).deposit(allocateAmount, address(this));
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
        // the relative weights also take into account the price of the asset
        uint256[] memory relativeWeights = new uint256[](numberOfAssets);
        uint256[] memory amounts = new uint256[](numberOfAssets);
        uint256 totalRelativeWeight = 0;
        for (uint256 i = 0; i < numberOfAssets; i++) {
            address assetAddress = allAssets[i];
            // we round it upwards to avoid rounding errors detrimental for the protocol
            uint256 assetPrice = IOracle(oracleRouter).price(assetAddress);
            if (assetPrice > 1e18) {
                assetPrice = 1e18;
            }
            relativeWeights[i] = assetToAssetInfo[assetAddress].weight * assetPrice;
            totalRelativeWeight += relativeWeights[i];
        }
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < numberOfAssets; i++) {
            // here the amount[i] has 18 decimals (because bentoUSD has 18 decimals)
            amounts[i] = (desiredAmount * relativeWeights[i]) / totalRelativeWeight;
            totalAmount += amounts[i];
            // we need to scale it to the decimals of the asset
            amounts[i] = scaleDecimals(amounts[i], 18, IERC20Metadata(allAssets[i]).decimals());
        }
        return (amounts, totalAmount);
    }

    /**
     * @notice Calculate the amount of LTs to withdraw for a given amount of BentoUSD
     * @param inputAmount Amount of BentoUSD to redeem
     * @return Array of LT amounts
     */
    function getOutputLTAmounts(uint256 inputAmount) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](allAssets.length);
        address priceOracle = oracleRouter;
        for (uint256 i = 0; i < allAssets.length; i++) {
            address asset = allAssets[i];
            AssetInfo memory assetInfo = assetToAssetInfo[asset];
            // first we calculate the amount corresponding to the asset in USD 
            // the amount has 18 decimals (because bentoUSD has 18 decimals)
            uint256 partialInputAmount = (inputAmount * assetInfo.weight) / totalWeight;
            uint256 adjustedPrice = adjustPrice(IOracle(priceOracle).price(asset), true);
            // we need to scale it to the decimals of the asset
            uint256 normalizedAmount = scaleDecimals(partialInputAmount * 1e18 / adjustedPrice, 18, IERC20Metadata(asset).decimals());
            address ltToken = assetInfo.ltToken;
            amounts[i] = IERC4626(ltToken).convertToShares(normalizedAmount);
        }
        return amounts;
    }

    /**
     * @notice Returns the total value of assets in the vault
     * @return Total value in USD
     */
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
            uint256 assetPrice = adjustPrice(IOracle(oracleRouter).price(asset), false);
            totalValue += (totalBalance * assetPrice) / 1e18;
        }
        return totalValue;
    }

    /**
     * @notice Mints reward based on the total value of the vault
     */
    function mintReward() public {
        uint256 totalValue = getTotalValue();
        uint256 bentoUSDBalance = BentoUSD(bentoUSD).balanceOf(address(this));
        BentoUSD(bentoUSD).mint(msg.sender, totalValue - bentoUSDBalance);
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

    /**
     * @notice Scale the amount with "from" decimals to an amount with "to" decimals
     * @param amount The amount to scale
     * @param from The current decimals of the asset
     * @param to The target decimals
     * @return The scaled amount
     */
    function scaleDecimals(uint256 amount, uint8 from, uint8 to) internal pure returns (uint256) {
        if (from < to) {
            // if the asset has less than 18 decimals, we add 0s to the end
            return amount * 10 ** (to - from);
        } else if (from > to) {
            // if the asset has more than 18 decimals, we remove the extra decimals
            return amount / 10 ** (from - to);
        }
        return amount;
    }
}
