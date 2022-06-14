// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LiquidityAmounts} from "../vendor/uniswap/LiquidityAmounts.sol";
import {TickMath} from "../vendor/uniswap/TickMath.sol";
import {
    UnderlyingPayload,
    RangeData,
    PositionUnderlying,
    FeesEarnedPayload
} from "../structs/SVaultV2.sol";
import {UniswapV3Amounts} from "./UniswapV3Amounts.sol";
import {Position} from "./Position.sol";

library Underlying {
    // solhint-disable-next-line function-max-lines
    function totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_
    )
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        for (uint256 i = 0; i < underlyingPayload_.ranges.length; i++) {
            {
                IUniswapV3Pool pool = IUniswapV3Pool(
                    underlyingPayload_.factory.getPool(
                        underlyingPayload_.token0,
                        underlyingPayload_.token1,
                        underlyingPayload_.ranges[i].feeTier
                    )
                );
                (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) = underlying(
                    RangeData({
                        self: underlyingPayload_.self,
                        range: underlyingPayload_.ranges[i],
                        pool: pool
                    }),
                    sqrtPriceX96
                );
                amount0 += a0 + f0;
                amount1 += a1 + f1;
                fee0 += f0;
                fee1 += f1;
            }
        }

        amount0 += IERC20(underlyingPayload_.token0).balanceOf(
            underlyingPayload_.self
        );
        amount1 += IERC20(underlyingPayload_.token1).balanceOf(
            underlyingPayload_.self
        );
    }

    function underlying(RangeData memory underlying_, uint160 sqrtPriceX96_)
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 a0;
        uint256 a1;
        uint256 f0;
        uint256 f1;
        (, int24 tick, , , , , ) = underlying_.pool.slot0();
        bytes32 positionId = Position.getPositionId(
            underlying_.self,
            underlying_.range.lowerTick,
            underlying_.range.upperTick
        );
        PositionUnderlying memory positionUnderlying = PositionUnderlying({
            positionId: positionId,
            sqrtPriceX96: sqrtPriceX96_,
            tick: tick,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick,
            pool: underlying_.pool
        });
        (a0, a1, f0, f1) = getUnderlyingBalances(positionUnderlying);
        amount0 += a0;
        amount1 += a1;
        fee0 += f0;
        fee1 += f1;
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalances(
        PositionUnderlying memory positionUnderlying_
    )
        public
        view
        returns (
            uint256 amount0Current,
            uint256 amount1Current,
            uint256 fee0,
            uint256 fee1
        )
    {
        (
            uint128 liquidity,
            uint256 feeGrowthInside0Last,
            uint256 feeGrowthInside1Last,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionUnderlying_.pool.positions(positionUnderlying_.positionId);

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
                positionUnderlying_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
                TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
                liquidity
            );

        // compute current fees earned
        fee0 =
            UniswapV3Amounts.computeFeesEarned(
                FeesEarnedPayload({
                    feeGrowthInsideLast: feeGrowthInside0Last,
                    liquidity: liquidity,
                    tick: positionUnderlying_.tick,
                    lowerTick: positionUnderlying_.lowerTick,
                    upperTick: positionUnderlying_.upperTick,
                    isZero: true,
                    pool: positionUnderlying_.pool
                })
            ) +
            uint256(tokensOwed0);
        fee1 =
            UniswapV3Amounts.computeFeesEarned(
                FeesEarnedPayload({
                    feeGrowthInsideLast: feeGrowthInside1Last,
                    liquidity: liquidity,
                    tick: positionUnderlying_.tick,
                    lowerTick: positionUnderlying_.lowerTick,
                    upperTick: positionUnderlying_.upperTick,
                    isZero: false,
                    pool: positionUnderlying_.pool
                })
            ) +
            uint256(tokensOwed1);
    }
}
