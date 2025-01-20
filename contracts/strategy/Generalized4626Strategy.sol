// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title Generalized 4626 Strategy
 * @notice Investment strategy for ERC-4626 Tokenized Vaults
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "hardhat/console.sol";


contract Generalized4626Strategy {
    using SafeERC20 for IERC20;

    //address of the ERC-4626 Vault contract
    address public immutable shareToken;
    //address of the underlying asset
    address public immutable assetToken;
    //address of the admin (assumed to be the bento vault contract)
    address public immutable admin;

    /**
     * @param _assetToken Address of the ERC-4626 asset token. eg frxETH or DAI
     * @param _shareToken Address of the ERC-4626 share token. eg sfrxETH or sDAI
     * @param _admin Address of the admin (assumed to be the bento vault contract)
     */
    constructor(address _assetToken, address _shareToken, address _admin)
    {
        shareToken = _shareToken;
        assetToken = _assetToken;
        admin = _admin;
        IERC20(assetToken).safeIncreaseAllowance(shareToken, type(uint256).max);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    /**
     * @dev Deposit assets by converting them to shares
     * @param _amount Amount of asset to deposit
     */
    function deposit(uint256 _amount)
        external
        onlyAdmin
    {
        uint receivedShares = IERC4626(shareToken).deposit(_amount, admin);
        console.log("Received shares: %s", receivedShares);
        console.log("send to admin: %s", admin);
    }

    /**
     * @dev Withdraw asset by burning shares
     * @param _recipient Address to receive withdrawn asset
     * @param _amount Amount of asset to withdraw
     */
    function withdraw(
        address _recipient,
        uint256 _amount
    ) external virtual onlyAdmin {
        require(_amount > 0, "Must withdraw something");
        require(_recipient != address(0), "Must specify recipient");

        // slither-disable-next-line unused-return
        IERC4626(shareToken).withdraw(_amount, _recipient, address(this));
    }

    /**
     * @dev Redeem shares by converting them to assets
     * @param _amount Amount of shares to redeem
     * @param _recipient Address to receive redeemed assets
     */
    function redeem(address _recipient, uint256 _amount) external virtual onlyAdmin {
        // slither-disable-next-line unused-return
        IERC4626(shareToken).redeem(_amount, _recipient, address(this));
    }

    /**
     * @dev Remove all assets from platform and send them to Vault contract.
     */
    function withdrawAll()
        external
        virtual
        onlyAdmin
    {
        uint256 shareBalance = IERC20(shareToken).balanceOf(address(this));
        uint256 assetAmount = IERC4626(shareToken).redeem(
            shareBalance,
            admin,
            address(this)
        );
    }

    function approveVault(address _vault) external onlyAdmin {
        IERC20(assetToken).safeIncreaseAllowance(_vault, type(uint256).max);
    }
}
