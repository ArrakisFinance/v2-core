// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {InitializeParams} from "../structs/SMultiposition.sol";

interface IVaultV2Storage {
    function initialize(
        string calldata name_,
        InitializeParams calldata params_
    ) external virtual;
}
