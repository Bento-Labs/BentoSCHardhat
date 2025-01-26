pragma solidity 0.8.27;

contract Errors {
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();
    error Inconsistency();
    error DefaultValueRequired();
    error NotSupported();
    error StalePrice();
    error SlippageTooHigh();
    error InsufficientBalance();
}