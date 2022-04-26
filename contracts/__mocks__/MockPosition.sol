// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev example of position facet
contract MockPosition {
    //#region Storage struct and pointer

    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant MOCK_PUBLIC_STORAGE_POINTER =
        keccak256("mock.position.public.storage");

    bytes32 public constant VAULT_V2_PUBLIC_STORAGE_POINTER =
        keccak256("vault.v2.public.storage");

    // solhint-disable-next-line ordering
    struct MockPositionPublicStorage {
        uint256 index;
    }

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

    /// @dev not have onlyManager check for mock purpose.
    function setIndex(uint256 index_) external {
        MockPositionPublicStorage storage mockPositionPublicStorage =
            _mockPositionPublicStorage();
        mockPositionPublicStorage.index = index_;
    }

    /// @dev not have onlyManager check for mock purpose.
    function setManagerTreasury(address newManagerTreasury) external {
        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        publicData.managerTreasury = newManagerTreasury;
        emit SetManagerTreasury(newManagerTreasury);
    }

    function _mockPositionPublicStorage()
        internal
        pure
        returns (MockPositionPublicStorage storage s)
    {
        bytes32 pointer = MOCK_PUBLIC_STORAGE_POINTER;
        assembly {
            s.slot := pointer
        }
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
}
