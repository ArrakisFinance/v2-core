// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Twap} from "../../libraries/Twap.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract TwapMock {
    function getTwap(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (int24)
    {
        return Twap.getTwap(pool_, twapDuration_);
    }

    function getSqrtTwapX96(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint160 sqrtPriceX96)
    {
        return Twap.getSqrtTwapX96(pool_, twapDuration_);
    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96_)
        public
        pure
        returns (uint256 priceX96)
    {
        return Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96_);
    }

    function getPrice0(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint256)
    {
        return Twap.getPrice0(pool_, twapDuration_);
    }

    function getPrice1(IUniswapV3Pool pool_, uint24 twapDuration_)
        public
        view
        returns (uint256)
    {
        return Twap.getPrice1(pool_, twapDuration_);
    }

    function checkDeviation(
        IUniswapV3Pool pool_,
        uint24 twapDuration_,
        int24 maxTwapDeviation_
    ) public view {
        Twap.checkDeviation(pool_, twapDuration_, maxTwapDeviation_);
    }
}
