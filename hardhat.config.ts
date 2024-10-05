import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.27",
        settings: {
          viaIR: true,
        },
      },
    networks: {
        hardhat: {
            forking: {
                url: process.env.MainnetAlchemyAPI || "",
                blockNumber: 14390000
            }
        }
    }
};

export default config;
