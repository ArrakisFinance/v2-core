// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVaultV2Resolver} from  "./interfaces/IVaultV2Resolver.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IVaultV2Helper} from "./interfaces/IVaultV2Helper.sol";
import {IVaultV2} from "./interfaces/IVaultV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Underlying as UnderlyingHelper} from "./libraries/Underlying.sol";
import {UniswapV3Amounts} from "./libraries/UniswapV3Amounts.sol";
import {Position as PositionHelper} from "./libraries/Position.sol";
import {FullMath} from "./vendor/uniswap/FullMath.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {LiquidityAmounts} from "./vendor/uniswap/LiquidityAmounts.sol";
import {
    BurnLiquidity,
    PositionLiquidity,
    UnderlyingOutput,
    UnderlyingPayload,
    Range,
    RangeWeight,
    Rebalance
} from "./structs/SVaultV2.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract VaultV2Resolver is IVaultV2Resolver {
    IUniswapV3Factory public immutable factory;
    IVaultV2Helper public immutable helper;

    constructor(IUniswapV3Factory factory_, IVaultV2Helper helper_) {
        factory = factory_;
        helper = helper_;
    }

    // no swapping. Standard rebalance.
    // solhint-disable-next-line function-max-lines
    function standardRebalance(
        RangeWeight[] memory rangeWeights_,
        IVaultV2 vaultV2_
    ) external view returns (Rebalance memory rebalanceParams) {

        uint256 amount0;
        uint256 amount1;
        address token0Addr;
        address token1Addr;
        {
            Range[] memory ranges = vaultV2_.rangesArray();

            token0Addr = address(vaultV2_.token0());
            token1Addr = address(vaultV2_.token1());

            (amount0, amount1) = helper.totalUnderlying(
                vaultV2_
            );

            for (uint256 i = 0; i < ranges.length; i++) {
                uint128 liquidity;
                {
                    (liquidity, , , , ) = IUniswapV3Pool(
                        vaultV2_.factory().getPool(
                            token0Addr,
                            token1Addr,
                            ranges[i].feeTier
                        )
                    ).positions(
                            PositionHelper.getPositionId(
                                address(vaultV2_),
                                ranges[i].lowerTick,
                                ranges[i].upperTick
                            )
                        );
                }

                if (liquidity > 0)
                    rebalanceParams.removes[i] = PositionLiquidity({
                        liquidity: liquidity,
                        range: ranges[i]
                    });
            }
        }

        // TODO check if sum of weight is < 10000

        _requireWeightUnder100(rangeWeights_);

        rebalanceParams.deposits = new PositionLiquidity[](rangeWeights_.length);

        for (uint256 i = 0; i < rangeWeights_.length; i++) {
            RangeWeight memory rangeWeight = rangeWeights_[i];
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(
                vaultV2_.factory().getPool(
                    token0Addr,
                    token1Addr,
                    rangeWeight.range.feeTier
                )
            ).slot0();

            uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(rangeWeight.range.lowerTick),
                TickMath.getSqrtRatioAtTick(rangeWeight.range.upperTick),
                FullMath.mulDiv(amount0, rangeWeight.weight, 10000),
                FullMath.mulDiv(amount1, rangeWeight.weight, 10000)
            );

            rebalanceParams.deposits[i] = PositionLiquidity({
                liquidity: liquidity,
                range: rangeWeight.range
            });
        }
    }

    // solhint-disable-next-line function-max-lines
    function standardBurnParams(uint256 amountToBurn_, IVaultV2 vaultV2_)
        external
        view
        returns (BurnLiquidity[] memory burns)
    {
        uint256 totalSupply = vaultV2_.totalSupply();
        require(totalSupply > 0, "total supply");

        Range[] memory ranges = vaultV2_.rangesArray();

        {
            UnderlyingOutput memory underlying;
            (
                underlying.amount0,
                underlying.amount1,
                underlying.fee0,
                underlying.fee1
            ) = UnderlyingHelper.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: ranges,
                    factory: factory,
                    token0: address(vaultV2_.token0()),
                    token1: address(vaultV2_.token1()),
                    self: address(vaultV2_)
                })
            );
            underlying.leftOver0 = vaultV2_.token0().balanceOf(address(vaultV2_));
            underlying.leftOver1 = vaultV2_.token1().balanceOf(address(vaultV2_));

            {
                (uint256 fee0, uint256 fee1) = UniswapV3Amounts
                    .subtractAdminFees(
                        underlying.fee0,
                        underlying.fee1,
                        vaultV2_.managerFeeBPS(),
                        vaultV2_.arrakisFeeBPS()
                    );
                underlying.amount0 += underlying.leftOver0 + fee0;
                underlying.amount1 += underlying.leftOver1 + fee1;
            }

            {
                uint256 amount0 = FullMath.mulDiv(
                    underlying.amount0,
                    amountToBurn_,
                    totalSupply
                );
                uint256 amount1 = FullMath.mulDiv(
                    underlying.amount1,
                    amountToBurn_,
                    totalSupply
                );

                if (
                    amount0 <= underlying.leftOver0 &&
                    amount1 <= underlying.leftOver1
                ) return burns;
            }
        }
        // #endregion get amount to burn.

        burns = new BurnLiquidity[](ranges.length);

        for (uint256 i = 0; i < ranges.length; i++) {
            uint128 liquidity;
            {
                (liquidity, , , , ) = IUniswapV3Pool(
                    vaultV2_.factory().getPool(
                        address(vaultV2_.token0()),
                        address(vaultV2_.token1()),
                        ranges[i].feeTier
                    )
                ).positions(
                        PositionHelper.getPositionId(
                            address(vaultV2_),
                            ranges[i].lowerTick,
                            ranges[i].upperTick
                        )
                    );
            }

            burns[i] = BurnLiquidity({
                liquidity: SafeCast.toUint128(
                    FullMath.mulDiv(liquidity, amountToBurn_, totalSupply)
                ),
                range: ranges[i]
            });
        }
    }

    // solhint-disable-next-line function-max-lines
    function getMintAmounts(
        IVaultV2 vaultV2_,
        uint256 amount0Max_,
        uint256 amount1Max_
    )
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        (uint256 current0, uint256 current1) = helper.totalUnderlying(
            vaultV2_
        );

        uint256 totalSupply = vaultV2_.totalSupply();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = UniswapV3Amounts
                .computeMintAmounts(
                    current0,
                    current1,
                    totalSupply,
                    amount0Max_,
                    amount1Max_
                );
        } else
            (amount0, amount1, mintAmount) = UniswapV3Amounts
                .computeMintAmounts(
                    vaultV2_.init0(),
                    vaultV2_.init1(),
                    1 ether,
                    amount0Max_,
                    amount1Max_
                );
    }

    function getAmountsForLiquidity(
        int24 currentTick_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity_
    ) public pure returns (uint256 amount0, uint256 amount1) {
        return
            LiquidityAmounts.getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(currentTick_),
                TickMath.getSqrtRatioAtTick(lowerTick_),
                TickMath.getSqrtRatioAtTick(upperTick_),
                liquidity_
            );
    }

    // #region view internal functions.

    function _requireWeightUnder100(RangeWeight[] memory rangeWeights_)
        internal
        pure
    {
        uint256 totalWeight;
        for (uint256 i; i < rangeWeights_.length; i++) {
            totalWeight += rangeWeights_[i].weight;
        }

        require(totalWeight <= 10000, "total weight");
    }

    // #endregion view internal functions.
}
