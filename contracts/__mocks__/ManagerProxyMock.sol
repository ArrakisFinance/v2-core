// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVaultV2} from "./../interfaces/IVaultV2.sol";
import {Range, Rebalance} from "./../structs/SVaultV2.sol";

contract ManagerProxyMock {
    uint16 public constant managerFeeBPS = 100;

    function rebalance(
        address vaultV2,
        Range[] calldata rangesToAdd_,
        Rebalance calldata rebalanceParams_,
        Range[] calldata rangesToRemove_
    ) external {
        IVaultV2(vaultV2).rebalance(
            rangesToAdd_,
            rebalanceParams_,
            rangesToRemove_
        );
    }
}
