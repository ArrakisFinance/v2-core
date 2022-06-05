// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Underlying as UnderlyingHelper} from "./libraries/Underlying.sol";
import {UnderlyingPayload, Underlying, Range, RangeData} from "./structs/SVaultV2.sol";
import {Amount} from "./structs/SVaultV2Helper.sol";

contract VaultV2Helper {
    IUniswapV3Factory public immutable factory;

    constructor(IUniswapV3Factory factory_) {
        factory = factory_;
    }

    function totalUnderlyingWithFeesAndLeftOver(
        UnderlyingPayload memory underlyingPayload_
    ) external view returns (Underlying memory underlying) {
        (
            underlying.amount0,
            underlying.amount1,
            underlying.fee0,
            underlying.fee1
        ) = UnderlyingHelper.totalUnderlyingWithFees(underlyingPayload_);

        underlying.leftOver0 = IERC20(underlyingPayload_.token0).balanceOf(
            underlyingPayload_.self
        );
        underlying.leftOver1 = IERC20(underlyingPayload_.token1).balanceOf(
            underlyingPayload_.self
        );
    }

    function totalUnderlyingWithFees(
        UnderlyingPayload memory underlyingPayload_
    )
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        (amount0, amount1, fee0, fee1) = UnderlyingHelper
            .totalUnderlyingWithFees(underlyingPayload_);
    }

    function totalUnderlying(UnderlyingPayload memory underlyingPayload_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1, , ) = UnderlyingHelper.totalUnderlyingWithFees(
            underlyingPayload_
        );
    }

    // #region Rebalance helper functions

    function token0AndToken1ByRange(
        Range[] calldata ranges_,
        address token0_,
        address token1_,
        address vaultV2_
    )
        external
        view
        returns (Amount[] memory amount0s, Amount[] memory amount1s)
    {
        for (uint256 i = 0; i < ranges_.length; i++) {
            (uint256 amount0, uint256 amount1) = getAmountsFromLiquidity(
                token0_,
                token1_,
                ranges_[i],
                vaultV2_
            );

            amount0s[i] = Amount({range: ranges_[i], amount: amount0});
            amount1s[i] = Amount({range: ranges_[i], amount: amount1});
        }
    }

    // #endregion Rebalance helper functions

    // #region internal functions

    function getAmountsFromLiquidity(
        address token0_,
        address token1_,
        Range memory range_,
        address vaultV2_
    ) public view returns (uint256 amount0, uint256 amount1) {
        (token0_, token1_) = token0_ < token1_
            ? (token0_, token1_)
            : (token1_, token0_);

        IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(token0_, token1_, range_.feeTier)
        );

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        (amount0, amount1, , ) = UnderlyingHelper.underlying(
            RangeData({self: vaultV2_, range: range_, pool: pool}),
            sqrtPriceX96
        );

        amount0 += IERC20(token0_).balanceOf(vaultV2_);
        amount1 += IERC20(token1_).balanceOf(vaultV2_);
    }

    // #endregion internal functions
}
