import { expect } from "chai";
import { Contract, Signer } from "ethers";
import hre = require("hardhat");
import {
  ArrakisV2,
  ArrakisV2Factory,
  ArrakisV2Helper,
  ArrakisV2Resolver,
  ISwapRouter,
  IUniswapV3Factory,
  IUniswapV3Pool,
  ManagerProxyMock,
} from "../../typechain";
import { Addresses, getAddresses } from "../../src/addresses";
const { ethers, deployments } = hre;

describe("ArrakisV2Helper functions unit test", function () {
  this.timeout(0);

  let user: Signer;
  let userAddr: string;
  let arrakisV2Helper: ArrakisV2Helper;
  let uniswapV3Factory: IUniswapV3Factory;
  let uniswapV3Pool: IUniswapV3Pool;
  let arrakisV2: ArrakisV2;
  let arrakisV2Factory: ArrakisV2Factory;
  let managerProxyMock: ManagerProxyMock;
  let arrakisV2Resolver: ArrakisV2Resolver;
  let swapRouter: ISwapRouter;
  let addresses: Addresses;
  let wEth: Contract;
  let usdc: Contract;
  let wMatic: Contract;
  let lowerTick: number;
  let upperTick: number;

  before(
    "Setting up for ArrakisV2Helper functions unit test",
    async function () {
      if (hre.network.name !== "hardhat") {
        console.error("Test Suite is meant to be run on hardhat only");
        process.exit(1);
      }

      await deployments.fixture();

      addresses = getAddresses(hre.network.name);

      [user, , ,] = await ethers.getSigners();

      userAddr = await user.getAddress();

      arrakisV2Factory = (await ethers.getContract(
        "ArrakisV2Factory",
        user
      )) as ArrakisV2Factory;
      arrakisV2Helper = (await ethers.getContract(
        "ArrakisV2Helper",
        user
      )) as ArrakisV2Helper;
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
      arrakisV2Resolver = (await ethers.getContract(
        "ArrakisV2Resolver"
      )) as ArrakisV2Resolver;

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

      const slot0 = await uniswapV3Pool.slot0();
      const tickSpacing = await uniswapV3Pool.tickSpacing();

      lowerTick = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing;
      upperTick = slot0.tick - (slot0.tick % tickSpacing) + 2 * tickSpacing;

      const res = await arrakisV2Resolver.getAmountsForLiquidity(
        slot0.tick,
        lowerTick,
        upperTick,
        ethers.utils.parseUnits("1", 18)
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
          burnBuffer: 1000,
        },
        true
      );
      const rc = await tx.wait();
      const event = rc?.events?.find((event) => event.event === "VaultCreated");
      // eslint-disable-next-line no-unsafe-optional-chaining
      const result = event?.args;

      arrakisV2 = (await ethers.getContractAt(
        "ArrakisV2",
        result?.vault,
        user
      )) as ArrakisV2;

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

      // #region mint arrakis token by Lp.

      await wEth.approve(arrakisV2.address, ethers.constants.MaxUint256);
      await usdc.approve(arrakisV2.address, ethers.constants.MaxUint256);

      // #endregion approve weth and usdc token to vault.

      // #region user balance of weth and usdc.

      const wethBalance = await wEth.balanceOf(userAddr);
      const usdcBalance = await usdc.balanceOf(userAddr);

      // #endregion user balance of weth and usdc.

      // #region mint arrakis vault V2 token.

      const result2 = await arrakisV2Resolver.getMintAmounts(
        arrakisV2.address,
        usdcBalance,
        wethBalance
      );

      await arrakisV2.mint(result2.mintAmount, userAddr);

      const balance = await arrakisV2.balanceOf(userAddr);

      expect(balance).to.be.eq(result2.mintAmount);

      // #endregion mint arrakis token by Lp.
      // #region rebalance to deposit user token into the uniswap v3 pool.

      const rebalanceParams = await arrakisV2Resolver.standardRebalance(
        [
          {
            range: { lowerTick, upperTick, pool: uniswapV3Pool.address },
            weight: 10000,
          },
        ],
        arrakisV2.address
      );

      await managerProxyMock.rebalance(
        arrakisV2.address,
        [{ lowerTick, upperTick, pool: uniswapV3Pool.address }],
        rebalanceParams,
        []
      );

      // #region do a swap to generate fees.

      const swapR: ISwapRouter = (await ethers.getContractAt(
        "ISwapRouter",
        "0xE592427A0AEce92De3Edee1F18E0157C05861564",
        user
      )) as ISwapRouter;

      await wMatic.deposit({ value: ethers.utils.parseUnits("1000", 18) });
      await wMatic.approve(swapR.address, ethers.utils.parseUnits("1000", 18));

      await swapR.exactInputSingle({
        tokenIn: addresses.WMATIC,
        tokenOut: addresses.WETH,
        fee: 500,
        recipient: userAddr,
        deadline: ethers.constants.MaxUint256,
        amountIn: ethers.utils.parseUnits("1000", 18),
        amountOutMinimum: ethers.constants.Zero,
        sqrtPriceLimitX96: 0,
      });

      await wEth.approve(swapR.address, ethers.utils.parseEther("0.001"));

      await swapR.exactInputSingle({
        tokenIn: wEth.address,
        tokenOut: usdc.address,
        fee: 500,
        recipient: userAddr,
        deadline: ethers.constants.MaxUint256,
        amountIn: ethers.utils.parseEther("0.001"),
        amountOutMinimum: ethers.constants.Zero,
        sqrtPriceLimitX96: 0,
      });

      // #endregion do a swap to generate fess.

      // #endregion rebalance to deposit user token into the uniswap v3 pool.
    }
  );

  it("#0: get token0 and token1 amounts of vault for first range", async () => {
    const result = await arrakisV2Helper.token0AndToken1ByRange(
      [
        {
          lowerTick: lowerTick,
          upperTick: upperTick,
          pool: uniswapV3Pool.address,
        },
      ],
      await arrakisV2.token0(),
      await arrakisV2.token1(),
      arrakisV2.address
    );

    expect(result.amount0s[0].amount).to.be.gt(0);
    expect(result.amount1s[0].amount).to.be.gt(0);
  });

  it("#1: get token0 and token1 amounts with their fees of vault for first range with fees", async () => {
    const result = await arrakisV2Helper.token0AndToken1PlusFeesByRange(
      [
        {
          lowerTick: lowerTick,
          upperTick: upperTick,
          pool: uniswapV3Pool.address,
        },
      ],
      await arrakisV2.token0(),
      await arrakisV2.token1(),
      arrakisV2.address
    );

    expect(result.amount0s[0].amount).to.be.gt(0);
    expect(result.fee0s[0].amount).to.be.eq(0);
    expect(result.amount1s[0].amount).to.be.gt(0);
    expect(result.fee1s[0].amount).to.be.gt(0);
  });

  it("#2: get token0 and token1 amounts of vault ", async () => {
    const result = await arrakisV2Helper.totalUnderlying(arrakisV2.address);

    expect(result.amount0).to.be.gt(0);
    expect(result.amount1).to.be.gt(0);
  });

  it("#3: get token0 and token1 with their fees amounts of vault ", async () => {
    const result = await arrakisV2Helper.totalUnderlyingWithFees(
      arrakisV2.address
    );

    expect(result.amount0).to.be.gt(0);
    expect(result.amount1).to.be.gt(0);
    expect(result.fee0).to.be.eq(0);
    expect(result.fee1).to.be.gt(0);
  });
  it("#4: get token0 and token1 with their fees and left over amounts of vault ", async () => {
    const result = await arrakisV2Helper.totalUnderlyingWithFeesAndLeftOver(
      arrakisV2.address
    );

    expect(result.amount0).to.be.gt(0);
    expect(result.amount1).to.be.gt(0);
    expect(result.fee0).to.be.eq(0);
    expect(result.fee1).to.be.gt(0);
  });
});
