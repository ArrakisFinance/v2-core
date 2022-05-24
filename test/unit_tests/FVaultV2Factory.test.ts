import { expect } from "chai";
// import { Signer } from "@ethersproject/abstract-signer";
import hre = require("hardhat");
// import { BigNumber } from "@ethersproject/bignumber";
import { MockFVaultV2Factory, IUniswapV3Pool } from "../../typechain";
import { Addresses, getAddresses } from "../../src/addresses";
import { Signer } from "ethers";

const { ethers, deployments } = hre;

describe("Vault V2 Factory smart contract internal functions unit test", function () {
  this.timeout(0);

  let user: Signer;
  let mockFVaultV2Factory: MockFVaultV2Factory;
  let addresses: Addresses;
  let poolContract: IUniswapV3Pool;

  beforeEach("Setting up for Vault V2 functions unit test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();

    addresses = getAddresses(hre.network.name);

    await deployments.fixture();

    mockFVaultV2Factory = (await ethers.getContract(
      "MockFVaultV2Factory"
    )) as MockFVaultV2Factory;

    poolContract = (await ethers.getContractAt(
      "IUniswapV3Pool",
      addresses.TestPool,
      user
    )) as IUniswapV3Pool;
  });

  it("#0: Test Token Order", async () => {
    const tokenA = await poolContract.token1();
    const tokenB = await poolContract.token0();

    const result = await mockFVaultV2Factory.getTokenOrder(tokenA, tokenB);

    expect(result.token0).to.be.eq(tokenB);
    expect(result.token1).to.be.eq(tokenA);
  });

  it("#1: Test Append", async () => {
    const a = "a";
    const b = "b";
    const c = "c";
    const d = "d";

    const appendString = await mockFVaultV2Factory.append(a, b, c, d);

    expect(a + b + c + d).to.be.eq(appendString);
  });
});
