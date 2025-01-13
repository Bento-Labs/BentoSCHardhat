// script to investigate convertToShares function of MetaMorpho
import { ethers } from "hardhat";
import { IMetaMorpho } from "../typechain-types";

async function main() {
    const network = await hre.network.name;
    console.log(`network: ${network}`);
    const chainId = (await ethers.provider.getNetwork()).chainId;
    console.log(chainId);
    const sUSDCAddress = "0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB";
    const sUSDTAddress = "0xbEef047a543E45807105E51A8BBEFCc5950fcfBa";
    const sUSDC = await ethers.getContractAt("IMetaMorpho", sUSDCAddress);
    const sUSDT = await ethers.getContractAt("IMetaMorpho", sUSDTAddress);
    const assetAmount = 375076817; // please don't add n to the end, but it seems like it doesn't matter
    console.log(`checking ${await sUSDC.name()}`);
    /* const USDCSharesAmount = await sUSDC.convertToShares(assetAmount);
    console.log(`the shares amount is ${USDCSharesAmount}`);
    const USDTSharesAmount = await sUSDT.convertToShares(assetAmount);
    console.log(`the shares amount is ${USDTSharesAmount}`); */
    const MorphoAddress = await sUSDC.MORPHO();
    const Morpho = await ethers.getContractAt("IMorpho", MorphoAddress);
    console.log(`Morpho address is ${MorphoAddress}`);
    const withdrawQueueLength = await sUSDC.withdrawQueueLength();
    console.log(`withdraw queue length is ${withdrawQueueLength}`);
    for (let i = 0; i < withdrawQueueLength; i++) {
        const withdrawId = await sUSDC.withdrawQueue(i);
        const marketParams = await Morpho.idToMarketParams(withdrawId);
        const market = await Morpho.market(withdrawId);
        const loanToken = marketParams[0];
        const collateralToken = marketParams[1];
        const oracle = marketParams[2];
        const irm = marketParams[3];
        const lltv = marketParams[4];
        console.log(`-----------------------------------`);
        console.log(`investigating withdrawQueue element ${i}`);
        console.log(`withdraw Id is ${withdrawId}`);
        console.log(`loan token is ${loanToken}`);
        const loanTokenContract = await ethers.getContractAt("IERC20Metadata", loanToken);
        console.log(`loan token name is ${await loanTokenContract.name()}`);
        console.log(`collateral token is ${collateralToken}`);
        if (collateralToken !== ethers.ZeroAddress) {
            const collateralTokenContract = await ethers.getContractAt("IERC20Metadata", collateralToken);
            console.log(`collateral token name is ${await collateralTokenContract.name()}`);
        }
        console.log(`oracle is ${oracle}`);
        console.log(`irm is ${irm}`);
        console.log(`lltv is ${lltv}`);
        console.log(`market state is `);
        console.log(`totalSupplyAssets is ${market.totalSupplyAssets}`);
        console.log(`totalSupplyShares is ${market.totalSupplyShares}`);
        console.log(`totalBorrowAssets is ${market.totalBorrowAssets}`);
        console.log(`totalBorrowShares is ${market.totalBorrowShares}`);
        console.log(`lastUpdate is ${market.lastUpdate}`);
        console.log(`fee is ${market.fee}`);

        /* uint256 availableLiquidity = UtilsLib.min(
            totalSupplyAssets - totalBorrowAssets, ERC20(marketParams.loanToken).balanceOf(address(MORPHO))
        );

        return UtilsLib.min(supplyAssets, availableLiquidity);*/
        const liquidity = await loanTokenContract.balanceOf(MorphoAddress);
        const supplyDiff = market.totalSupplyAssets - market.totalBorrowAssets;
        const withdrawable = supplyDiff < liquidity ? supplyDiff : liquidity;
        console.log(`withdrawable is ${withdrawable}`);

        const morphoSupplyShares = await Morpho.position(withdrawId, sUSDCAddress);
        console.log(`morphoSupplyShares is ${morphoSupplyShares}`);
        if (irm !== ethers.ZeroAddress) {
            const irmContract = await ethers.getContractAt("IIrm", irm);
            const _marketParams = {
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: oracle,
                irm: irm,
                lltv: lltv,
            };
            const _market = {
                totalSupplyAssets: market.totalSupplyAssets,
                totalSupplyShares: market.totalSupplyShares,
                totalBorrowAssets: market.totalBorrowAssets,
                totalBorrowShares: market.totalBorrowShares,
                lastUpdate: market.lastUpdate,
                fee: market.fee,
            };
            console.log(_marketParams);
            console.log(_market);
            const borrowRate = await irmContract.borrowRateView(_marketParams, _market);

            console.log(`borrow rate is ${borrowRate}`);
        }
        console.log(`-----------------------------------`);
    }

    const supplyQueueLength = await sUSDC.supplyQueueLength();
    console.log(`supply queue length is ${supplyQueueLength}`);
    for (let i = 0; i < supplyQueueLength; i++) {
        const supplyId = await sUSDC.supplyQueue(i);
        const marketParams = await Morpho.idToMarketParams(supplyId);
        const loanToken = marketParams[0];
        const collateralToken = marketParams[1];
        const oracle = marketParams[2];
        const irm = marketParams[3];
        const lltv = marketParams[4];
        console.log(`-----------------------------------`);
        console.log(`investigating supplyQueue element ${i}`);
        console.log(`supply Id is ${supplyId}`);
        console.log(`loan token is ${loanToken}`);
        const loanTokenContract = await ethers.getContractAt("IERC20Metadata", loanToken);
        console.log(`loan token name is ${await loanTokenContract.name()}`);
        console.log(`collateral token is ${collateralToken}`);
        if (collateralToken !== ethers.ZeroAddress) {

            const collateralTokenContract = await ethers.getContractAt("IERC20Metadata", collateralToken);
            console.log(`collateral token name is ${await collateralTokenContract.name()}`);
        }
        console.log(`oracle is ${oracle}`);
        console.log(`irm is ${irm}`);
        console.log(`lltv is ${lltv}`);
        console.log(`-----------------------------------`);
    }
}

main();