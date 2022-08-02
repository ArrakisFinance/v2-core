// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IManagerProxy} from "./IManagerProxy.sol";

interface IManagerProxyV2 is IManagerProxy {
    function managerFeeBPS() external view returns (uint16);
}
