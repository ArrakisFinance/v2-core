// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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

struct RangeWeight {
    Range range;
    uint256 weight; // should be between 0 and 100%
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

// #region internal Structs

struct ComputeFeesEarned {
    uint256 feeGrowthInsideLast;
    uint256 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
    bool isZero;
    IUniswapV3Pool pool;
}

struct PositionUnderlying {
    bytes32 positionId;
    uint160 sqrtPriceX96;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
    IUniswapV3Pool pool;
}

struct Withdraw {
    uint256 burn0;
    uint256 burn1;
    uint256 fee0;
    uint256 fee1;
}

struct UnderlyingPayload {
    Range[] ranges;
    IUniswapV3Factory factory;
    address token0;
    address token1;
    address self;
}

struct RangeData {
    address self;
    Range range;
    IUniswapV3Pool pool;
}

// #endregion internal Structs
