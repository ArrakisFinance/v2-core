// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IEIP173Proxy {
    function transferProxyAdmin(address newAdmin) external;

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes calldata data)
        external
        payable;

    function proxyAdmin() external view returns (address);
}
