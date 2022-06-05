// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {InitializeParams} from "../structs/SVaultV2.sol";

interface IVaultV2Factory {
    event PoolCreated(address indexed manager, address indexed vault);

    event UpdatePoolImplementation(
        address previousImplementation,
        address newImplementation
    );

    function deployVault(InitializeParams calldata params_)
        external
        returns (address vault);

    // #region view functions

    function version() external view returns (string memory);

    function poolImplementation() external view returns (address);

    function deployer() external view returns (address);

    function index() external view returns (uint256);

    function numPoolsByDeployer(address deployer_)
        external
        view
        returns (uint256);

    function getPoolsByDeployer(address deployer)
        external
        view
        returns (address[] memory);

    // #endregion view functions
}
