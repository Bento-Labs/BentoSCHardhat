export function getSwapTx(from: string, to: string, inToken: string, out: string, amount: number, slippage: number) {
    const tokens = process.env.ONEINCH_API_KEYS.split(",");
    const headers = {
      headers: {
        Authorization: `Bearer ${tokens[getRandomInt(tokens.length)]}`,
        accept: "application/json",
      },
    };
    const swpParams = {
      src: `0x${inToken}`,
      dst: `0x${out}`,
      amount: amount,
      from: `0x${from}`,
      receiver: `0x${to}`,
      slippage: Number(slippage) / 10000,
      disableEstimate: true,
      allowPartialFill: false,
    };
  
    const url = apiRequestUrl("/swap", swpParams);
    return fetch(url, headers);
  }
  
  function apiRequestUrl(methodName: string, queryParams: Record<string, string>) {
    const chainId = 1;
    const apiBaseUrl = "https://api.1inch.dev/swap/v5.2/" + chainId;
  
    return (
      apiBaseUrl + methodName + "?" + new URLSearchParams(queryParams).toString()
    );
  }
  
  function getRandomInt(max: number) {
    return Math.floor(Math.random() * max);
  }
  
   function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }