// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

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
