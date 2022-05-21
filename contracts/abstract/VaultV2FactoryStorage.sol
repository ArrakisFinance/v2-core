// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IVaultV2FactoryStorage} from "../interfaces/IVaultV2FactoryStorage.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// solhint-disable-next-line max-states-count
contract VaultV2FactoryStorage is
    IVaultV2FactoryStorage,
    OwnableUninitialized, /* XXXX DONT MODIFY ORDERING XXXX */
    Initializable
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";
    address public immutable factory;
    address public poolImplementation;
    address public deployer;
    EnumerableSet.AddressSet internal _deployers;
    mapping(address => EnumerableSet.AddressSet) internal _pools;
    // APPPEND ADDITIONAL STATE VARS BELOW:
    uint256 public index;
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    // #region events

    event UpdatePoolImplementation(
        address previousImplementation,
        address newImplementation
    );

    //#endregion events

    constructor(address _uniswapV3Factory) {
        factory = _uniswapV3Factory;
    }

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

    // #endregion admin set functions
}
