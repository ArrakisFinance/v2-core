// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct Position {
    uint128 liquidity;
    Range range;
}

struct Burn {
    uint128 liquidity;
    Range range;
}

struct SwapData {
    bytes payload;
    address router;
    uint256 amountIn;
    uint256 expectedMinReturn;
    bool zeroForOne;
}

struct Range {
    int24 lowerTick;
    int24 upperTick;
    uint24 feeTier;
}

struct RebalanceParams {
    Position[] removes;
    Position[] deposits;
    SwapData swap;
}

struct InitializeParams {
    uint24[] feeTiers;
    address token0;
    address token1;
    address owner;
    address[] operators;
    Range[] ranges;
    uint256 init0;
    uint256 init1;
    address managerTreasury;
    uint16 managerFeeBPS;
    int24 maxTwapDeviation;
    uint24 twapDuration;
    uint24 burnSlippage;
}

struct Underlying {
    uint256 amount0;
    uint256 amount1;
    uint256 fee0;
    uint256 fee1;
    uint256 leftOver0;
    uint256 leftOver1;
}
