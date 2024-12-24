import { tenderly } from 'hardhat';
/**
 * Verifies a smart contract after deployment.
 */
async function main() {
    await tenderly.verify({
        address: "0x6BfB50ce7f9D383b713A399f453AF8290cf14a74",
        name: "OracleRouter",
    });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
