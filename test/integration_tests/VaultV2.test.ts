import { expect } from "chai";
import hre = require("hardhat");
import {
  VaultV2,
  VaultV2Factory,
  IUniswapV3Factory,
  IUniswapV3Pool,
  ISwapRouter,
  VaultV2Resolver,
} from "../../typechain";
import { Addresses, getAddresses } from "../../src/addresses";
import { Signer } from "ethers";
import { Contract } from "ethers";
import { ManagerProxyMock } from "../../typechain/contracts/__mocks__/ManagerProxyMock";

const { ethers, deployments } = hre;

describe("Vault V2 integration test!!!", async function () {
  this.timeout(0);

  let user: Signer;
  let userAddr: string;
  let vaultV2Factory: VaultV2Factory;
  let vaultV2: VaultV2;
  let uniswapV3Factory: IUniswapV3Factory;
  let uniswapV3Pool: IUniswapV3Pool;
  let vaultV2Resolver: VaultV2Resolver;
  let swapRouter: ISwapRouter;
  let wMatic: Contract;
  let wEth: Contract;
  let usdc: Contract;
  let addresses: Addresses;
  let lowerTick: number;
  let upperTick: number;

  let managerProxyMock: ManagerProxyMock;

  beforeEach("Setting up for V2 functions integration test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();

    userAddr = await user.getAddress();

    addresses = getAddresses(hre.network.name);
    await deployments.fixture();

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

    managerProxyMock = (await ethers.getContract(
      "ManagerProxyMock"
    )) as ManagerProxyMock;

    uniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      await uniswapV3Factory.getPool(addresses.USDC, addresses.WETH, 500),
      user
    )) as IUniswapV3Pool;

    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    wEth = new ethers.Contract(
      addresses.WETH,
      [
        "function decimals() external view returns (uint8)",
        "function balanceOf(address account) public view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
      ],
      user
    );

    usdc = new ethers.Contract(
      addresses.USDC,
      [
        "function decimals() external view returns (uint8)",
        "function balanceOf(address account) public view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
      ],
      user
    );

    // #region Price computation.

    // const usdcDecimals = await usdc.decimals();
    // const wEthDecimals = await wEth.decimals();

    // const price = slot0.sqrtPriceX96
    //   .pow(2)
    //   .mul(
    //     ethers.utils
    //       .parseUnits("1", 18)
    //       .mul(ethers.utils.parseUnits("1", usdcDecimals))
    //       .div(ethers.utils.parseUnits("1", wEthDecimals))
    //   )
    //   .div(BigNumber.from("2").pow(96).pow(2));

    // const price1 = BigNumber.from("2")
    //   .pow(96)
    //   .pow(2)
    //   .mul(
    //     ethers.utils
    //       .parseUnits("1", 18)
    //       .mul(ethers.utils.parseUnits("1", wEthDecimals))
    //       .div(ethers.utils.parseUnits("1", usdcDecimals))
    //   )
    //   .div(slot0.sqrtPriceX96.pow(2));

    // #endregion Price computation.

    // For initialization.
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
      manager: managerProxyMock.address,
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

    // #region get some USDC and WETH tokens from Uniswap V3.

    swapRouter = (await ethers.getContractAt(
      "ISwapRouter",
      addresses.SwapRouter,
      user
    )) as ISwapRouter;

    wMatic = new ethers.Contract(
      addresses.WMATIC,
      [
        "function deposit() external payable",
        "function withdraw(uint256 _amount) external",
        "function balanceOf(address account) public view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
      ],
      user
    );

    await wMatic.deposit({ value: ethers.utils.parseUnits("1000", 18) });

    await wMatic.approve(swapRouter.address, ethers.constants.MaxUint256);

    // #region swap wrapped matic for wrapped eth.

    await swapRouter.exactInputSingle({
      tokenIn: addresses.WMATIC,
      tokenOut: addresses.WETH,
      fee: 500,
      recipient: userAddr,
      deadline: ethers.constants.MaxUint256,
      amountIn: ethers.utils.parseUnits("1000", 18),
      amountOutMinimum: ethers.constants.Zero,
      sqrtPriceLimitX96: 0,
    });

    // #endregion swap wrapped matic for wrapped eth.

    // #region swap wrapped matic for usdc.

    await wMatic.deposit({ value: ethers.utils.parseUnits("1000", 18) });

    await swapRouter.exactInputSingle({
      tokenIn: addresses.WMATIC,
      tokenOut: addresses.USDC,
      fee: 500,
      recipient: userAddr,
      deadline: ethers.constants.MaxUint256,
      amountIn: ethers.utils.parseUnits("1000", 18),
      amountOutMinimum: ethers.constants.Zero,
      sqrtPriceLimitX96: 0,
    });

    // #endregion swap wrapped matic for usdc.

    // #endregion get some USDC and WETH tokens from Uniswap V3.
  });

  it("#0: Deposit token and Mint Arrakis V2 tokens ", async () => {
    // #region approve weth and usdc token to vault.

    await wEth.approve(vaultV2.address, ethers.constants.MaxUint256);
    await usdc.approve(vaultV2.address, ethers.constants.MaxUint256);

    // #endregion approve weth and usdc token to vault.

    // #region user balance of weth and usdc.

    const wethBalance = await wEth.balanceOf(userAddr);
    const usdcBalance = await usdc.balanceOf(userAddr);

    // #endregion user balance of weth and usdc.

    // #region mint arrakis vault V2 token.

    const result = await vaultV2Resolver.getMintAmounts(
      vaultV2.address,
      usdcBalance,
      wethBalance
    );

    await vaultV2.mint(result.mintAmount, userAddr);

    const balance = await vaultV2.balanceOf(userAddr);

    expect(balance).to.be.eq(result.mintAmount);

    // #endregion mint arrakis vault V2 token.
  });

  it("#1: Burn Minted Arrakis V2 tokens", async () => {
    // #region mint arrakis token by Lp.

    await wEth.approve(vaultV2.address, ethers.constants.MaxUint256);
    await usdc.approve(vaultV2.address, ethers.constants.MaxUint256);

    // #endregion approve weth and usdc token to vault.

    // #region user balance of weth and usdc.

    const wethBalance = await wEth.balanceOf(userAddr);
    const usdcBalance = await usdc.balanceOf(userAddr);

    // #endregion user balance of weth and usdc.

    // #region mint arrakis vault V2 token.

    const result = await vaultV2Resolver.getMintAmounts(
      vaultV2.address,
      usdcBalance,
      wethBalance
    );

    await vaultV2.mint(result.mintAmount, userAddr);

    let balance = await vaultV2.balanceOf(userAddr);

    expect(balance).to.be.eq(result.mintAmount);

    // #endregion mint arrakis token by Lp.
    // #region burn token to get back token to user.

    await vaultV2.burn([], result.mintAmount, userAddr);

    balance = await vaultV2.balanceOf(userAddr);

    expect(balance).to.be.eq(0);

    // #endregion burn token to get back token to user.
  });

  it("#2: Rebalance after mint and burn of Arrakis V2 tokens", async () => {
    // #region mint arrakis token by Lp.

    await wEth.approve(vaultV2.address, ethers.constants.MaxUint256);
    await usdc.approve(vaultV2.address, ethers.constants.MaxUint256);

    // #endregion approve weth and usdc token to vault.

    // #region user balance of weth and usdc.

    const wethBalance = await wEth.balanceOf(userAddr);
    const usdcBalance = await usdc.balanceOf(userAddr);

    // #endregion user balance of weth and usdc.

    // #region mint arrakis vault V2 token.

    const result = await vaultV2Resolver.getMintAmounts(
      vaultV2.address,
      usdcBalance,
      wethBalance
    );

    await vaultV2.mint(result.mintAmount, userAddr);

    let balance = await vaultV2.balanceOf(userAddr);

    expect(balance).to.be.eq(result.mintAmount);

    // #endregion mint arrakis token by Lp.
    // #region rebalance to deposit user token into the uniswap v3 pool.

    const rebalanceParams = await vaultV2Resolver.standardRebalance(
      [{ range: { lowerTick, upperTick, feeTier: 500 }, weight: 10000 }],
      vaultV2.address
    );

    await managerProxyMock.rebalance(
      vaultV2.address,
      [{ lowerTick, upperTick, feeTier: 500 }],
      rebalanceParams,
      []
    );

    // #endregion rebalance to deposit user token into the uniswap v3 pool.
    // #region burn token to get back token to user.

    const burnPayload = await vaultV2Resolver.standardBurnParams(
      result.mintAmount,
      vaultV2.address
    );

    await vaultV2.burn(burnPayload, result.mintAmount, userAddr);

    balance = await vaultV2.balanceOf(userAddr);

    expect(await usdc.balanceOf(vaultV2.address)).to.be.eq(0);
    expect(await wEth.balanceOf(vaultV2.address)).to.be.eq(0);

    expect(balance).to.be.eq(0);

    // #endregion burn token to get back token to user.
  });
});
