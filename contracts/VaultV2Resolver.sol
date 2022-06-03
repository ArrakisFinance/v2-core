// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IVaultV2Storage} from "./interfaces/IVaultV2Storage.sol";
import {IVaultV2Helper} from "./interfaces/IVaultV2Helper.sol";
import {Underlying as UnderlyingHelper} from "./libraries/Underlying.sol";
import {UniswapV3Amounts} from "./libraries/UniswapV3Amounts.sol";
import {Position as PositionHelper} from "./libraries/Position.sol";
import {FullMath} from "./vendor/uniswap/FullMath.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {LiquidityAmounts} from "./vendor/uniswap/LiquidityAmounts.sol";
import {
    Burn,
    Position,
    Underlying,
    UnderlyingPayload,
    Range,
    RangeWeight,
    RebalanceParams
} from "./structs/SVaultV2.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract VaultV2Resolver {
    IUniswapV3Factory public immutable factory;
    IVaultV2Helper public immutable helper;

    constructor(IUniswapV3Factory factory_, IVaultV2Helper helper_) {
        factory = factory_;
        helper = helper_;
    }

    // no swapping. Standard rebalance.
    // solhint-disable-next-line function-max-lines
    function standardRebalanceParams(
        RangeWeight[] memory rangeWeights_,
        address vaultV2_
    ) external view returns (RebalanceParams memory rebalanceParams) {
        IVaultV2Storage vault = IVaultV2Storage(vaultV2_);

        uint256 amount0;
        uint256 amount1;
        address token0Addr;
        address token1Addr;
        {
            Range[] memory ranges = vault.rangesArray();

            token0Addr = address(vault.token0());
            token1Addr = address(vault.token1());

            (amount0, amount1) = helper.totalUnderlying(
                UnderlyingPayload({
                    ranges: ranges,
                    factory: factory,
                    token0: token0Addr,
                    token1: token1Addr,
                    self: vaultV2_
                })
            );

            for (uint256 i = 0; i < ranges.length; i++) {
                uint128 liquidity;
                {
                    (liquidity, , , , ) = IUniswapV3Pool(
                        vault.factory().getPool(
                            token0Addr,
                            token1Addr,
                            ranges[i].feeTier
                        )
                    ).positions(
                            PositionHelper.getPositionId(
                                vaultV2_,
                                ranges[i].lowerTick,
                                ranges[i].upperTick
                            )
                        );
                }

                if (liquidity > 0)
                    rebalanceParams.removes[i] = Position({
                        liquidity: liquidity,
                        range: ranges[i]
                    });
            }
        }

        // TODO check if sum of weight is < 10000

        requireWeightUnder100(rangeWeights_);

        rebalanceParams.deposits = new Position[](rangeWeights_.length);

        for (uint256 i = 0; i < rangeWeights_.length; i++) {
            RangeWeight memory rangeWeight = rangeWeights_[i];
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(
                vault.factory().getPool(
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

            rebalanceParams.deposits[i] = Position({
                liquidity: liquidity,
                range: rangeWeight.range
            });
        }
    }

    // solhint-disable-next-line function-max-lines
    function standardBurnParams(uint256 amountToBurn_, address vaultV2_)
        external
        view
        returns (Burn[] memory burns)
    {
        IVaultV2Storage vault = IVaultV2Storage(vaultV2_);
        uint256 totalSupply = vault.totalSupply();

        Range[] memory ranges = vault.rangesArray();

        {
            Underlying memory underlying;
            (
                underlying.amount0,
                underlying.amount1,
                underlying.fee0,
                underlying.fee1
            ) = UnderlyingHelper.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: ranges,
                    factory: factory,
                    token0: address(vault.token0()),
                    token1: address(vault.token1()),
                    self: vaultV2_
                })
            );
            underlying.leftOver0 = vault.token0().balanceOf(vaultV2_);
            underlying.leftOver1 = vault.token1().balanceOf(vaultV2_);

            // #region get amount to burn.

            require(totalSupply > 0, "total supply");

            {
                (uint256 fee0, uint256 fee1) = UniswapV3Amounts
                    .subtractAdminFees(
                        underlying.fee0,
                        underlying.fee1,
                        vault.managerFeeBPS()
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

        burns = new Burn[](ranges.length);

        for (uint256 i = 0; i < ranges.length; i++) {
            uint128 liquidity;
            {
                (liquidity, , , , ) = IUniswapV3Pool(
                    vault.factory().getPool(
                        address(vault.token0()),
                        address(vault.token1()),
                        ranges[i].feeTier
                    )
                ).positions(
                        PositionHelper.getPositionId(
                            vaultV2_,
                            ranges[i].lowerTick,
                            ranges[i].upperTick
                        )
                    );
            }

            burns[i] = Burn({
                liquidity: SafeCast.toUint128(
                    FullMath.mulDiv(liquidity, amountToBurn_, totalSupply)
                ),
                range: ranges[i]
            });
        }
    }

    // solhint-disable-next-line function-max-lines
    function getMintAmounts(
        address vaultV2_,
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
        IVaultV2Storage vault = IVaultV2Storage(vaultV2_);
        (uint256 current0, uint256 current1) = helper.totalUnderlying(
            UnderlyingPayload({
                ranges: vault.rangesArray(),
                factory: vault.factory(),
                token0: address(vault.token0()),
                token1: address(vault.token1()),
                self: vaultV2_
            })
        );
        uint256 totalSupply = vault.totalSupply();
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
                    vault.init0(),
                    vault.init1(),
                    1 ether,
                    amount0Max_,
                    amount1Max_
                );
    }

    function getRangeIndexesForAmount(
        uint256 amount_,
        uint256[] memory amounts_
    ) external pure returns (uint256[] memory indexes) {
        uint256 amount = 0;
        uint256 i = 0;
        while (amount < amount_) {
            (uint256 max, uint256 index) = getMax(amounts_);

            delete amounts_[index];
            indexes[i] = max;
            i++;
        }
    }

    function requireWeightUnder100(RangeWeight[] memory rangeWeights_)
        public
        pure
    {
        uint256 totalWeight;
        for (uint256 i; i < rangeWeights_.length; i++) {
            totalWeight += rangeWeights_[i].weight;
        }

        require(totalWeight <= 10000, "total weight");
    }

    function getAmountsForLiquidity(
        int24 currentTick_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        return
            LiquidityAmounts.getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(currentTick_),
                TickMath.getSqrtRatioAtTick(lowerTick_),
                TickMath.getSqrtRatioAtTick(upperTick_),
                liquidity
            );
    }

    function getMax(uint256[] memory amounts_)
        public
        pure
        returns (uint256 max, uint256 index)
    {
        for (uint256 i = 0; i < amounts_.length; i++) {
            if (amounts_[i] > max) {
                max = amounts_[i];
                index = i;
            }
        }
    }
}
