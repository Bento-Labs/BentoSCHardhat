import hre from 'hardhat';
import { getSwapTx, getQuote } from './helpers';


async function main() {

    const [deployer, user, user2] = await hre.ethers.getSigners();

    console.log(deployer.address);
    console.log(user.address);
    console.log(user2.address);
    const from = user.address;
    const to = user2.address;
    const inToken = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const outToken = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const amount = hre.ethers.parseUnits("1", 6);
    const slippage = 40;

    console.log(`from ${from}, to ${to}, inToken ${inToken}, outToken ${outToken}, amount ${amount}, slippage ${slippage}`);

        /* getQuote(inToken, outToken, amount).then(async (res) => {
            const raw = await res.json();
            console.log("quote");
            console.log(raw);
        }); */

    /* const quote = await getQuote(inToken, outToken, amount);
    console.log(quote); */

    /* getSwapTx(from, to, inToken, outToken, amount, slippage).then(async (res) => {
        const raw = await res.json();
        console.log("swapTx");
        console.log(raw);
      }); */

    const swapTx = await (await getSwapTx(from, to, inToken, outToken, amount, slippage)).json();
    console.log(swapTx.tx.data);
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
