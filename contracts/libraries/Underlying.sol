// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IArrakisV2} from "../interfaces/IArrakisV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    FullMath,
    LiquidityAmounts
} from "@arrakisfi/v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {SqrtPriceMath} from "@arrakisfi/v3-lib-0.8/contracts/SqrtPriceMath.sol";
import {TickMath} from "@arrakisfi/v3-lib-0.8/contracts/TickMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {
    UnderlyingPayload,
    RangeData,
    PositionUnderlying,
    ComputeFeesPayload,
    GetFeesPayload
} from "../structs/SArrakisV2.sol";
import {Position} from "./Position.sol";

library Underlying {
    // solhint-disable-next-line function-max-lines
    function totalUnderlyingForMint(
        UnderlyingPayload memory underlyingPayload_,
        uint256 mintAmount_,
        uint256 totalSupply_
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                IUniswapV3Pool pool = IUniswapV3Pool(
                    underlyingPayload_.factory.getPool(
                        underlyingPayload_.token0,
                        underlyingPayload_.token1,
                        underlyingPayload_.ranges[i].feeTier
                    )
                );
                (
                    uint256 a0,
                    uint256 a1,
                    uint256 f0,
                    uint256 f1
                ) = underlyingMint(
                        RangeData({
                            self: underlyingPayload_.self,
                            range: underlyingPayload_.ranges[i],
                            pool: pool
                        }),
                        mintAmount_,
                        totalSupply_
                    );
                amount0 += a0;
                amount1 += a1;
                fee0 += f0;
                fee1 += f1;
            }
        }

        IArrakisV2 arrakisV2 = IArrakisV2(underlyingPayload_.self);

        (uint256 fee0After, uint256 fee1After) = subtractAdminFees(
            fee0,
            fee1,
            arrakisV2.managerFeeBPS()
        );

        amount0 += FullMath.mulDivRoundingUp(
            mintAmount_,
            fee0After +
                IERC20(underlyingPayload_.token0).balanceOf(
                    underlyingPayload_.self
                ) -
                arrakisV2.managerBalance0(),
            totalSupply_
        );
        amount1 += FullMath.mulDivRoundingUp(
            mintAmount_,
            fee1After +
                IERC20(underlyingPayload_.token1).balanceOf(
                    underlyingPayload_.self
                ) -
                arrakisV2.managerBalance1(),
            totalSupply_
        );
    }

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
        return _totalUnderlyingWithFees(underlyingPayload_, 0);
    }

    function totalUnderlyingAtPriceWithFees(
        UnderlyingPayload memory underlyingPayload_,
        uint160 sqrtPriceX96_
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
        return _totalUnderlyingWithFees(underlyingPayload_, sqrtPriceX96_);
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
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = underlying_.pool.slot0();
        bytes32 positionId = Position.getPositionId(
            underlying_.self,
            underlying_.range.lowerTick,
            underlying_.range.upperTick
        );
        PositionUnderlying memory positionUnderlying = PositionUnderlying({
            positionId: positionId,
            sqrtPriceX96: sqrtPriceX96_ > 0 ? sqrtPriceX96_ : sqrtPriceX96,
            tick: tick,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick,
            pool: underlying_.pool
        });
        (amount0, amount1, fee0, fee1) = getUnderlyingBalances(
            positionUnderlying
        );
    }

    function underlyingMint(
        RangeData memory underlying_,
        uint256 mintAmount_,
        uint256 totalSupply_
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
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = underlying_.pool.slot0();
        bytes32 positionId = Position.getPositionId(
            underlying_.self,
            underlying_.range.lowerTick,
            underlying_.range.upperTick
        );
        PositionUnderlying memory positionUnderlying = PositionUnderlying({
            positionId: positionId,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            lowerTick: underlying_.range.lowerTick,
            upperTick: underlying_.range.upperTick,
            pool: underlying_.pool
        });
        (amount0, amount1, fee0, fee1) = getUnderlyingBalancesMint(
            positionUnderlying,
            mintAmount_,
            totalSupply_
        );
    }

    // solhint-disable-next-line function-max-lines
    function getUnderlyingBalancesMint(
        PositionUnderlying memory positionUnderlying_,
        uint256 mintAmount_,
        uint256 totalSupply_
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
        uint128 liquidity;
        {
            uint256 feeGrowthInside0Last;
            uint256 feeGrowthInside1Last;
            uint128 tokensOwed0;
            uint128 tokensOwed1;
            (
                liquidity,
                feeGrowthInside0Last,
                feeGrowthInside1Last,
                tokensOwed0,
                tokensOwed1
            ) = positionUnderlying_.pool.positions(
                positionUnderlying_.positionId
            );

            // compute current fees earned
            (fee0, fee1) = _getFeesEarned(
                GetFeesPayload({
                    feeGrowthInside0Last: feeGrowthInside0Last,
                    feeGrowthInside1Last: feeGrowthInside1Last,
                    pool: positionUnderlying_.pool,
                    liquidity: liquidity,
                    tick: positionUnderlying_.tick,
                    lowerTick: positionUnderlying_.lowerTick,
                    upperTick: positionUnderlying_.upperTick
                })
            );

            fee0 += uint256(tokensOwed0);
            fee1 += uint256(tokensOwed1);
        }

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = getAmountsForDelta(
            positionUnderlying_.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
            TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
            SafeCast.toInt128(
                SafeCast.toInt256(
                    FullMath.mulDiv(
                        uint256(liquidity),
                        mintAmount_,
                        totalSupply_
                    )
                )
            )
        );
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

        // compute current fees earned
        (fee0, fee1) = _getFeesEarned(
            GetFeesPayload({
                feeGrowthInside0Last: feeGrowthInside0Last,
                feeGrowthInside1Last: feeGrowthInside1Last,
                pool: positionUnderlying_.pool,
                liquidity: liquidity,
                tick: positionUnderlying_.tick,
                lowerTick: positionUnderlying_.lowerTick,
                upperTick: positionUnderlying_.upperTick
            })
        );

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts
            .getAmountsForLiquidity(
                positionUnderlying_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
                TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
                liquidity
            );

        fee0 += uint256(tokensOwed0);
        fee1 += uint256(tokensOwed1);
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    function getAmountsForDelta(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 < sqrtRatioAX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = SafeCast.toUint256(
                SqrtPriceMath.getAmount0Delta(
                    sqrtRatioX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96,
                    sqrtRatioX96,
                    liquidity
                )
            );
        } else {
            amount1 = SafeCast.toUint256(
                SqrtPriceMath.getAmount1Delta(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    liquidity
                )
            );
        }
    }

    function subtractAdminFees(
        uint256 rawFee0_,
        uint256 rawFee1_,
        uint16 managerFeeBPS_
    ) public pure returns (uint256 fee0, uint256 fee1) {
        fee0 = rawFee0_ - ((rawFee0_ * (managerFeeBPS_)) / 10000);
        fee1 = rawFee1_ - ((rawFee1_ * (managerFeeBPS_)) / 10000);
    }

    // solhint-disable-next-line function-max-lines
    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) public pure returns (uint256 mintAmount) {
        // compute proportional amount of tokens to mint
        if (current0_ == 0 && current1_ > 0) {
            mintAmount = FullMath.mulDiv(amount1Max_, totalSupply_, current1_);
        } else if (current1_ == 0 && current0_ > 0) {
            mintAmount = FullMath.mulDiv(amount0Max_, totalSupply_, current0_);
        } else if (current0_ > 0 && current1_ > 0) {
            uint256 amount0Mint = FullMath.mulDiv(
                amount0Max_,
                totalSupply_,
                current0_
            );
            uint256 amount1Mint = FullMath.mulDiv(
                amount1Max_,
                totalSupply_,
                current1_
            );
            require(
                amount0Mint > 0 && amount1Mint > 0,
                "ArrakisVaultV2: mint 0"
            );

            mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        } else {
            revert("ArrakisVaultV2: panic");
        }
    }

    // solhint-disable-next-line function-max-lines
    function _getFeesEarned(GetFeesPayload memory feeInfo_)
        private
        view
        returns (uint256 fee0, uint256 fee1)
    {
        (
            ,
            ,
            uint256 feeGrowthOutside0Lower,
            uint256 feeGrowthOutside1Lower,
            ,
            ,
            ,

        ) = feeInfo_.pool.ticks(feeInfo_.lowerTick);
        (
            ,
            ,
            uint256 feeGrowthOutside0Upper,
            uint256 feeGrowthOutside1Upper,
            ,
            ,
            ,

        ) = feeInfo_.pool.ticks(feeInfo_.upperTick);

        ComputeFeesPayload memory payload = ComputeFeesPayload({
            feeGrowthInsideLast: feeInfo_.feeGrowthInside0Last,
            feeGrowthOutsideLower: feeGrowthOutside0Lower,
            feeGrowthOutsideUpper: feeGrowthOutside0Upper,
            feeGrowthGlobal: feeInfo_.pool.feeGrowthGlobal0X128(),
            pool: feeInfo_.pool,
            liquidity: feeInfo_.liquidity,
            tick: feeInfo_.tick,
            lowerTick: feeInfo_.lowerTick,
            upperTick: feeInfo_.upperTick
        });

        fee0 = _computeFeesEarned(payload);
        payload.feeGrowthInsideLast = feeInfo_.feeGrowthInside1Last;
        payload.feeGrowthOutsideLower = feeGrowthOutside1Lower;
        payload.feeGrowthOutsideUpper = feeGrowthOutside1Upper;
        payload.feeGrowthGlobal = feeInfo_.pool.feeGrowthGlobal1X128();
        fee1 = _computeFeesEarned(payload);
    }

    // solhint-disable-next-line function-max-lines
    function _totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_,
        uint160 sqrtPriceX96_
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        for (uint256 i; i < underlyingPayload_.ranges.length; i++) {
            {
                IUniswapV3Pool pool = IUniswapV3Pool(
                    underlyingPayload_.factory.getPool(
                        underlyingPayload_.token0,
                        underlyingPayload_.token1,
                        underlyingPayload_.ranges[i].feeTier
                    )
                );
                (uint256 a0, uint256 a1, uint256 f0, uint256 f1) = underlying(
                    RangeData({
                        self: underlyingPayload_.self,
                        range: underlyingPayload_.ranges[i],
                        pool: pool
                    }),
                    sqrtPriceX96_
                );
                amount0 += a0;
                amount1 += a1;
                fee0 += f0;
                fee1 += f1;
            }
        }

        IArrakisV2 arrakisV2 = IArrakisV2(underlyingPayload_.self);

        (uint256 fee0After, uint256 fee1After) = subtractAdminFees(
            fee0,
            fee1,
            arrakisV2.managerFeeBPS()
        );

        amount0 +=
            fee0After +
            IERC20(underlyingPayload_.token0).balanceOf(
                underlyingPayload_.self
            ) -
            arrakisV2.managerBalance0();
        amount1 +=
            fee1After +
            IERC20(underlyingPayload_.token1).balanceOf(
                underlyingPayload_.self
            ) -
            arrakisV2.managerBalance1();
    }

    function _computeFeesEarned(ComputeFeesPayload memory computeFees_)
        private
        pure
        returns (uint256 fee)
    {
        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (computeFees_.tick >= computeFees_.lowerTick) {
                feeGrowthBelow = computeFees_.feeGrowthOutsideLower;
            } else {
                feeGrowthBelow =
                    computeFees_.feeGrowthGlobal -
                    computeFees_.feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (computeFees_.tick < computeFees_.upperTick) {
                feeGrowthAbove = computeFees_.feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove =
                    computeFees_.feeGrowthGlobal -
                    computeFees_.feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside = computeFees_.feeGrowthGlobal -
                feeGrowthBelow -
                feeGrowthAbove;
            fee = FullMath.mulDiv(
                computeFees_.liquidity,
                feeGrowthInside - computeFees_.feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }
}
