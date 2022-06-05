// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IVaultV2Factory} from "../interfaces/IVaultV2Factory.sol";
import {IEIP173Proxy} from "../interfaces/IEIP173Proxy.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// solhint-disable-next-line max-states-count
abstract contract VaultV2FactoryStorage is
    IVaultV2Factory,
    OwnableUninitialized, /* XXXX DONT MODIFY ORDERING XXXX */
    Initializable
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    using EnumerableSet for EnumerableSet.AddressSet;

    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";

    address public poolImplementation;
    address public deployer;
    uint256 public index;

    EnumerableSet.AddressSet internal _deployers;
    mapping(address => EnumerableSet.AddressSet) internal _pools;

    // APPPEND ADDITIONAL STATE VARS BELOW:

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    // #region constructor.

    constructor() {
        deployer = msg.sender;
        _deployers.add(msg.sender);
    }

    // #endregion constructor.

    function initialize(address _implementation, address _owner_)
        external
        initializer
    {
        poolImplementation = _implementation;
        _owner = _owner_;
    }

    // #region admin set functions

    function setPoolImplementation(address nextImplementation)
        external
        onlyOwner
    {
        emit UpdatePoolImplementation(poolImplementation, nextImplementation);
        poolImplementation = nextImplementation;
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

    // #endregion admin set functions
}
