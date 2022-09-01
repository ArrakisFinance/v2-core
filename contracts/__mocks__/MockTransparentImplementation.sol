// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract MockTransparentImplementation {
    function name() external pure returns (string memory) {
        return "Mock contract";
    }
}
