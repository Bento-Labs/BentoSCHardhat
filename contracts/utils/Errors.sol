pragma solidity 0.8.27;

contract Errors {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error Inconsistency();
    error Inconsistency2(uint256, uint256, uint256, uint256);
    error DefaultValueRequired();
    error NotSupported();
    error StalePrice();
    error SlippageTooHigh();
    error InsufficientBalance();
    error RouterNotWhitelisted();
}
