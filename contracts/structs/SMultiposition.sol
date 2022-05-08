// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

struct Position {
    uint128 liquidity;
    int24 lowerTick;
    int24 upperTick;
}

struct Range {
    int24 lowerTick;
    int24 upperTick;
}