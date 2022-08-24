// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IArrakisV2Factory} from "../interfaces/IArrakisV2Factory.sol";
import {IEIP173Proxy} from "../vendor/proxy/interfaces/IEIP173Proxy.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// solhint-disable-next-line max-states-count
abstract contract ArrakisV2FactoryStorage is
    IArrakisV2Factory,
    OwnableUninitialized, /* XXXX DONT MODIFY ORDERING XXXX */
    Initializable
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    using EnumerableSet for EnumerableSet.AddressSet;

    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";

    address public vaultImplementation;
    address public deployer;
    uint256 public index;

    EnumerableSet.AddressSet internal _deployers;
    mapping(address => EnumerableSet.AddressSet) internal _vaults;

    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    // #region constructor.

    constructor() {
        deployer = msg.sender;
        _deployers.add(msg.sender);
    }

    // #endregion constructor.

    function initialize(address implementation_, address _owner_)
        external
        initializer
    {
        vaultImplementation = implementation_;
        _owner = _owner_;

        emit InitFactory(vaultImplementation);
    }

    // #region admin set functions

    function setVaultImplementation(address nextImplementation_)
        external
        onlyOwner
    {
        vaultImplementation = nextImplementation_;
        emit UpdateVaultImplementation(
            vaultImplementation,
            nextImplementation_
        );
    }

    function upgradeVaults(address[] memory vaults_) external onlyOwner {
        for (uint256 i = 0; i < vaults_.length; i++) {
            IEIP173Proxy(vaults_[i]).upgradeTo(vaultImplementation);
        }
    }

    function upgradeVaultsAndCall(
        address[] memory vaults_,
        bytes[] calldata datas_
    ) external onlyOwner {
        require(vaults_.length == datas_.length, "mismatching array length");
        for (uint256 i = 0; i < vaults_.length; i++) {
            IEIP173Proxy(vaults_[i]).upgradeToAndCall(
                vaultImplementation,
                datas_[i]
            );
        }
    }

    function makeVaultsImmutable(address[] memory vaults_) external onlyOwner {
        for (uint256 i = 0; i < vaults_.length; i++) {
            IEIP173Proxy(vaults_[i]).transferProxyAdmin(address(0));
        }
    }

    // #endregion admin set functions
}
