// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {Range} from "./SVaultV2.sol";

struct Amount {
    Range range;
    uint256 amount;
}
