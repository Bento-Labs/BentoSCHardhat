// script to investigate convertToShares function of MetaMorpho
import { ethers } from "hardhat";
import { ERC4626 } from "../typechain-types";

async function main() {
    const network = await hre.network.name;
    console.log(`network: ${network}`);
    const chainId = await hre.network.config.chainId;
    console.log(`chainId: ${chainId}`);
const sUSDCAddress = "0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB";
  const sUSDC = await ethers.getContractAt("ERC4626", sUSDCAddress);
  const assetAmount = 375076817; // please don't add n to the end, but it seems like it doesn't matter
  console.log(await sUSDC.name());
  const sharesAmount = await sUSDC.convertToShares(assetAmount);
  console.log(`the shares amount is ${sharesAmount}`);
}

main();