// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IManagerProxy {
    // ======= EXTERNAL FUNCTIONS =======
    function fundVaultBalance(address vault) external payable;
}
