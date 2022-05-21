// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {Burn} from "../structs/SMultiposition.sol";

error LiquidityZeroError(int24 lowerTick, int24 upperTick, uint24 feeTier);
error PoolError(uint24 feeTier);

function _liquidityZeroError(Burn memory burn_) view {
    revert LiquidityZeroError(
        burn_.range.lowerTick,
        burn_.range.upperTick,
        burn_.range.feeTier
    );
}

function _poolError(uint24 feeTier_) view {
    revert PoolError(feeTier_);
}
