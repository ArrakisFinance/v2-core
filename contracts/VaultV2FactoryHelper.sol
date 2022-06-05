// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IEIP173Proxy} from "./interfaces/IEIP173Proxy.sol";
import {IVaultV2Factory} from "./interfaces/IVaultV2Factory.sol";

contract VaultV2FactoryHelper {
    IVaultV2Factory public immutable vaultV2Factory;

    constructor(IVaultV2Factory vaultV2Factory_) {
        vaultV2Factory = vaultV2Factory_;
    }

    /// @notice isPoolImmutable checks if a certain Vault is "immutable" i.e. that the
    /// proxyAdmin is the zero address and thus the underlying implementation cannot be upgraded
    /// @param pool address of the Vault
    /// @return bool signaling if pool is immutable (true) or not (false)
    function isPoolImmutable(address pool) external view returns (bool) {
        return address(0) == getProxyAdmin(pool);
    }

    /// @notice getGelatoPools gets all the Harvesters deployed by Gelato's
    /// default deployer address (since anyone can deploy and manage Harvesters)
    /// @return list of Gelato managed Vault addresses
    function getGelatoPools() external view returns (address[] memory) {
        return getPools(vaultV2Factory.deployer());
    }

    /// @notice getProxyAdmin gets the current address who controls the underlying implementation
    /// of a Vault. For most all pools either this contract address or the zero address will
    /// be the proxyAdmin. If the admin is the zero address the pool's implementation is naturally
    /// no longer upgradable (no one owns the zero address).
    /// @param pool address of the Vault
    /// @return address that controls the Vault implementation (has power to upgrade it)
    function getProxyAdmin(address pool) public view returns (address) {
        return IEIP173Proxy(pool).proxyAdmin();
    }

    /// @notice getPools fetches all the Vault addresses deployed by `deployer`
    /// @param deployer address that has potentially deployed Harvesters (can return empty array)
    /// @return pools the list of Vault addresses deployed by `deployer`
    function getPools(address deployer) public view returns (address[] memory) {
        uint256 length = vaultV2Factory.numPoolsByDeployer(deployer);
        address[] memory pools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            pools[i] = vaultV2Factory.getPoolsByDeployer(deployer)[i];
        }

        return pools;
    }
}
