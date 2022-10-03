// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TickMath} from "@arrakisfi/v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

library Twap {
    /// @dev Fetches time-weighted average price in ticks from Uniswap pool.
    function getTwap(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (int24)
    {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = twapDuration_;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives, ) = pool_.observe(secondsAgo);
        return
            int24(
                (tickCumulatives[1] - tickCumulatives[0]) /
                    int56(uint56(twapDuration_))
            );
    }

    function getSqrtTwapX96(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint160 sqrtPriceX96)
    {
        if (twapDuration_ == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = pool_.slot0();
        } else {
            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                getTwap(pool_, twapDuration_)
            );
        }
    }

    function getPrice0(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint256 price0)
    {
        ERC20 token0 = ERC20(pool_.token0());

        uint256 priceX96 = getSqrtTwapX96(pool_, twapDuration_);

        price0 = FullMath.mulDiv(
            priceX96 * priceX96,
            10**token0.decimals(),
            2**192
        );
    }

    function getPrice1(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint256 price1)
    {
        ERC20 token1 = ERC20(pool_.token1());

        uint256 priceX96 = getSqrtTwapX96(pool_, twapDuration_);

        price1 = FullMath.mulDiv(
            2**192,
            10**token1.decimals(),
            priceX96 * priceX96
        );
    }

    function checkDeviation(
        IUniswapV3Pool pool_,
        uint24 twapDuration_,
        int24 maxTwapDeviation_
    ) public view {
        (, int24 tick, , , , , ) = pool_.slot0();
        int24 twap = getTwap(pool_, twapDuration_);

        int24 deviation = tick > twap ? tick - twap : twap - tick;
        require(deviation <= maxTwapDeviation_, "maxTwapDeviation");
    }
}
