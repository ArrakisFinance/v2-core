// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVaultV2} from "./IVaultV2.sol";
import {UnderlyingPayload, UnderlyingOutput, Range} from "../structs/SVaultV2.sol";
import {Amount} from "../structs/SVaultV2Helper.sol";

interface IVaultV2Helper {
    function totalUnderlyingWithFeesAndLeftOver(IVaultV2 vault_)
        external
        view
        returns (UnderlyingOutput memory underlying);

    function totalUnderlyingWithFees(IVaultV2 vault_)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        );

    function totalUnderlying(IVaultV2 vault_)
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
}
