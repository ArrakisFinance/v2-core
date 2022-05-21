// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FullMath, LiquidityAmounts} from "../vendor/uniswap/LiquidityAmounts.sol";
import {TickMath} from "../vendor/uniswap/TickMath.sol";
import {PositionUnderlying, Range, ComputeFeesEarned, UnderlyingPayload, UnderStruct} from "../structs/SMultiposition.sol";

/* solhint-disable */
// prettier-ignore
// using TickMath for int24;
/* solhint-enable */

function _subtractAdminFees(
    uint256 rawFee0_,
    uint256 rawFee1_,
    uint16 managerFeeBPS_
) view returns (uint256 fee0, uint256 fee1) {
    fee0 = rawFee0_ - ((rawFee0_ * (managerFeeBPS_)) / 10000);
    fee1 = rawFee1_ - ((rawFee1_ * (managerFeeBPS_)) / 10000);
}

function _getPositionId(
    address self_,
    int24 lowerTick_,
    int24 upperTick_
) view returns (bytes32 positionId) {
    return keccak256(abi.encodePacked(self_, lowerTick_, upperTick_));
}

function _computeMintAmounts(
    uint256 current0_,
    uint256 current1_,
    uint256 totalSupply_,
    uint256 amount0Max_,
    uint256 amount1Max_
)
    pure
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 mintAmount
    )
{
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
        require(amount0Mint > 0 && amount1Mint > 0, "ArrakisVaultV2: mint 0");

        mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
    } else {
        revert("ArrakisVaultV2: panic");
    }

    // compute amounts owed to contract
    amount0 = FullMath.mulDivRoundingUp(mintAmount, current0_, totalSupply_);
    amount1 = FullMath.mulDivRoundingUp(mintAmount, current1_, totalSupply_);
}

// solhint-disable-next-line function-max-lines
function _computeFeesEarned(ComputeFeesEarned memory computeFeesEarned_)
    view
    returns (uint256 fee)
{
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    if (computeFeesEarned_.isZero) {
        feeGrowthGlobal = computeFeesEarned_.pool.feeGrowthGlobal0X128();
        (, , feeGrowthOutsideLower, , , , , ) = computeFeesEarned_.pool.ticks(
            computeFeesEarned_.lowerTick
        );
        (, , feeGrowthOutsideUpper, , , , , ) = computeFeesEarned_.pool.ticks(
            computeFeesEarned_.upperTick
        );
    } else {
        feeGrowthGlobal = computeFeesEarned_.pool.feeGrowthGlobal1X128();
        (, , , feeGrowthOutsideLower, , , , ) = computeFeesEarned_.pool.ticks(
            computeFeesEarned_.lowerTick
        );
        (, , , feeGrowthOutsideUpper, , , , ) = computeFeesEarned_.pool.ticks(
            computeFeesEarned_.upperTick
        );
    }

    unchecked {
        // calculate fee growth below
        uint256 feeGrowthBelow;
        if (computeFeesEarned_.tick >= computeFeesEarned_.lowerTick) {
            feeGrowthBelow = feeGrowthOutsideLower;
        } else {
            feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
        }

        // calculate fee growth above
        uint256 feeGrowthAbove;
        if (computeFeesEarned_.tick < computeFeesEarned_.upperTick) {
            feeGrowthAbove = feeGrowthOutsideUpper;
        } else {
            feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
        }

        uint256 feeGrowthInside = feeGrowthGlobal -
            feeGrowthBelow -
            feeGrowthAbove;
        fee = FullMath.mulDiv(
            computeFeesEarned_.liquidity,
            feeGrowthInside - computeFeesEarned_.feeGrowthInsideLast,
            0x100000000000000000000000000000000
        );
    }
}

/// @dev Fetches time-weighted average price in ticks from Uniswap pool.
function _getTwap(IUniswapV3Pool pool_, uint24 twapDuration_)
    view
    returns (int24)
{
    uint32[] memory secondsAgo = new uint32[](2);
    secondsAgo[0] = twapDuration_;
    secondsAgo[1] = 0;

    (int56[] memory tickCumulatives, ) = pool_.observe(secondsAgo);
    return
        int24(
            (tickCumulatives[1] - tickCumulatives[0]) /
                int56(uint56(twapDuration_))
        );
}

function _checkDeviation(
    IUniswapV3Pool pool_,
    uint24 twapDuration_,
    int24 maxTwapDeviation_
) view {
    (, int24 tick, , , , , ) = pool_.slot0();
    int24 twap = _getTwap(pool_, twapDuration_);

    int24 deviation = tick > twap ? tick - twap : twap - tick;
    require(deviation <= maxTwapDeviation_, "maxTwapDeviation");
}

