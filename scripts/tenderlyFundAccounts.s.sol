// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Addresses} from "./Addresses.sol";

contract TenderlyFundAccounts is Script {
    function run() external {
        // Define accounts to fund
        address[] memory accounts = new address[](3);
        accounts[0] = 0xDDC9b558908E28279147D441BF626D4E3e5A5163;
        accounts[1] = 0x5118470D402d840a0091c6574F7D8ee5C32e0551;
        accounts[2] = 0x3cA5f5caa07b47c5c6c85afC684A482d2cE9a5e4;

        address[] memory tokens = new address[](4);
        tokens[0] = Addresses.DAI;
        tokens[1] = Addresses.USDC;
        tokens[2] = Addresses.USDT;
        tokens[3] = Addresses.USDe;

        // Prepare accounts array for JSON
        string memory accountsJson = "";
        for (uint i = 0; i < accounts.length; i++) {
            if (i > 0) accountsJson = string.concat(accountsJson, ",");
            accountsJson = string.concat(accountsJson, "\"", vm.toString(accounts[i]), "\"");
        }

        // Fund native ETH first
        string[] memory ethCommand = new string[](3);
        ethCommand[0] = "bash";
        ethCommand[1] = "-c";
        ethCommand[2] = string.concat(
            "curl -s $TenderlyMainnetRPC ",
            "-X POST ",
            "-H 'Content-Type: application/json' ",
            "-d '{",
                "\"jsonrpc\": \"2.0\",",
                "\"method\": \"tenderly_addBalance\",",
                "\"params\": [",
                    "[", accountsJson, "],",
                    "\"0x21E19E0C9BAB2400000\"",  // 10000 ETH
                "],",
                "\"id\": \"12345\"",
            "}'"
        );

        bytes memory ethResult = vm.ffi(ethCommand);
        console.log("\nFunding ETH:");
        console.log("Response:", string(ethResult));

        // Fund ERC20 tokens
        for (uint i = 0; i < tokens.length; i++) {
            string[] memory command = new string[](3);
            command[0] = "bash";
            command[1] = "-c";
            command[2] = string.concat(
                "curl -s $TenderlyMainnetRPC ",
                "-X POST ",
                "-H 'Content-Type: application/json' ",
                "-d '{",
                    "\"jsonrpc\": \"2.0\",",
                    "\"method\": \"tenderly_setErc20Balance\",",
                    "\"params\": [",
                        "\"", vm.toString(tokens[i]), "\",",
                        "[", accountsJson, "],",
                        "\"0x21E19E0C9BAB2400000\"",  // 10000 tokens
                    "],",
                    "\"id\": \"12345\"",
                "}'"
            );

            bytes memory result = vm.ffi(command);
            console.log("\nFunding token:", tokens[i]);
            console.log("Response:", string(result));
        }

        // Log final balances
        console.log("\nFinal balances:");
        for (uint i = 0; i < accounts.length; i++) {
            console.log("\nAccount", i, ":", accounts[i]);
            console.log("ETH balance:", accounts[i].balance);
            
            for (uint j = 0; j < tokens.length; j++) {
                bytes memory balanceCommand = abi.encodeWithSignature(
                    "balanceOf(address)", 
                    accounts[i]
                );
                (bool success, bytes memory data) = tokens[j].staticcall(balanceCommand);
                if (success) {
                    uint256 balance = abi.decode(data, (uint256));
                    console.log("Token", tokens[j], "balance:", balance);
                }
            }
        }
    }
} 