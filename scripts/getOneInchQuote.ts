/* Copyright (C) 2023 Galactica Network. This file is part of zkKYC. zkKYC is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. zkKYC is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. */
import hre from 'hardhat';
import { getSwapTx, getQuote } from './helpers';


/**
 * Script to deploy the example DApp, a smart contract requiring zkKYC to issue a verification SBT.
 */
async function main() {

    const [deployer] = await hre.ethers.getSigners();

    const from = deployer.address;
    const to = deployer.address;
    const inToken = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const outToken = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const amount = hre.ethers.parseUnits("1", 18);
    const slippage = 100;

    console.log(`from ${from}, to ${to}, inToken ${inToken}, outToken ${outToken}, amount ${amount}, slippage ${slippage}`);

    getQuote(inToken, outToken, amount).then(async (res) => {
        const raw = await res.json();
        console.log("quote");
        console.log(raw);
    });

    /* getSwapTx(from, to, inToken, outToken, amount, slippage).then(async (res) => {
        const raw = await res.json();
        console.log(raw);
      }); */
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