/// @notice this function is not marked view because of internal delegatecalls
/// but it should be staticcalled from off chain
function _mintAmounts(
    UnderlyingPayload memory underlyingPayload_,
    uint256 init0_,
    uint256 init1_,
    uint256 totalSupply_,
    uint256 amount0Max,
    uint256 amount1Max
)
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 mintAmount
    )
{
    (uint256 current0, uint256 current1) = totalSupply_ > 0
        ? _totalUnderlying(underlyingPayload_)
        : (init0_, init1_);

    return
        _computeMintAmounts(
            current0,
            current1,
            totalSupply_ > 0 ? totalSupply_ : 1 ether,
            amount0Max,
            amount1Max
        );
}

function _totalUnderlying(UnderlyingPayload memory underlyingPayload_)
    view
    returns (uint256 amount0, uint256 amount1)
{
    for (uint256 i = 0; i < underlyingPayload_.ranges.length; i++) {
        (uint256 a0, uint256 a1, uint256 fee0, uint256 fee1) = _underlying(
            UnderStruct({
                self: underlyingPayload_.self,
                range: underlyingPayload_.ranges[i],
                pool: IUniswapV3Pool(
                    underlyingPayload_.factory.getPool(
                        underlyingPayload_.token0,
                        underlyingPayload_.token1,
                        underlyingPayload_.ranges[i].feeTier
                    )
                )
            })
        );
        amount0 += a0 + fee0;
        amount1 += a1 + fee1;
    }
    amount0 += IERC20(underlyingPayload_.token0).balanceOf(
        underlyingPayload_.self
    );
    amount1 += IERC20(underlyingPayload_.token1).balanceOf(
        underlyingPayload_.self
    );
}

function _totalUnderlyingAtPrice(
    UnderlyingPayload memory underlyingPayload_,
    uint160 sqrtRatioX96_
) view returns (uint256 amount0, uint256 amount1) {
    for (uint256 i = 0; i < underlyingPayload_.ranges.length; i++) {
        (
            uint256 a0,
            uint256 a1,
            uint256 fee0,
            uint256 fee1
        ) = _underlyingAtPrice(
                UnderStruct({
                    self: underlyingPayload_.self,
                    range: underlyingPayload_.ranges[i],
                    pool: IUniswapV3Pool(
                        underlyingPayload_.factory.getPool(
                            underlyingPayload_.token0,
                            underlyingPayload_.token1,
                            underlyingPayload_.ranges[i].feeTier
                        )
                    )
                }),
                sqrtRatioX96_
            );
        amount0 += a0 + fee0;
        amount1 += a1 + fee1;
    }
    amount0 += IERC20(underlyingPayload_.token0).balanceOf(
        underlyingPayload_.self
    );
    amount1 += IERC20(underlyingPayload_.token1).balanceOf(
        underlyingPayload_.self
    );
}

function _totalUnderlyingWithFees(UnderlyingPayload memory underlyingPayload_)
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
            (uint256 a0, uint256 a1, uint256 f0, uint256 f1) = _underlying(
                UnderStruct({
                    self: underlyingPayload_.self,
                    range: underlyingPayload_.ranges[i],
                    pool: pool
                })
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

function _underlying(UnderStruct memory underlying_)
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
    (uint160 sqrtPriceX96, int24 tick, , , , , ) = underlying_.pool.slot0();
    bytes32 positionId = _getPositionId(
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
    (a0, a1, f0, f1) = _getUnderlyingBalances(positionUnderlying);
    amount0 += a0;
    amount1 += a1;
    fee0 += f0;
    fee1 += f1;
}

function _underlyingAtPrice(
    UnderStruct memory underlying_,
    uint160 sqrtPriceX96_
)
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
    bytes32 positionId = _getPositionId(
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
    (a0, a1, f0, f1) = _getUnderlyingBalances(positionUnderlying);
    amount0 += a0;
    amount1 += a1;
    fee0 += f0;
    fee1 += f1;
}

function _getUnderlyingBalances(PositionUnderlying memory positionUnderlying_)
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
    (amount0Current, amount1Current) = LiquidityAmounts.getAmountsForLiquidity(
        positionUnderlying_.sqrtPriceX96,
        TickMath.getSqrtRatioAtTick(positionUnderlying_.lowerTick),
        TickMath.getSqrtRatioAtTick(positionUnderlying_.upperTick),
        liquidity
    );

    // compute current fees earned
    fee0 =
        _computeFeesEarned(
            ComputeFeesEarned({
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
        _computeFeesEarned(
            ComputeFeesEarned({
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

// #region Storage checkers

function _validateTickSpacing(
    IUniswapV3Factory factory_,
    address token0_,
    address token1_,
    Range memory range_
) view returns (bool) {
    int24 spacing = IUniswapV3Pool(
        factory_.getPool(token0_, token1_, range_.feeTier)
    ).tickSpacing();
    return
        range_.lowerTick < range_.upperTick &&
        range_.lowerTick % spacing == 0 &&
        range_.upperTick % spacing == 0;
}

// #endregion Storage checkers
