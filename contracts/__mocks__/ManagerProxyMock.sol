// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IArrakisV2} from "./../interfaces/IArrakisV2.sol";
import {Rebalance} from "./../structs/SArrakisV2.sol";

contract ManagerProxyMock {
    // solhint-disable-next-line const-name-snakecase
    uint16 public constant managerFeeBPS = 100;

    function rebalance(address vaultV2, Rebalance calldata rebalanceParams_)
        external
    {
        IArrakisV2(vaultV2).rebalance(rebalanceParams_);
    }

    // solhint-disable-next-line no-empty-blocks
    function fundVaultBalance(address vault) external payable {
        // empty
    }

    function setManagerFeeBPS(address vault_, uint16 fees_) external {
        IArrakisV2(vault_).setManagerFeeBPS(fees_);
    }
}
