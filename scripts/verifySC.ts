import { ethers, tenderly } from 'hardhat';
/**
 * Verifies a smart contract after deployment.
 */
async function main() {
    // remember to turn on /* tdly.setup({ automaticVerifications: true }); */ in hardhat.config.ts
    const contractAddress = "0xc7bAaB0b9b26Cf4b962f143c5cb23763ead129A9";
    const contractName = "EthenaWalletProxy";
    await ethers.getContractAt(contractName, contractAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
