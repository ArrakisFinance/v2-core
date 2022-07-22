import hre, { ethers } from "hardhat";
import { getAddresses } from "../src/addresses";
import {
  IUniswapV3Factory,
  IUniswapV3Pool,
  VaultV2Resolver,
} from "../typechain";
import { getNearestTick } from "../src/utils";

// #region input values.

const feeTier = 500; // uniswap v3 feeTier.
const token0 = "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270"; // token0 address. token0 < token1 USDC on polygon
const token1 = "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619"; // token1 address. token0 < token1 WETH on polygon
let owner = ""; // owner address.
let managerTreasury = ""; // manager addres.
const managerFeeBPS = 100; // manager fee.
const maxTwapDeviation = 100; // twap deviation max value.
const twapDuration = 2000; // number of seconds.
const maxSlippage = 100;

const lowerPrice = ethers.utils.parseUnits("0.0003", 18); // lower price limit.
const upperPrice = ethers.utils.parseUnits("0.0005", 18); // upper price limit.

// #endregion input values.

async function main() {
  const addresses = getAddresses(hre.network.name);
  const [user] = await ethers.getSigners();
  const operator = await user.getAddress();
  const vaultV2Factory = await ethers.getContract("VaultV2Factory", user);
  const vaultV2Resolver = (await ethers.getContract(
    "VaultV2Resolver"
  )) as VaultV2Resolver;

  const uniswapV3Factory = (await ethers.getContractAt(
    "IUniswapV3Factory",
    addresses.UniswapV3Factory,
    user
  )) as IUniswapV3Factory;

  const pool = (await ethers.getContractAt(
    "IUniswapV3Pool",
    await uniswapV3Factory.getPool(token0, token1, feeTier),
    user
  )) as IUniswapV3Pool;

  // #region set owner and manager. Can be custmized.

  owner = operator;
  managerTreasury = operator;

  // #endregion set owner and manager. Can be customized.

  // #region ERC20 contracts.

  const token0Contract = new ethers.Contract(
    token0,
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
    ],
    user
  );

  const token1Contract = new ethers.Contract(
    token1,
    [
      "function decimals() external view returns (uint8)",
      "function balanceOf(address account) public view returns (uint256)",
      "function approve(address spender, uint256 amount) external returns (bool)",
    ],
    user
  );

  // #endregion ERC20 contracts.

  // #region get tick from price.

  const lowerTick = (
    await getNearestTick(
      pool,
      await token0Contract.decimals(),
      await token1Contract.decimals(),
      lowerPrice
    )
  ).lower;

  const upperTick = (
    await getNearestTick(
      pool,
      await token0Contract.decimals(),
      await token1Contract.decimals(),
      upperPrice
    )
  ).upper;

  const slot0 = await pool.slot0();

  const res = await vaultV2Resolver.getAmountsForLiquidity(
    slot0.tick,
    lowerTick,
    upperTick,
    ethers.utils.parseUnits("1", 18)
  );

  // #endregion get tick from price.

  const tx = await vaultV2Factory.deployVault({
    feeTiers: [feeTier],
    token0,
    token1,
    owner,
    operators: [operator],
    ranges: [
      {
        lowerTick: lowerTick,
        upperTick: upperTick,
        feeTier: feeTier,
      },
    ],
    init0: res.amount0,
    init1: res.amount1,
    managerTreasury,
    managerFeeBPS,
    maxTwapDeviation,
    twapDuration,
    maxSlippage,
  });

  const rc = await tx.wait();
  const event = rc?.events?.find(
    (e: { event: string }) => e.event === "VaultCreated"
  );
  // eslint-disable-next-line no-unsafe-optional-chaining
  const result = event?.args;

  console.log("Created vault V2 address : ", result?.vault);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
