// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {UnderlyingPayload, Underlying, Range} from "../structs/SVaultV2.sol";
import {Amount} from "../structs/SVaultV2Helper.sol";

interface IVaultV2Helper {
    function totalUnderlyingWithFeesAndLeftOver(
        UnderlyingPayload memory underlyingPayload_
    ) external view returns (Underlying memory underlying);

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
        );

    function totalUnderlying(UnderlyingPayload memory underlyingPayload_)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function token0AndToken1ByRange(
        Range[] calldata ranges_,
        address token0_,
        address token1_,
        address vaultV2_
    )
        external
        view
        returns (Amount[] memory amount0s, Amount[] memory amount1s);

    function getAmountsFromLiquidity(
        address token0_,
        address token1_,
        Range memory range_,
        address vaultV2_
    ) external view returns (uint256 amount0, uint256 amount1);
}
