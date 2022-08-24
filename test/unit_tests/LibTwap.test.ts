// import { expect } from "chai";
// import { Signer } from "ethers";
// import hre = require("hardhat");
// import { Addresses, getAddresses } from "../../src/addresses";
// import { TwapMock, IUniswapV3Pool, ERC20Upgradeable } from "../../typechain";

// const { ethers, deployments } = hre;

// describe("Twap unit test", function () {
//   this.timeout(0);

//   let user: Signer;
//   let addresses: Addresses;
//   let twap: TwapMock;
//   let pool: IUniswapV3Pool;
//   let token0: ERC20Upgradeable;
//   let token1: ERC20Upgradeable;

//   beforeEach("Setting up for Twap library test", async function () {
//     if (hre.network.name !== "hardhat") {
//       console.error("Test Suite is meant to be run on hardhat only");
//       process.exit(1);
//     }

//     [user] = await ethers.getSigners();

//     await deployments.fixture();

//     addresses = getAddresses(hre.network.name);

//     twap = (await ethers.getContract("TwapMock")) as TwapMock;
//     pool = (await ethers.getContractAt(
//       "IUniswapV3Pool",
//       addresses.TestPool,
//       user
//     )) as IUniswapV3Pool;

//     // token0 = (await ethers.getContractAt(
//     //   "ERC20Upgradeable",
//     //   await pool.token0(),
//     //   user
//     // )) as ERC20Upgradeable;

//     // token1 = (await ethers.getContractAt(
//     //   "ERC20Upgradeable",
//     //   await pool.token1(),
//     //   user
//     // )) as ERC20Upgradeable;
//   });

//   it("#0 Twap: unit test getPriceX96FromSqrtPriceX96 ", async () => {
//     // const result = await twap.getSqrtTwapX96(addresses.TestPool, 2000);
//     // const price0 = await twap.getPrice0(addresses.TestPool, 2000);
//     // // console.log("Price in 18 decimals :", price0.toString());
//     // const price1 = await twap.getPrice1(addresses.TestPool, 2000);
//     // console.log("Price in 18 decimals :", price1.toString());
//     // #region price in 18 decimals.
//     // console.log(await token0.decimals());
//     // console.log(await token1.decimals());
//     // #endregion price in 18 decimals.
//   });
// });
