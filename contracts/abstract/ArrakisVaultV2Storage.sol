// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
/// @dev ERC20Upgradable and ReentrancyGaurdUpgradeable include Initialize
// solhint-disable-next-line max-states-count
abstract contract ArrakisVaultV2Storage is
    ERC20Upgradeable, /* XXXX DONT MODIFY ORDERING XXXX */
    ReentrancyGuardUpgradeable,
    OwnableUninitialized
    // APPEND ADDITIONAL BASE WITH STATE VARS BELOW:
    // XXXX DONT MODIFY ORDERING XXXX
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // solhint-disable-next-line const-name-snakecase
    string public constant version = "2.0.0";

    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX
    EnumerableSet.AddressSet internal _strategies;
    EnumerableSet.AddressSet internal _operators;
    EnumerableSet.AddressSet internal _targets;
    IERC20 public token0;
    IERC20 public token1;
    address public managerTreasury;
    // APPPEND ADDITIONAL STATE VARS BELOW:
    // XXXXXXXX DO NOT MODIFY ORDERING XXXXXXXX

    event SetManagerTreasury(address treasury);
    event AddStrategy(address strategy);
    event RemoveStrategy(address strategy);
    event AddOperator(address operator);
    event RemoveOperator(address operator);
    event AddTarget(address target);
    event RemoveTarget(address target);

    /// @notice initialize storage variables on a new G-UNI pool, only called once
    /// @param _name name of Vault (immutable)
    /// @param _symbol symbol of Vault (immutable)
    /// @param _token0 token0 first asset of vault
    /// @param _token1 token1 second asset of vault
    /// @param _manager_ address of manager (ownership can be transferred)
    function initialize(
        string memory _name,
        string memory _symbol,
        address _token0,
        address _token1,
        address _manager_,
        address[] memory _strategies_
    ) external initializer {
        // these variables are immutable after initialization
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        _targets.add(_token0);
        _targets.add(_token1);
        for (uint256 i = 0; i < _strategies_.length; i++) {
            _strategies.add(_strategies_[i]);
        }

        // these variables can be udpated by the manager
        _manager = _manager_;
        managerTreasury = _manager_; // default: treasury is admin

        // e.g. "Gelato Uniswap V3 USDC/DAI LP" and "G-UNI"
        __ERC20_init(_name, _symbol);
        __ReentrancyGuard_init();
    }

    /// @notice setManagerTreasury changes manager treasury address
    /// @param newManagerTreasury address that collects manager fees
    function setManagerTreasury(address newManagerTreasury)
        external
        onlyManager
    {
        managerTreasury = newManagerTreasury;
        emit SetManagerTreasury(managerTreasury);
    }

    function addStrategy(address strategy) external onlyManager {
        _strategies.add(strategy);
        emit AddStrategy(strategy);
    }

    function removeStrategy(address strategy) external onlyManager {
        _strategies.remove(strategy);
        emit RemoveStrategy(strategy);
    }

    function addOperator(address operator) external onlyManager {
        _operators.add(operator);
        emit AddOperator(operator);
    }

    function removeOperator(address operator) external onlyManager {
        _operators.remove(operator);
        emit RemoveOperator(operator);
    }

    function addTarget(address target) external onlyManager {
        _targets.add(target);
        emit AddTarget(target);
    }

    function removeTarget(address target) external onlyManager {
        _targets.remove(target);
        emit RemoveTarget(target);
    }

    function operators() external view returns (address[] memory) {
        uint256 length = _operators.length();
        address[] memory output = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            output[i] = _operators.at(i);
        }

        return output;
    }

    function strategies() external view returns (address[] memory) {
        uint256 length = _strategies.length();
        address[] memory output = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            output[i] = _strategies.at(i);
        }

        return output;
    }
}
