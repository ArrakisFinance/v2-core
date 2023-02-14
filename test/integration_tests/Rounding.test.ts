import { expect } from "chai";
import hre = require("hardhat");
import {
  ArrakisV2,
  ArrakisV2Factory,
  ISwapRouter,
  IUniswapV3Factory,
  IUniswapV3Pool,
  ArrakisV2Resolver,
  ArrakisV2Helper,
} from "../../typechain";
import { getAddresses, Addresses } from "../../src/addresses";
import { Signer } from "ethers";
import { Contract } from "ethers";
import { ManagerProxyMock } from "../../typechain/contracts/__mocks__/ManagerProxyMock";

const { ethers, deployments } = hre;

describe("Rounding integration test", async function () {
  this.timeout(0);

  let user: Signer;
  let userAddr: string;
  let arrakisV2Factory: ArrakisV2Factory;
  let vaultV2: ArrakisV2;
  let uniswapV3Factory: IUniswapV3Factory;
  let uniswapV3Pool: IUniswapV3Pool;
  let arrakisV2Resolver: ArrakisV2Resolver;
  let helper: ArrakisV2Helper;
  let wEth: Contract;
  let usdc: Contract;
  let addresses: Addresses;
  let lowerTick: number;
  let upperTick: number;

  let managerProxyMock: ManagerProxyMock;
  let nullSwap: any;

  let swapRouter: ISwapRouter;
  let wMatic: Contract;

  before("Setting up for V2 functions integration test", async function () {
    if (hre.network.name !== "hardhat") {
      console.error("Test Suite is meant to be run on hardhat only");
      process.exit(1);
    }

    [user] = await ethers.getSigners();

    userAddr = await user.getAddress();

    addresses = getAddresses(hre.network.name);
    await deployments.fixture();

    arrakisV2Factory = (await ethers.getContract(
      "ArrakisV2Factory"
    )) as ArrakisV2Factory;

    arrakisV2Resolver = (await ethers.getContract(
      "ArrakisV2Resolver"
    )) as ArrakisV2Resolver;

    helper = (await ethers.getContract("ArrakisV2Helper")) as ArrakisV2Helper;

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

    wEth = new ethers.Contract(
      addresses.WETH,
      [
        "function decimals() external view returns (uint8)",
        "function balanceOf(address account) public view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
        "function transfer(address to, uint256 amount) external returns (bool)",
      ],
      user
    );

    usdc = new ethers.Contract(
      addresses.USDC,
      [
        "function decimals() external view returns (uint8)",
        "function balanceOf(address account) public view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
        "function transfer(address to, uint256 amount) external returns (bool)",
      ],
      user
    );

    nullSwap = {
      payload: "0x",
      router: ethers.constants.AddressZero,
      amountIn: 0,
      expectedMinReturn: 0,
      zeroForOne: false,
    };

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

    const slot0 = await uniswapV3Pool.slot0();
    const tickSpacing = await uniswapV3Pool.tickSpacing();

    lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
    upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

    // For initialization.
    const res = await arrakisV2Resolver.getAmountsForLiquidity(
      slot0.sqrtPriceX96,
      lowerTick,
      upperTick,
      ethers.utils.parseUnits("1", 12)
    );

    const tx = await arrakisV2Factory.deployVault(
      {
        feeTiers: [500],
        token0: addresses.USDC,
        token1: addresses.WETH,
        owner: userAddr,
        init0: res.amount0,
        init1: res.amount1,
        manager: managerProxyMock.address,
        routers: [],
      },
      true
    );

    const rc = await tx.wait();
    const event = rc?.events?.find((event) => event.event === "VaultCreated");
    // eslint-disable-next-line no-unsafe-optional-chaining
    const result = event?.args;

    vaultV2 = (await ethers.getContractAt(
      "ArrakisV2",
      result?.vault,
      user
    )) as ArrakisV2;
  });
  it("0: should rebalance exact amount with no leftover", async () => {
    await wEth.approve(vaultV2.address, ethers.constants.MaxUint256);
    await usdc.approve(vaultV2.address, ethers.constants.MaxUint256);

    await vaultV2.mint(ethers.utils.parseEther("1"), userAddr);

    let balance0 = await usdc.balanceOf(vaultV2.address);
    let balance1 = await wEth.balanceOf(vaultV2.address);

    const init0 = await vaultV2.init0();
    const init1 = await vaultV2.init1();

    expect(balance0).to.be.eq(init0);
    expect(balance1).to.be.eq(init1);

    await expect(
      managerProxyMock.rebalance(vaultV2.address, {
        mints: [
          {
            liquidity: ethers.utils.parseUnits("1", 12),
            range: { lowerTick: lowerTick, upperTick: upperTick, feeTier: 500 },
          },
        ],
        burns: [],
        swap: nullSwap,
        minBurn0: 0,
        minBurn1: 0,
        minDeposit0: 0,
        minDeposit1: 0,
      })
    ).to.be.reverted;

    await vaultV2.burn(ethers.utils.parseEther("1"), userAddr);

    balance0 = await usdc.balanceOf(vaultV2.address);
    balance1 = await wEth.balanceOf(vaultV2.address);

    expect(balance0).to.be.eq(0);
    expect(balance1).to.be.eq(0);

    await vaultV2.setInits(init0.add(1), init1.add(1));

    await vaultV2.mint(ethers.utils.parseEther("1"), userAddr);

    balance0 = await usdc.balanceOf(vaultV2.address);
    balance1 = await wEth.balanceOf(vaultV2.address);

    expect(balance0).to.be.eq(init0.add(1));
    expect(balance1).to.be.eq(init1.add(1));

    const ranges = await vaultV2.getRanges();
    expect(ranges.length).to.be.eq(0);

    await managerProxyMock.rebalance(vaultV2.address, {
      mints: [
        {
          liquidity: ethers.utils.parseUnits("1", 12),
          range: { lowerTick: lowerTick, upperTick: upperTick, feeTier: 500 },
        },
      ],
      burns: [],
      swap: nullSwap,
      minBurn0: 0,
      minBurn1: 0,
      minDeposit0: 0,
      minDeposit1: 0,
    });

    const rangesAfter = await vaultV2.getRanges();
    expect(rangesAfter.length).to.be.eq(1);
    balance0 = await usdc.balanceOf(vaultV2.address);
    balance1 = await wEth.balanceOf(vaultV2.address);

    expect(balance0).to.be.eq(0);
    expect(balance1).to.be.eq(0);
  });
  it("1: mint and burn work properly", async () => {
    // #region approve weth and usdc token to vault.

    await wEth.approve(vaultV2.address, ethers.constants.MaxUint256);
    await usdc.approve(vaultV2.address, ethers.constants.MaxUint256);

    // #endregion approve weth and usdc token to vault.

    // #region user balance of weth and usdc.

    const wethBalance = await wEth.balanceOf(userAddr);
    const usdcBalance = await usdc.balanceOf(userAddr);

    // #endregion user balance of weth and usdc.

    // #region mint arrakis vault V2 token.

    const result = await arrakisV2Resolver.getMintAmounts(
      vaultV2.address,
      usdcBalance,
      wethBalance
    );

    const balanceBefore = await vaultV2.balanceOf(userAddr);
    const ranges = await vaultV2.getRanges();
    expect(ranges.length).to.be.eq(1);
    const totalLiquidityBefore = await helper.totalLiquidity(vaultV2.address);
    expect(totalLiquidityBefore.length).to.eq(1);
    expect(totalLiquidityBefore[0].liquidity).to.be.eq(
      ethers.utils.parseUnits("1", 12)
    );

    await vaultV2.mint(result.mintAmount, userAddr);

    const balance = await vaultV2.balanceOf(userAddr);

    expect(balance.sub(balanceBefore)).to.be.eq(result.mintAmount);

    const totalLiquidityAfter = await helper.totalLiquidity(vaultV2.address);
    expect(totalLiquidityAfter.length).to.eq(1);
    expect(totalLiquidityAfter[0].liquidity).to.be.gt(
      totalLiquidityBefore[0].liquidity
    );
    // #endregion mint arrakis vault V2 token.

    await vaultV2.burn(result.mintAmount, userAddr);

    const wethBalanceAfter = await wEth.balanceOf(userAddr);
    const usdcBalanceAfter = await usdc.balanceOf(userAddr);

    expect(wethBalance.sub(wethBalanceAfter)).to.be.lt(3);
    expect(usdcBalance.sub(usdcBalanceAfter)).to.be.lt(3);

    await vaultV2.burn(await vaultV2.totalSupply(), userAddr);

    const balance0 = await usdc.balanceOf(vaultV2.address);
    const balance1 = await wEth.balanceOf(vaultV2.address);

    expect(balance0).to.be.eq(0);
    expect(balance1).to.be.eq(0);
  });
});
