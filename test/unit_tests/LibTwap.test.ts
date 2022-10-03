import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import JSBI from "jsbi";
import { Addresses, getAddresses } from "../../src/addresses";
import { TwapMock, IUniswapV3Pool, ERC20Upgradeable } from "../../typechain";

const { ethers, deployments } = hre;

describe("Twap unit test", function () {
  this.timeout(0);

  let user: Signer;
  let addresses: Addresses;
  let twap: TwapMock;
  let pool: IUniswapV3Pool;
  let token0: ERC20Upgradeable;
  let token1: ERC20Upgradeable;

  beforeEach("Setting up for Twap library test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();

    await deployments.fixture();

    addresses = getAddresses(hre.network.name);

    twap = (await ethers.getContract("TwapMock")) as TwapMock;
    pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      addresses.TestPool,
      user
    )) as IUniswapV3Pool;

    token0 = (await ethers.getContractAt(
      "ERC20Upgradeable",
      await pool.token0(),
      user
    )) as ERC20Upgradeable;

    token1 = (await ethers.getContractAt(
      "ERC20Upgradeable",
      await pool.token1(),
      user
    )) as ERC20Upgradeable;
  });

  it("#0 Twap: checkDeviation should fail for a small max deviation ", async () => {
    await expect(
      twap.checkDeviation(addresses.TestPool, 2000, 10)
    ).to.be.revertedWith("maxTwapDeviation");
  });
  it("#1 Twap: checkDeviation", async () => {
    await expect(twap.checkDeviation(addresses.TestPool, 2000, 100)).to.not.be
      .reverted;
  });
  it("#2 Twap: getPrice0", async () => {
    const priceX96 = JSBI.BigInt(
      (await twap.getSqrtTwapX96(addresses.TestPool, 2000)).toString()
    );
    const token0Dec = await token0.decimals();
    const price0 = JSBI.divide(
      JSBI.multiply(
        JSBI.multiply(priceX96, priceX96),
        JSBI.exponentiate(JSBI.BigInt(10), JSBI.BigInt(token0Dec))
      ),
      JSBI.exponentiate(JSBI.BigInt(2), JSBI.BigInt(192))
    );

    const price0Current = await twap.getPrice0(addresses.TestPool, 2000);

    expect(price0.toString()).to.be.eq(price0Current);
  });

  it("#3 Twap: getPrice1", async () => {
    const priceX96 = JSBI.BigInt(
      (await twap.getSqrtTwapX96(addresses.TestPool, 2000)).toString()
    );
    const token1Dec = await token1.decimals();
    const price1 = JSBI.divide(
      JSBI.multiply(
        JSBI.exponentiate(JSBI.BigInt(2), JSBI.BigInt(192)),
        JSBI.exponentiate(JSBI.BigInt(10), JSBI.BigInt(token1Dec))
      ),
      JSBI.multiply(priceX96, priceX96)
    );

    const price1Current = await twap.getPrice1(addresses.TestPool, 2000);

    expect(price1.toString()).to.be.eq(price1Current);
  });
});
