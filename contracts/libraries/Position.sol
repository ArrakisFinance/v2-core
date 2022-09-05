// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Range} from "../structs/SArrakisV2.sol";

library Position {
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
                range_.feeTier == currentRanges_[i].feeTier;
            index = i;
            if (ok) break;
        }
    }
}
