// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// We put the definitions outside so they can be imported to different contracts (in this case VaultCore and VaultInspector)
    enum StrategyType {
        Generalized4626,
        Ethena,
        Other
    }
    // Changed to fit into a single storage slot so the decimals needs to be recached
    struct AssetInfo {
        address ltToken;
        uint32 weight;
        uint8 decimals;
        uint8 index;
        StrategyType strategyType;
        address strategy;
        uint256 minimalAmountInVault;
    }