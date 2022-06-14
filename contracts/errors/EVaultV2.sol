// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {BurnLiquidity} from "../structs/SVaultV2.sol";

error LiquidityZeroError(int24 lowerTick, int24 upperTick, uint24 feeTier);
error PoolError(uint24 feeTier);

function _liquidityZeroError(BurnLiquidity memory burn_) pure {
    revert LiquidityZeroError(
        burn_.range.lowerTick,
        burn_.range.upperTick,
        burn_.range.feeTier
    );
}

function _poolError(uint24 feeTier_) pure {
    revert PoolError(feeTier_);
}
