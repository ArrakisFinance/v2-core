// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IVaultV2} from "./interfaces/IVaultV2.sol";
import {EIP173Proxy} from "./vendor/proxy/EIP173Proxy.sol";
import {VaultV2FactoryStorage} from "./abstract/VaultV2FactoryStorage.sol";
import {InitializePayload} from "./structs/SVaultV2.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {_getTokenOrder, _append} from "./functions/FVaultV2Factory.sol";

contract VaultV2Factory is VaultV2FactoryStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    function deployVault(InitializePayload calldata params_)
        external
        returns (address vault)
    {
        string memory name;
        (vault, name) = _preDeploy(params_.token0, params_.token1);

        IVaultV2(vault).initialize(
            name,
            string(abi.encodePacked("RAKIS-V2-", _uint2str(index + 1))),
            params_
        );

        _deployers.add(params_.managerTreasury);
        _vaults[params_.managerTreasury].add(vault);
        index += 1;
        emit VaultCreated(params_.managerTreasury, vault);
    }

    // #region public external view functions.

    function getTokenName(address token0_, address token1_)
        external
        view
        returns (string memory)
    {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return _append("Arrakis Vault V2 ", symbol0, "/", symbol1);
    }

    /// @notice getDeployerVaults gets all the Harvesters deployed by Arrakis deployer
    /// default deployer address (since anyone can deploy and manage Harvesters)
    /// @return list of deployer's managed Vault addresses
    function getDeployerVaults() external view returns (address[] memory) {
        return getVaultsByDeployer(deployer);
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

    /// @notice numVaults counts the total number of Harvesters in existence
    /// @return result total number of Harvesters deployed
    function numVaults() public view returns (uint256 result) {
        address[] memory deployers = getDeployers();
        for (uint256 i = 0; i < deployers.length; i++) {
            result += numVaultsByDeployer(deployers[i]);
        }
    }

    /// @notice numVaults counts the total number of Harvesters deployed by `deployer`
    /// @param deployer deployer address
    /// @return total number of Harvesters deployed by `deployer`
    function numVaultsByDeployer(address deployer)
        public
        view
        returns (uint256)
    {
        return _vaults[deployer].length();
    }

    /// @notice numDeployers counts the total number of Vault deployer addresses
    /// @return total number of Vault deployer addresses
    function numDeployers() public view returns (uint256) {
        return _deployers.length();
    }

    /// @notice getVaults fetches all the Vault addresses deployed by `deployer`
    /// @param deployer address that has potentially deployed Harvesters (can return empty array)
    /// @return vaults the list of Vault addresses deployed by `deployer`
    function getVaultsByDeployer(address deployer)
        public
        view
        returns (address[] memory)
    {
        uint256 length = numVaultsByDeployer(deployer);
        address[] memory vaults = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            vaults[i] = _getVault(deployer, i);
        }

        return vaults;
    }

    // #endregion public external view functions.

    // #region internal functions

    function _preDeploy(address tokenA_, address tokenB_)
        internal
        returns (address vault, string memory name)
    {
        (address token0, address token1) = _getTokenOrder(tokenA_, tokenB_);
        vault = address(
            new EIP173Proxy(vaultImplementation, address(this), "")
        );
        name = "Arrakis Vault V2";
        try this.getTokenName(token0, token1) returns (string memory result) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks
    }

    // #endregion internal functions

    // #region internal view functions

    function _getDeployer(uint256 index) internal view returns (address) {
        return _deployers.at(index);
    }

    function _getVault(address deployer, uint256 index)
        internal
        view
        returns (address)
    {
        return _vaults[deployer].at(index);
    }

    function _uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // #endregion internal view functions
}
