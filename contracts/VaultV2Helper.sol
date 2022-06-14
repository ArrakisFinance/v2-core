// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultV2Helper} from "./interfaces/IVaultV2Helper.sol";
import {IVaultV2} from "./interfaces/IVaultV2.sol";
import {Underlying as UnderlyingHelper} from "./libraries/Underlying.sol";
import {UnderlyingPayload, UnderlyingOutput, Range, RangeData} from "./structs/SVaultV2.sol";
import {Amount} from "./structs/SVaultV2Helper.sol";

contract VaultV2Helper is IVaultV2Helper {
    IUniswapV3Factory public immutable factory;

    constructor(IUniswapV3Factory factory_) {
        factory = factory_;
    }

    function totalUnderlyingWithFeesAndLeftOver(IVaultV2 vault_)
        external
        view
        returns (UnderlyingOutput memory underlying)
    {
        UnderlyingPayload memory underlyingPayload = UnderlyingPayload({
            ranges: vault_.rangesArray(),
            factory: vault_.factory(),
            token0: address(vault_.token0()),
            token1: address(vault_.token1()),
            self: address(vault_)
        });

        (
            underlying.amount0,
            underlying.amount1,
            underlying.fee0,
            underlying.fee1
        ) = UnderlyingHelper.totalUnderlyingWithFees(underlyingPayload);

        underlying.leftOver0 = IERC20(underlyingPayload.token0).balanceOf(
            underlyingPayload.self
        );
        underlying.leftOver1 = IERC20(underlyingPayload.token1).balanceOf(
            underlyingPayload.self
        );
    }

    function totalUnderlyingWithFees(IVaultV2 vault_)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        UnderlyingPayload memory underlyingPayload = UnderlyingPayload({
            ranges: vault_.rangesArray(),
            factory: vault_.factory(),
            token0: address(vault_.token0()),
            token1: address(vault_.token1()),
            self: address(vault_)
        });

        (amount0, amount1, fee0, fee1) = UnderlyingHelper
            .totalUnderlyingWithFees(underlyingPayload);
    }

    function totalUnderlying(IVaultV2 vault_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        UnderlyingPayload memory underlyingPayload = UnderlyingPayload({
            ranges: vault_.rangesArray(),
            factory: vault_.factory(),
            token0: address(vault_.token0()),
            token1: address(vault_.token1()),
            self: address(vault_)
        });

        (amount0, amount1, , ) = UnderlyingHelper.totalUnderlyingWithFees(
            underlyingPayload
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
            (uint256 amount0, uint256 amount1) = _getAmountsFromLiquidity(
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

    function _getAmountsFromLiquidity(
        address token0_,
        address token1_,
        Range calldata range_,
        address vaultV2_
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (token0_, token1_) = token0_ < token1_
            ? (token0_, token1_)
            : (token1_, token0_);

        IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(token0_, token1_, range_.feeTier)
        );

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        uint256 fee0;
        uint256 fee1;
        (amount0, amount1, fee0, fee1) = UnderlyingHelper.underlying(
            RangeData({self: vaultV2_, range: range_, pool: pool}),
            sqrtPriceX96
        );

        amount0 += fee0;
        amount1 += fee1;
    }

    // #endregion internal functions
}
