// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

contract MockEIP173Implementation {
    function name() external pure returns (string memory) {
        return "Mock contract";
    }
}
