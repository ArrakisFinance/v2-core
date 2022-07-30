import { expect } from "chai";
import hre = require("hardhat");
import { Addresses, getAddresses } from "../../src/addresses";
import { Signer } from "ethers";
import {
  IUniswapV3Factory,
  IUniswapV3Pool,
  StratRegistry,
  VaultV2,
  VaultV2Factory,
  VaultV2Resolver,
} from "../../typechain";

const { ethers, deployments } = hre;

describe("Strategy registry unit test", function () {
  this.timeout(0);

  let user: Signer;
  let userAddr: string;
  let addresses: Addresses;
  let stratRegistry: StratRegistry;
  let vaultV2Factory: VaultV2Factory;
  let vaultV2Resolver: VaultV2Resolver;
  let uniswapV3Factory: IUniswapV3Factory;
  let uniswapV3Pool: IUniswapV3Pool;
  let lowerTick: number;
  let upperTick: number;
  //   let wEth: Contract;
  //   let usdc: Contract;
  let vaultV2: VaultV2;

  beforeEach("Setup for Vault V2 functions unit test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();
    userAddr = await user.getAddress();
    addresses = getAddresses(hre.network.name);

    await deployments.fixture();

    stratRegistry = (await ethers.getContract(
      "StratRegistry"
    )) as StratRegistry;

    vaultV2Factory = (await ethers.getContract(
      "VaultV2Factory"
    )) as VaultV2Factory;

    vaultV2Resolver = (await ethers.getContract(
      "VaultV2Resolver"
    )) as VaultV2Resolver;

    uniswapV3Factory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      addresses.UniswapV3Factory,
      user
    )) as IUniswapV3Factory;

    uniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      await uniswapV3Factory.getPool(addresses.USDC, addresses.WETH, 500),
      user
    )) as IUniswapV3Pool;

    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // wEth = new ethers.Contract(
    //   addresses.WETH,
    //   [
    //     "function decimals() external view returns (uint8)",
    //     "function balanceOf(address account) public view returns (uint256)",
    //     "function approve(address spender, uint256 amount) external returns (bool)",
    //   ],
    //   user
    // );

    // usdc = new ethers.Contract(
    //   addresses.USDC,
    //   [
    //     "function decimals() external view returns (uint8)",
    //     "function balanceOf(address account) public view returns (uint256)",
    //     "function approve(address spender, uint256 amount) external returns (bool)",
    //   ],
    //   user
    // );

    const res = await vaultV2Resolver.getAmountsForLiquidity(
      slot0.tick,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 18)
    );

    await vaultV2Factory.initialize(
      (
        await ethers.getContract("VaultV2")
      ).address,
      userAddr
    );

    const tx = await vaultV2Factory.deployVault({
      feeTiers: [500],
      token0: addresses.USDC,
      token1: addresses.WETH,
      owner: userAddr,
      operators: [userAddr],
      init0: res.amount0,
      init1: res.amount1,
      manager: userAddr,
      maxTwapDeviation: 100,
      twapDuration: 2000,
      maxSlippage: 100,
    });

    const rc = await tx.wait();
    const event = rc?.events?.find((event) => event.event === "VaultCreated");
    // eslint-disable-next-line no-unsafe-optional-chaining
    const result = event?.args;

    vaultV2 = (await ethers.getContractAt(
      "VaultV2",
      result?.vault,
      user
    )) as VaultV2;
  });

  it("#0: Add new strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;
  });

  it("#1: Add the same strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await expect(stratRegistry.addStratType(stratType)).to.be.reverted;
  });

  it("#2: Remove strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await stratRegistry.removeStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.false;
  });

  it("#3: Remove unknown strategy", async () => {
    const stratType = "Gaussian";

    await expect(stratRegistry.removeStratType(stratType)).to.be.revertedWith(
      "no strat"
    );
  });

  it("#4: Subscribe to strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await stratRegistry.subscribe(vaultV2.address, stratType);

    expect(await stratRegistry.vaultByStrat(vaultV2.address)).to.be.equal(
      stratType
    );
  });

  it("#5: Subscribe again to strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await stratRegistry.subscribe(vaultV2.address, stratType);

    expect(await stratRegistry.vaultByStrat(vaultV2.address)).to.be.equal(
      stratType
    );

    await expect(stratRegistry.subscribe(vaultV2.address, stratType)).to.be
      .reverted;
  });

  it("#6: Unsubscribe after subcription to strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await stratRegistry.subscribe(vaultV2.address, stratType);

    expect(await stratRegistry.vaultByStrat(vaultV2.address)).to.be.equal(
      stratType
    );

    await stratRegistry.unsubscribe(vaultV2.address);

    expect(await stratRegistry.vaultByStrat(vaultV2.address)).to.be.equal("");
  });

  it("#7: Unsubscribe none subscribe to strategy", async () => {
    const stratType = "Gaussian";

    await stratRegistry.addStratType(stratType);

    expect(await stratRegistry.stratExist(stratType)).to.be.true;

    await expect(stratRegistry.unsubscribe(vaultV2.address)).to.be.reverted;
  });
});
