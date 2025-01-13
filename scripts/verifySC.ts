import { ethers, tenderly } from 'hardhat';
/**
 * Verifies a smart contract after deployment.
 */
async function main() {
    // remember to turn on /* tdly.setup({ automaticVerifications: true }); */ in hardhat.config.ts
    const contractAddress = "0xb120d26E6e36cE295Ec520c9d776EBBAeaf4436a";
    const contractName = "VaultCore";
    await ethers.getContractAt(contractName, contractAddress);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
