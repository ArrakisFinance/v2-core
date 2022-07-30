// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IManagerProxy {
    function managerFeeBPS() external view returns (uint16);
}
