// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Range} from "../structs/SArrakisV2.sol";

library Pool {
    function validateTickSpacing(
        IUniswapV3Factory factory_,
        address token0_,
        address token1_,
        Range memory range_
    ) public view returns (bool) {
        int24 spacing = IUniswapV3Pool(
            factory_.getPool(token0_, token1_, range_.feeTier)
        ).tickSpacing();
        return
            range_.lowerTick < range_.upperTick &&
            range_.lowerTick % spacing == 0 &&
            range_.upperTick % spacing == 0;
    }
}
