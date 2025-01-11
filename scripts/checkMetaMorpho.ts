// script to investigate convertToShares function of MetaMorpho
import { ethers } from "hardhat";
import { ERC4626 } from "../typechain-types";

async function main() {
    const network = await hre.network.name;
    console.log(`network: ${network}`);
    const chainId = (await ethers.provider.getNetwork()).chainId;
    console.log(chainId);
    const sUSDCAddress = "0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB";
    const sUSDTAddress = "0xbEef047a543E45807105E51A8BBEFCc5950fcfBa";
    const sUSDC = await ethers.getContractAt("ERC4626", sUSDCAddress);
    const sUSDT = await ethers.getContractAt("ERC4626", sUSDTAddress);
    const assetAmount = 375076817; // please don't add n to the end, but it seems like it doesn't matter
    console.log(await sUSDC.name());
    const USDCSharesAmount = await sUSDC.convertToShares(assetAmount);
    console.log(`the shares amount is ${USDCSharesAmount}`);
    const USDTSharesAmount = await sUSDT.convertToShares(assetAmount);
    console.log(`the shares amount is ${USDTSharesAmount}`);
}

main();