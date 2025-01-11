import { tenderly } from 'hardhat';
/**
 * Verifies a smart contract after deployment.
 */
async function main() {
    // remember to turn on /* tdly.setup({ automaticVerifications: true }); */ in hardhat.config.ts
    const contractAddress = "0x03C5f20dACf35dD6B3874d7152Cc5112367acc2F";
    const contractName = "VaultCore";
    await ethers.getContractAt(contractName, contractAddress);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
