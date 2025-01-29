import { ethers } from "hardhat";
import { addresses } from "../addresses";
import { VaultCore, BentoUSD, VaultInspector } from "../../typechain-types";
import { getSwapTx, decodeSwapData, changeSlippagePercentage, getInputData } from "../1inch/helpers";
async function main() {
  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log("Signer address:", signer.address);

  // Get the VaultCore contract instance
  const vaultAddress = "0xfc5e87A876f0e1d46f00f201F459c390826f35E2";
  const vaultInspectorAddress = "0x9776204ab81052E370eA0271c836F1E0011Aa40c";
  const vaultInspector = await ethers.getContractAt("VaultInspector", vaultInspectorAddress) as VaultInspector;
  const depositAssetAddress = addresses.mainnet.USDC;
  const depositAsset = await ethers.getContractAt("IERC20Metadata", depositAssetAddress);
  const depositAssetDecimals = await depositAsset.decimals();
  const depositAmount = ethers.parseUnits("1000", depositAssetDecimals);

  console.log("Vault address:", vaultAddress);
  const vaultCore = await ethers.getContractAt("VaultCore", vaultAddress) as VaultCore;
  const bentoUSDAddress = await vaultCore.bentoUSD();
  console.log("BentoUSD address:", bentoUSDAddress);
  const bentoUSD = await ethers.getContractAt("BentoUSD", bentoUSDAddress) as BentoUSD;

  // approve the vault to spend the deposit asset
  const depositAssetAllowance = await depositAsset.allowance(signer.address, vaultAddress);
  if (depositAssetAllowance < depositAmount) {
    await depositAsset.approve(vaultAddress, depositAmount);
  }

  // here we create the swap data
  const totalWeight = await vaultCore.totalWeight();
  const vaultAssets = await vaultCore.getAllAssets();
  const routers = [];
  const routerData = [];
  console.log(vaultAssets);
  for (const asset of vaultAssets) {
    const assetInfo = await vaultCore.assetToAssetInfo(asset);
    const weight = assetInfo.weight;
    const partialAmount = depositAmount * weight / totalWeight;
    // create swap data
    if (asset === depositAssetAddress) {
      routers.push('0x' + partialAmount.toString(16).padStart(40, '0'));
      routerData.push("0x");
    } else {
        // from is the vault, because user deposits the asset into the vault
        const from = await vaultCore.getAddress();
        const to = await vaultCore.getAddress();
        const inToken = depositAssetAddress;
        const outToken = asset;
        const amount = partialAmount;
        const slippage = 40;
        const rawSwapData = await getSwapTx(from, to, inToken, outToken, amount, slippage);
        const swapData = (await rawSwapData.json()).tx.data;
        const decodedSwapData = await decodeSwapData(swapData);
        /* console.log(await decodeSwapData(swapData));
        const decodedSwapData = changeSlippagePercentage(await decodeSwapData(swapData), slippage);
        const functionSig = "function swap(address executor,(address from, address to, address srcReceiver, address dstReceiver, uint256 amount, uint256 minReturn, uint256 flags), bytes calldata data)";
        const modifiedSwapData = getInputData(functionSig, "swap", decodedSwapData.args);
        console.log(modifiedSwapData); */
        
        console.log(`working with asset ${asset}`);
        if (decodedSwapData.name === "swap") {
            const executor = decodedSwapData.args[0];
            const desc = decodedSwapData.args[1];
            const data = decodedSwapData.args[2];
            const srcToken = desc[0];
            const dstToken = desc[1];
            const srcReceiver = desc[2];
            const dstReceiver = desc[3];
            const amount = desc[4];
            const minReturnAmount = desc[5];
            const flags = desc[6];
            console.log(`executor: ${executor}`);
            console.log(`srcToken: ${srcToken}`);
            console.log(`dstToken: ${dstToken}`);
            console.log(`srcReceiver: ${srcReceiver}`);
            console.log(`dstReceiver: ${dstReceiver}`);
            console.log(`amount: ${amount}`);
            console.log(`minReturnAmount: ${minReturnAmount}`);
            console.log(`flags: ${flags}`);
            console.log(`data: ${data}`);
          } else {
            throw Error(`Unknown 1Inch tx signature ${swapTx.sighash}`);
          }
      
        //lets wait 2 secs before the next 1inch API call
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        routers.push(addresses.mainnet.ONE_INCH_AGGREGATION_ROUTER_V6);
        routerData.push(swapData);
    }
  }
  console.log(`starting to mint`);
  console.log(signer.address);
  console.log(depositAssetAddress);
  console.log(depositAmount);
  console.log(0);
  console.log(routers);
  console.log(routerData);
  try {
    const tx = await vaultCore.mintWithOneToken(
        signer.address,
        depositAssetAddress,
        depositAmount,
        0,
        routers,
        routerData,
        {gasLimit: 2_000_000}
    );
    console.log("Transaction sent:", tx.hash);
    await tx.wait();
    console.log("Successfully minted with one token");
  } catch (error) {
    console.error("Error minting with one token:", error);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

/*
0xDDC9b558908E28279147D441BF626D4E3e5A5163
0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
1000000000
0
[
  "0x00000000000000000000000000000000165a0bc0",
  "0x111111125421cA6dc452d289314280a0f8842A65",
  "0x111111125421cA6dc452d289314280a0f8842A65",
  "0x111111125421cA6dc452d289314280a0f8842A65"
]
[
  "0x",
  "0x07ed23790000000000000000000000005141b82f5ffda4c6fe1e372978f1c5427640a190000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000005141b82f5ffda4c6fe1e372978f1c5427640a190000000000000000000000000fc5e87a876f0e1d46f00f201f459c390826f35e2000000000000000000000000000000000000000000000000000000000ee6b28000000000000000000000000000000000000000000000000d84f605bb052a515f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000fb0000000000000000000000000000000000000000000000000000dd00004e00a0744c8c09a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4890cbe4bdd538d6e9b379bff5fe72c3d67a521de5000000000000000000000000000000000000000000000000000000000003d0900c20a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48ae461ca67b15dc8dc81ce7615e0320da1a9ab8d56ae4071138002dc6c0ae461ca67b15dc8dc81ce7615e0320da1a9ab8d5111111125421ca6dc452d289314280a0f8842a6500000000000000000000000000000000000000000000000d627d0ca5ae1c807ca0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000004d753222",
  "0x07ed237900000000000000000000000064f2095cc11e4726078f4a64d4279c7e7fb7e6ec000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000064f2095cc11e4726078f4a64d4279c7e7fb7e6ec000000000000000000000000fc5e87a876f0e1d46f00f201f459c390826f35e200000000000000000000000000000000000000000000000000000000077359400000000000000000000000000000000000000000000000000000000007700ad300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000031cfc5a2cf1abe74b4603978eeae616abbaa4563e2db9ba556ed1fe6e1a83b876d5d71bdd7177de0c2b2e51ea0272d7540791643099437491965db996ede3e9edc40000000000000000000000000000000000000000000000000002be00004e00a0744c8c09a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4890cbe4bdd538d6e9b379bff5fe72c3d67a521de5000000000000000000000000000000000000000000000000000000000001e8485120111111125421ca6dc452d289314280a0f8842a65a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48012456a75868a21a25245a841890e971762e875074d3fa04d2e088a5fd1d8a1a41bb4ac6f09c000000000000000000000000807cf9a772d5a3f9cefbc1192e939d62f0d9bd380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000007701e5300000000000000000000000000000000000000000000000000000000077170f8000000000000000000000000000001af3100679949b200000000000000000000000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000414b3c111322234da316803eb2e255b8b8fec9338ec2273901ddb88af658596cbe2aeba4abe113a0bedd057113f25c425215d26dc3f186f59c31bac0e27c3373301b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014111111125421ca6dc452d289314280a0f8842a65000000000000000000000000000000004d753222",
  "0x07ed23790000000000000000000000005141b82f5ffda4c6fe1e372978f1c5427640a190000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000005141b82f5ffda4c6fe1e372978f1c5427640a190000000000000000000000000fc5e87a876f0e1d46f00f201f459c390826f35e2000000000000000000000000000000000000000000000000000000000ee6b28000000000000000000000000000000000000000000000000d7c106cb48e3942bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000cf0000000000000000000000000000000000000000000000000000b100004e00a0744c8c09a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4890cbe4bdd538d6e9b379bff5fe72c3d67a521de5000000000000000000000000000000000000000000000000000000000003d09002a000000000000000000000000000000000000000000000000d59ae232e904f2da3ee63c1e580e6d7ebb9f1a9519dc06d557e03c522d53520e76aa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48111111125421ca6dc452d289314280a0f8842a6500000000000000000000000000000000004d753222"
]
*/