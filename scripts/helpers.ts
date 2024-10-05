export function getSwapTx(from: string, to: string, inToken: string, outToken: string, amount: number, slippage: number) {

    const tokens = process.env.ONEINCH_API_KEYS.split(",");
    const headers = get1inchHeaders(tokens);
    const swpParams = {
      src: inToken,
      dst: outToken,
      amount: amount,
      from: from,
      receiver: to,
      slippage: Number(slippage) / 10000,
      disableEstimate: true,
      allowPartialFill: false,
    };

    console.log(`swpParams ${swpParams}`);
    
    const url = apiRequestUrl("/swap", swpParams);
    return fetch(url, headers);
  }
    export function getQuote(inToken: string, outToken: string, amount: number) {
        const tokens = process.env.ONEINCH_API_KEYS?.split(",") || [];
        const headers = get1inchHeaders(tokens);
        const quoteParams = {
            src: inToken,
            dst: outToken,
            amount: amount
        };

        console.log(`quoteParams ${quoteParams}`);
        
        const url = apiRequestUrl("/quote", quoteParams);
        return fetch(url, headers);
    }


    function get1inchHeaders(tokens: string[]) {
        return {
            headers: {
                Authorization: `Bearer ${tokens[getRandomInt(tokens.length)]}`,
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
  
  function getRandomInt(max: number) {
    return Math.floor(Math.random() * max);
  }
  