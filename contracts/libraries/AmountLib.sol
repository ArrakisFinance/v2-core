// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {Amount} from "../structs/SVaultV2Helper.sol";

library AmountLib {
    function getMaxAmount(Amount[] memory amounts_)
        public
        pure
        returns (Amount memory amount)
    {
        for (uint256 i; i < amounts_.length; i++) {
            if (amounts_[i].amount > amount.amount) {
                amount = amounts_[i];
            }
        }
    }
}
