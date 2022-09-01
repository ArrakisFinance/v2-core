// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    UpgradeableBeacon
} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract ArrakisV2Beacon is UpgradeableBeacon {
    // solhint-disable-next-line no-empty-blocks
    constructor(address implementation_) UpgradeableBeacon(implementation_) {}
}
