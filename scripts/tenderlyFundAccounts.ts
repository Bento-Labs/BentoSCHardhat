import { ethers } from "hardhat";
import { addresses } from "./addresses";

async function main() {
    // Define accounts to fund
    const accounts = [
        "0xDDC9b558908E28279147D441BF626D4E3e5A5163",
        "0x5118470D402d840a0091c6574F7D8ee5C32e0551",
        "0x3cA5f5caa07b47c5c6c85afC684A482d2cE9a5e4"
    ];

    const tokens = [
        addresses.mainnet.DAI,
        addresses.mainnet.USDC,
        addresses.mainnet.USDT,
        addresses.mainnet.USDe
    ];

    const currentRpc = hre.network.config.url;
    console.log(`current rpc is`);
    console.log(currentRpc);

    // Prepare accounts array for JSON
    const accountsJson = accounts.map(account => `"${account}"`).join(",");

    // Fund native ETH first
    console.log("\nFunding ETH:");
    const ethCommand = `curl -s ${currentRpc} \
        -X POST \
        -H 'Content-Type: application/json' \
        -d '{
            "jsonrpc": "2.0",
            "method": "tenderly_addBalance",
            "params": [
                [${accountsJson}],
                "0x21E19E0C9BAB2400000"
            ],
            "id": "12345"
        }'`;

    try {
        const ethResult = await execCommand(ethCommand);
        console.log("Response:", ethResult);
    } catch (error) {
        console.error("Error funding ETH:", error);
    }

    // Fund ERC20 tokens
    for (const token of tokens) {
        console.log("\nFunding token:", token);
        const tokenCommand = `curl -s ${currentRpc} \
            -X POST \
            -H 'Content-Type: application/json' \
            -d '{
                "jsonrpc": "2.0",
                "method": "tenderly_setErc20Balance",
                "params": [
                    "${token}",
                    [${accountsJson}],
                    "0x21E19E0C9BAB2400000"
                ],
                "id": "12345"
            }'`;

        try {
            const result = await execCommand(tokenCommand);
            console.log("Response:", result);
        } catch (error) {
            console.error("Error funding token:", token, error);
        }
    }

    // Log final balances
    console.log("\nFinal balances:");
    for (let i = 0; i < accounts.length; i++) {
        console.log("\nAccount", i, ":", accounts[i]);
        
        // Get ETH balance
        const ethBalance = await ethers.provider.getBalance(accounts[i]);
        console.log("ETH balance:", ethBalance.toString());
        
        // Get token balances
        for (const token of tokens) {
            const tokenContract = await ethers.getContractAt("IERC20", token);
            try {
                const balance = await tokenContract.balanceOf(accounts[i]);
                console.log("Token", token, "balance:", balance.toString());
            } catch (error) {
                console.error("Error getting balance for token:", token, error);
            }
        }
    }
}

async function execCommand(command: string): Promise<string> {
    const { exec } = require('child_process');
    return new Promise((resolve, reject) => {
        exec(command, (error: Error | null, stdout: string, stderr: string) => {
            if (error) {
                reject(error);
                return;
            }
            if (stderr) {
                reject(stderr);
                return;
            }
            resolve(stdout);
        });
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 