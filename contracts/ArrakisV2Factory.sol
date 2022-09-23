// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IArrakisV2} from "./interfaces/IArrakisV2.sol";
import {IArrakisV2Beacon} from "./interfaces/IArrakisV2Beacon.sol";
import {
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    BeaconProxy,
    ERC1967Upgrade
} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ArrakisV2FactoryStorage} from "./abstract/ArrakisV2FactoryStorage.sol";
import {InitializePayload} from "./structs/SArrakisV2.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {_getTokenOrder, _append} from "./functions/FArrakisV2Factory.sol";

contract ArrakisV2Factory is ArrakisV2FactoryStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(IArrakisV2Beacon arrakisV2Beacon_)
        ArrakisV2FactoryStorage(arrakisV2Beacon_)
    {} // solhint-disable-line no-empty-blocks

    function deployVault(InitializePayload calldata params_, bool isBeacon_)
        external
        returns (address vault)
    {
        vault = _preDeploy(params_, isBeacon_);

        if (!_deployers.contains(msg.sender)) _deployers.add(msg.sender);
        _vaults[msg.sender].add(vault);
        index += 1;
        emit VaultCreated(msg.sender, vault);
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

    /// @notice getDeployers fetches all addresses that have deployed a Vault
    /// @return deployers the list of deployer addresses
    function getDeployers() public view returns (address[] memory) {
        uint256 length = numDeployers();
        address[] memory deployers = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            deployers[i] = _deployers.at(i);
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
            vaults[i] = _vaults[deployer].at(i);
        }

        return vaults;
    }

    // #endregion public external view functions.

    // #region internal functions

    function _preDeploy(InitializePayload calldata params_, bool isBeacon_)
        internal
        returns (address vault)
    {
        (address token0, address token1) = _getTokenOrder(
            params_.token0,
            params_.token1
        );

        string memory name = "Arrakis Vault V2";
        try this.getTokenName(token0, token1) returns (string memory result) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks

        bytes memory data = abi.encodeWithSelector(
            IArrakisV2.initialize.selector,
            name,
            string(abi.encodePacked("RAKIS-V2-", _uint2str(index + 1))),
            params_
        );

        vault = isBeacon_
            ? address(new BeaconProxy(address(arrakisV2Beacon), data))
            : address(
                new TransparentUpgradeableProxy(
                    arrakisV2Beacon.implementation(),
                    address(this),
                    data
                )
            );
    }

    // #endregion internal functions

    // #region internal view functions

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
