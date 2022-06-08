import { BigNumber, ethers } from "ethers";
import { IUniswapV3Pool } from "../../typechain";
import { TickMath } from "@uniswap/v3-sdk";
import JSBI from "jsbi";

export const sqrt = (x: BigNumber) => {
  const ONE = ethers.BigNumber.from(1);
  const TWO = ethers.BigNumber.from(2);
  let z = x.add(ONE).div(TWO);
  let y = x;
  while (z.sub(y).isNegative()) {
    y = z;
    z = x.div(z).add(z).div(TWO);
  }
  return y;
};

export const getNearestTick = async (
  pool: IUniswapV3Pool,
  tkn0Decimal: number,
  tkn1Decimal: number,
  price: BigNumber
): Promise<{ lower: number; upper: number }> => {
  const sqrtPriceX96 = sqrt(price)
    .mul(BigNumber.from(2).pow(96))
    .div(
      sqrt(
        ethers.utils
          .parseUnits("1", 18)
          .mul(ethers.utils.parseUnits("1", tkn0Decimal))
          .div(ethers.utils.parseUnits("1", tkn1Decimal))
      )
    );

  const tick = TickMath.getTickAtSqrtRatio(
    JSBI.BigInt(sqrtPriceX96.toString())
  );
  const tickSpacing: number = await pool.tickSpacing();

  const lower = tick - (tick % tickSpacing);
  const upper = lower + tickSpacing;

  return { lower, upper };
};
