// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {RangeWeight} from "./SArrakisV2.sol";
import {IArrakisV2} from "./../interfaces/IArrakisV2.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct RebalanceWithSwap {
    RangeWeight[] rangeWeights;
    IArrakisV2 vaultV2;
    IUniswapV3Pool pool;
    uint256 swapRatio;
    bool zeroForOne;
}
