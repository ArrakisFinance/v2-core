// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    ITransparentUpgradeableProxy
} from "./interfaces/ITransparentUpgradeableProxy.sol";
import {IArrakisV2Factory} from "./interfaces/IArrakisV2Factory.sol";

contract ArrakisV2FactoryHelper {
    IArrakisV2Factory public immutable vaultV2Factory;

    constructor(IArrakisV2Factory vaultV2Factory_) {
        vaultV2Factory = vaultV2Factory_;
    }

    /// @notice getGelatoVaults gets all the Harvesters deployed by Gelato's
    /// default deployer address (since anyone can deploy and manage Harvesters)
    /// @return list of Gelato managed Vault addresses
    function getGelatoVaults() external view returns (address[] memory) {
        return getVaults(vaultV2Factory.deployer());
    }

    /// @notice getProxyAdmin gets the current address who controls the underlying implementation
    /// of a Vault. For most all vaults either this contract address or the zero address will
    /// be the proxyAdmin. If the admin is the zero address the vault's implementation is naturally
    /// no longer upgradable (no one owns the zero address).
    /// @param vault_ address of the Vault
    /// @return address that controls the Vault implementation (has power to upgrade it)
    function getProxyAdmin(address vault_) public view returns (address) {
        return vaultV2Factory.getProxyAdmin(vault_);
    }

    /// @notice getVaults fetches all the Vault addresses deployed by `deployer`
    /// @param deployer_ address that has potentially deployed Harvesters (can return empty array)
    /// @return vaults the list of Vault addresses deployed by `deployer`
    function getVaults(address deployer_)
        public
        view
        returns (address[] memory vaults)
    {
        uint256 length = vaultV2Factory.numVaultsByDeployer(deployer_);
        vaults = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            vaults[i] = vaultV2Factory.getVaultsByDeployer(deployer_)[i];
        }
    }
}