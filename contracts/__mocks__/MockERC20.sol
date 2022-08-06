// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
    constructor() {
        __ERC20_init("", "TOKEN");
        _mint(msg.sender, 100000e18);
    }
}
