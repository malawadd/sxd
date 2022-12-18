
const hre = require("hardhat");

async function main() {
  //constants
  const e30 = '1000000000000000000000000000000'
  const e18 = '1000000000000000000'
  const chainlinkPrice = '2329700'// 8 dec places
  const compoundPrice = '23999' // 6 dec places:
  const usdXdcCumPrice0 = '2784275278277546624451305316303382174855535226'
  const usdXdcCumPrice1 = '2639132666967530700283664103'
  const wxdcAddress = '0xE99500AB4A413164DA49Af83B9824749059b46ce'

  let wxdc, aggregator, anchoredView, usdcXdcPair
  let  aggregatorAddress, anchoredViewAddress, usdcXdcPairAddress

  const usdcDecimals = 6
  const xdcDecimals = 18 
  const uniswapTokensInReverseOrder = true
  
  //deployment//

  // //aggregator//
  // const Aggregator = await hre.ethers.getContractFactory("MockAggregatorV3");
  // aggregator = await Aggregator.deploy();
  // await aggregator.deployed();
  // await aggregator.set(chainlinkPrice)
  // aggregatorAddress = aggregator.address

  // console.log(
  //   `aggregator deployed to ${aggregator.address}`
  // );

  // //MockAnchoredView//
  // const MockAnchoredView = await hre.ethers.getContractFactory("MockAnchoredView");
  // anchoredView = await MockAnchoredView.deploy();
  // await anchoredView.deployed();
  // await anchoredView.set(compoundPrice)
  // anchoredViewAddress = anchoredView.address

  // console.log(
  //   `anchoredView deployed to ${anchoredView.address}`
  // );

  //MockAnchoredView//
  // const MockPair = await hre.ethers.getContractFactory("MockPair");
  // usdcXdcPair = await MockPair.deploy();
  // await usdcXdcPair.deployed();
  // await usdcXdcPair.setCumulativePrices(usdXdcCumPrice0, usdXdcCumPrice1)
  // usdcXdcPairAddress = usdcXdcPair.address

  // console.log(
  //   `usdcXdcPair deployed to ${usdcXdcPair.address}`
  // );

  // //SXD//
  // const SXD = await hre.ethers.getContractFactory("SXD");
  // const sxd = await SXD.deploy('20000');
  //   await sxd.deployed();
  
  // const sxdAddress = sxd.address

  // console.log(
  //   `sxd deployed to ${sxd.address}`
  // );

    //SXD//
    const FXD = await hre.ethers.getContractFactory("FXD");
    const fxd = await FXD.deploy('0xaaa17A76C38A071a4EFC0788a892FB0146BA36eA');
      await fxd.deployed();
    
    const fxdAddress = fxd.address
  
    console.log(
      `fxd deployed to ${fxd.address}`
    );
  
}
//  //SXD//
//   const SXD = await hre.ethers.getContractFactory("SXD");
//   const sxd = await SXD.deploy('20000');
//   await sxd.deployed();
  
//   const sxdAddress = sxd.address

//   console.log(
//     `sxd deployed to ${sxd.address}`
//   );



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
