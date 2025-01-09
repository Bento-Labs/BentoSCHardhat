import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import * as tdly from "@tenderly/hardhat-tenderly";

/* tdly.setup({ automaticVerifications: true }); */


const config: HardhatUserConfig = {
    mocha: {
        timeout: 100000000,
      },
    solidity: {
        version: "0.8.27",
        settings: {
          viaIR: true,
        },
      },
    networks: {
        hardhat: {
            forking: {
                url: process.env.TenderlyMainnetRPC || "",
                blockNumber: 21552974,
            },
            chains: {
                12345: {
                  hardforkHistory: {
                    cancun: 21552900
                  }
                }
            },
        },
        tenderlyMainnetFork: {
            url: process.env.TenderlyMainnetRPC,
            accounts: [process.env.BentoMainnetDeployerPrivateKey || ""],
        }
    },
    etherscan: {
        apiKey: {
          tenderlyMainnetFork: "<tenderly-api-key>"
        },
        customChains: [
          {
            network: "tenderlyMainnetFork",
            chainId: 12345,
            urls: {
              apiURL: "https://virtual.mainnet.rpc.tenderly.co/cb81e170-b28d-43c5-b398-b5c62eb95fb6",
              browserURL: "https://virtual.mainnet.rpc.tenderly.co/386db66e-cd20-4aa5-a6f6-a958dcaa9a59"
            }
          }
        ]
      },
      tenderly: {
        username: "Bento",
        project: "Bento-Mainnet-Fork",
      },
};

export default config;
