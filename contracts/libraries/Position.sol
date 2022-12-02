// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Range} from "../structs/SArrakisV2.sol";

library Position {
    function requireNotActiveRange(address self_, Range memory range_)
        public
        view
    {
        (uint128 liquidity, , , , ) = range_.pool.positions(
            getPositionId(self_, range_.lowerTick, range_.upperTick)
        );

        require(liquidity == 0, "LNZ");
    }

    function getPositionId(
        address self_,
        int24 lowerTick_,
        int24 upperTick_
    ) public pure returns (bytes32 positionId) {
        return keccak256(abi.encodePacked(self_, lowerTick_, upperTick_));
    }

    function rangeExist(Range[] memory currentRanges_, Range memory range_)
        public
        pure
        returns (bool ok, uint256 index)
    {
        for (uint256 i = 0; i < currentRanges_.length; i++) {
            ok =
                range_.lowerTick == currentRanges_[i].lowerTick &&
                range_.upperTick == currentRanges_[i].upperTick &&
                address(range_.pool) == address(currentRanges_[i].pool);
            index = i;
            if (ok) break;
        }
    }
}
