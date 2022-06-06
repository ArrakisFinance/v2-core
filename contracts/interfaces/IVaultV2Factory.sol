// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {InitializeParams} from "../structs/SVaultV2.sol";

interface IVaultV2Factory {
    event VaultCreated(address indexed manager, address indexed vault);

    event UpdateVaultImplementation(
        address previousImplementation,
        address newImplementation
    );

    function deployVault(InitializeParams calldata params_)
        external
        returns (address vault);

    // #region view functions

    function version() external view returns (string memory);

    function vaultImplementation() external view returns (address);

    function deployer() external view returns (address);

    function index() external view returns (uint256);

    function numVaultsByDeployer(address deployer_)
        external
        view
        returns (uint256);

    function getVaultsByDeployer(address deployer_)
        external
        view
        returns (address[] memory);

    // #endregion view functions
}
