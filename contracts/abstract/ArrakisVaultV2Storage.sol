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

    //#region Storage struct and pointer

    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant VAULT_V2_INTERNAL_STORAGE_POINTER =
        keccak256("vault.v2.internal.storage");

    bytes32 public constant VAULT_V2_PUBLIC_STORAGE_POINTER =
        keccak256("vault.v2.public.storage");

    // solhint-disable-next-line ordering
    struct VaultV2InternalStorage {
        EnumerableSet.AddressSet _positions;
        EnumerableSet.AddressSet _operators;
        EnumerableSet.AddressSet _targets;
    }

    // solhint-disable-next-line ordering
    struct VaultV2PublicStorage {
        mapping(address => bytes) positionState;
        IERC20 token0;
        IERC20 token1;
        address managerTreasury;
        uint256 managerBalance0;
        uint256 managerBalance1;
    }

    //#endregion Storage struct and pointer

    event SetManagerTreasury(address treasury);
    event AddPosition(address position);
    event RemovePosition(address position);
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
        address[] memory _positions_
    ) external initializer {
        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        // these variables are immutable after initialization
        publicData.token0 = IERC20(_token0);
        publicData.token1 = IERC20(_token1);
        internalData._targets.add(_token0);
        internalData._targets.add(_token1);
        for (uint256 i = 0; i < _positions_.length; i++) {
            internalData._positions.add(_positions_[i]);
        }

        // these variables can be udpated by the manager
        _manager = _manager_;
        publicData.managerTreasury = _manager_; // default: treasury is admin

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
        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        publicData.managerTreasury = newManagerTreasury;
        emit SetManagerTreasury(newManagerTreasury);
    }

    function addPosition(address position, bytes memory initialState)
        external
        onlyManager
    {
        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._positions.add(position);
        publicData.positionState[position] = initialState;
        emit AddPosition(position);
    }

    function removePosition(address position) external onlyManager {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._positions.remove(position);
        emit RemovePosition(position);
    }

    function addOperator(address operator) external onlyManager {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._operators.add(operator);
        emit AddOperator(operator);
    }

    function removeOperator(address operator) external onlyManager {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._operators.remove(operator);
        emit RemoveOperator(operator);
    }

    function addTarget(address target) external onlyManager {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._targets.add(target);
        emit AddTarget(target);
    }

    function removeTarget(address target) external onlyManager {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        internalData._targets.remove(target);
        emit RemoveTarget(target);
    }

    function _vaultV2PublicStorage()
        internal
        pure
        returns (VaultV2PublicStorage storage s)
    {
        bytes32 pointer = VAULT_V2_PUBLIC_STORAGE_POINTER;
        assembly {
            s.slot := pointer
        }
    }

    function _vaultV2InternalStorage()
        internal
        pure
        returns (VaultV2InternalStorage storage s)
    {
        bytes32 pointer = VAULT_V2_INTERNAL_STORAGE_POINTER;
        assembly {
            s.slot := pointer
        }
    }

    function operators() external view returns (address[] memory) {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        uint256 length = internalData._operators.length();
        address[] memory output = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            output[i] = internalData._operators.at(i);
        }

        return output;
    }

    function positions() external view returns (address[] memory) {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        uint256 length = internalData._positions.length();
        address[] memory output = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            output[i] = internalData._positions.at(i);
        }

        return output;
    }
}
