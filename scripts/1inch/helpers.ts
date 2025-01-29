import { ethers } from "hardhat";
import { addresses } from "../addresses";

export async function decodeSwapData(apiEncodedData: string) {
    try {
        const c1InchRouter = await ethers.getContractAt(
            "IOneInchRouter",
            addresses.mainnet.ONE_INCH_AGGREGATION_ROUTER_V6
        );
        const swapTx = c1InchRouter.interface.parseTransaction({
            data: apiEncodedData,
        });
        return swapTx;
    } catch (err) {
        throw Error(`Failed to recode 1Inch swap data: ${err.message}`, {
          cause: err,
        });
      }
}

export function getSwapTx(from: string, to: string, inToken: string, outToken: string, amount: number, slippage: number) {

    const token = process.env.BENTO_ONE_INCH_API_KEY || "";
    const headers = get1inchHeaders(token);
    const swpParams = {
      src: inToken,
      dst: outToken,
      amount: amount.toString(),
      from: from,
      receiver: to,
      slippage: slippage.toString(),
      disableEstimate: true,
      allowPartialFill: false,
    };
    
    const url = apiRequestUrl("/swap", swpParams);
    return fetch(url, headers);
  }
    export function getQuote(inToken: string, outToken: string, amount: number) {
        const token = process.env.BENTO_ONE_INCH_API_KEY || "";
        const headers = get1inchHeaders(token);
        const quoteParams = {
            src: inToken,
            dst: outToken,
            amount: amount.toString()
        };
        
        const url = apiRequestUrl("/quote", quoteParams);
        return fetch(url, headers);
    }


    function get1inchHeaders(token: string) {
        return {
            headers: {
                Authorization: `Bearer ${token}`,
                accept: "application/json",
            },
        };
    }
  function apiRequestUrl(methodName: string, queryParams: Record<string, string>) {
    const chainId = 1;
    const apiBaseUrl = "https://api.1inch.dev/swap/v6.0/" + chainId;
  
    return (
      apiBaseUrl + methodName + "?" + new URLSearchParams(queryParams).toString()
    );
  }

  export function changeSlippagePercentage(decodedSwapData: any, slippagePercentage: number) {
    const amount = (decodedSwapData.args[1])[4];
    
    // Create a new mutable array by copying the original
    const newArgs = [...decodedSwapData.args[1]];
    // Modify the copy instead of the original
    newArgs[5] = amount * BigInt(100 - slippagePercentage) / BigInt(100);
    
    // Create a new object with the modified array
    const newDecodedSwapData = {
        ...decodedSwapData,
        args: [decodedSwapData.args[0], newArgs, decodedSwapData.args[2]]
    };
    
    return newDecodedSwapData;
  }

  export function getInputData (functionSig: string, functionName: string, args: any) {
    let ABI = [functionSig];
    let iface = new ethers.Interface(ABI);
    return iface.encodeFunctionData(functionName, args);
}
  
  function getRandomInt(max: number) {
    return Math.floor(Math.random() * max);
  }