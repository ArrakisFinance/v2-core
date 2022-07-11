// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {RangeWeight} from "./SVaultV2.sol";
import {IVaultV2} from "./../interfaces/IVaultV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct RebalanceWithSwap {
    RangeWeight[] rangeWeights;
    IVaultV2 vaultV2;
    IUniswapV3Pool pool;
    uint256 swapRatio;
    bool zeroForOne;
}
