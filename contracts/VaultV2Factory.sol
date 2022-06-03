// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVaultV2Storage} from "./interfaces/IVaultV2Storage.sol";
import {EIP173Proxy} from "./vendor/proxy/EIP173Proxy.sol";
import {IEIP173Proxy} from "./interfaces/IEIP173Proxy.sol";
import {_getTokenOrder, _append} from "./functions/FVaultV2Factory.sol";
import {VaultV2FactoryStorage} from "./abstract/VaultV2FactoryStorage.sol";
import {InitializeParams} from "./structs/SVaultV2.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract VaultV2Factory is VaultV2FactoryStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address uniswapV3Factory_, address poolImplementation_)
        VaultV2FactoryStorage(uniswapV3Factory_, poolImplementation_)
    {} // solhint-disable-line no-empty-blocks

    function deployVault(InitializeParams calldata params_)
        external
        returns (address vault)
    {
        (address pool, string memory name) = _preDeploy(
            params_.token0,
            params_.token1
        );

        IVaultV2Storage(pool).initialize(name, params_);

        _deployers.add(params_.managerTreasury);
        _pools[params_.managerTreasury].add(pool);
        emit PoolCreated(params_.managerTreasury, pool);
    }

    function upgradePools(address[] memory pools) external onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeTo(poolImplementation);
        }
    }

    function upgradePoolsAndCall(address[] memory pools, bytes[] calldata datas)
        external
        onlyOwner
    {
        require(pools.length == datas.length, "mismatching array length");
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).upgradeToAndCall(
                poolImplementation,
                datas[i]
            );
        }
    }

    function makePoolsImmutable(address[] memory pools) external onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            IEIP173Proxy(pools[i]).transferProxyAdmin(address(0));
        }
    }

    function getTokenName(address token0_, address token1_)
        external
        view
        returns (string memory)
    {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return _append("Arrakis Vault V2 ", symbol0, "/", symbol1);
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
        return getPools(deployer);
    }

    /// @notice getDeployers fetches all addresses that have deployed a Vault
    /// @return deployers the list of deployer addresses
    function getDeployers() public view returns (address[] memory) {
        uint256 length = numDeployers();
        address[] memory deployers = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            deployers[i] = _getDeployer(i);
        }

        return deployers;
    }

    /// @notice numPools counts the total number of Harvesters in existence
    /// @return result total number of Harvesters deployed
    function numPools() public view returns (uint256 result) {
        address[] memory deployers = getDeployers();
        for (uint256 i = 0; i < deployers.length; i++) {
            result += numPools(deployers[i]);
        }
    }

    /// @notice numDeployers counts the total number of Vault deployer addresses
    /// @return total number of Vault deployer addresses
    function numDeployers() public view returns (uint256) {
        return _deployers.length();
    }

    /// @notice numPools counts the total number of Harvesters deployed by `deployer`
    /// @param deployer deployer address
    /// @return total number of Harvesters deployed by `deployer`
    function numPools(address deployer) public view returns (uint256) {
        return _pools[deployer].length();
    }

    /// @notice getPools fetches all the Vault addresses deployed by `deployer`
    /// @param deployer address that has potentially deployed Harvesters (can return empty array)
    /// @return pools the list of Vault addresses deployed by `deployer`
    function getPools(address deployer) public view returns (address[] memory) {
        uint256 length = numPools(deployer);
        address[] memory pools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            pools[i] = _getPool(deployer, i);
        }

        return pools;
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

    function _preDeploy(address tokenA_, address tokenB_)
        internal
        returns (address pool, string memory name)
    {
        (address token0, address token1) = _getTokenOrder(tokenA_, tokenB_);
        pool = address(new EIP173Proxy(poolImplementation, address(this), ""));
        name = "Arrakis Vault V2";
        try this.getTokenName(token0, token1) returns (string memory result) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks
    }

    function _getDeployer(uint256 index) internal view returns (address) {
        return _deployers.at(index);
    }

    function _getPool(address deployer, uint256 index)
        internal
        view
        returns (address)
    {
        return _pools[deployer].at(index);
    }
}
