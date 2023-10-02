// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    ArrakisStorage,
    ArrakisStorageLib
} from "../libraries/ArrakisStorageLib.sol";
import {Invest} from "../libraries/Invest.sol";
import {Range, Rebalance, InitializePayload} from "../structs/SArrakisV2.sol";
import {hundredPercent} from "../constants/CArrakisV2.sol";

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title ArrakisV2Storage base contract containing all ArrakisV2 storage variables.
// solhint-disable-next-line max-states-count
abstract contract ArrakisV2Storage is
    OwnableUpgradeable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region events

    event LogCollectedFees(uint256 fee0, uint256 fee1);

    event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
    // #region Setting events

    event LogSetInits(uint256 init0, uint256 init1);
    event LogAddPools(uint24[] feeTiers);
    event LogRemovePools(address[] pools);
    event LogSetManager(address newManager);
    event LogSetManagerFeeBPS(uint16 managerFeeBPS);
    event LogWhitelistRouters(address[] routers);
    event LogBlacklistRouters(address[] routers);
    // #endregion Setting events

    // #endregion events

    // #region modifiers

    modifier onlyManager() {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();
        require(arrakisStorage.manager == msg.sender, "NM");
        _;
    }

    // #endregion modifiers

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // solhint-disable-next-line function-max-lines
    function initialize(
        string calldata name_,
        string calldata symbol_,
        InitializePayload calldata params_
    ) external initializer {
        require(params_.feeTiers.length > 0, "NFT");
        require(params_.token0 != address(0), "T0");
        require(params_.token0 < params_.token1, "WTO");
        require(params_.owner != address(0), "OAZ");
        require(params_.manager != address(0), "MAZ");
        require(params_.init0 > 0 || params_.init1 > 0, "I");
        require(address(params_.factory) != address(0), "ZF");

        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        arrakisStorage.factory = IUniswapV3Factory(params_.factory);
        _addPools(params_.feeTiers, params_.token0, params_.token1);
        arrakisStorage.token0 = IERC20(params_.token0);
        arrakisStorage.token1 = IERC20(params_.token1);
        _whitelistRouters(params_.routers);
        _transferOwnership(params_.owner);
        arrakisStorage.manager = params_.manager;
        arrakisStorage.init0 = params_.init0;
        arrakisStorage.init1 = params_.init1;

        emit LogAddPools(params_.feeTiers);
        emit LogSetInits(params_.init0, params_.init1);
        emit LogSetManager(params_.manager);
    }

    // #region setter functions

    /// @notice set initial virtual allocation of token0 and token1
    /// @param init0_ initial virtual allocation of token 0.
    /// @param init1_ initial virtual allocation of token 1.
    function setInits(uint256 init0_, uint256 init1_) external onlyOwner {
        require(init0_ > 0 || init1_ > 0, "I");
        require(totalSupply() == 0, "TS");

        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();
        arrakisStorage.init0 = init0_;
        arrakisStorage.init1 = init1_;

        emit LogSetInits(init0_, init1_);
    }

    /// @notice whitelist pools
    /// @param feeTiers_ list of fee tiers associated to pools to whitelist.
    /// @dev only callable by owner.
    function addPools(uint24[] calldata feeTiers_) external onlyOwner {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();
        _addPools(
            feeTiers_,
            address(arrakisStorage.token0),
            address(arrakisStorage.token1)
        );
        emit LogAddPools(feeTiers_);
    }

    /// @notice unwhitelist pools
    /// @param pools_ list of pools to remove from whitelist.
    /// @dev only callable by owner.
    function removePools(address[] calldata pools_) external onlyOwner {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        for (uint256 i = 0; i < pools_.length; i++) {
            require(arrakisStorage.pools.contains(pools_[i]), "NP");

            arrakisStorage.pools.remove(pools_[i]);
        }
        emit LogRemovePools(pools_);
    }

    /// @notice whitelist routers
    /// @param routers_ list of router addresses to whitelist.
    /// @dev only callable by owner.
    function whitelistRouters(address[] calldata routers_) external onlyOwner {
        _whitelistRouters(routers_);
    }

    /// @notice blacklist routers
    /// @param routers_ list of routers addresses to blacklist.
    /// @dev only callable by owner.
    function blacklistRouters(address[] calldata routers_) external onlyOwner {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        for (uint256 i = 0; i < routers_.length; i++) {
            require(arrakisStorage.routers.contains(routers_[i]), "RW");

            arrakisStorage.routers.remove(routers_[i]);
        }
        emit LogBlacklistRouters(routers_);
    }

    /// @notice set manager
    /// @param manager_ manager address.
    /// @dev only callable by owner.
    function setManager(address manager_) external onlyOwner nonReentrant {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        Invest.collectFeesOnPools();
        _withdrawManagerBalance();
        arrakisStorage.manager = manager_;
        emit LogSetManager(manager_);
    }

    /// @notice set manager fee bps
    /// @param managerFeeBPS_ manager fee in basis points.
    /// @dev only callable by manager.
    function setManagerFeeBPS(uint16 managerFeeBPS_)
        external
        onlyManager
        nonReentrant
    {
        require(managerFeeBPS_ <= 10000, "MFO");

        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();
        Invest.collectFeesOnPools();
        arrakisStorage.managerFeeBPS = managerFeeBPS_;
        emit LogSetManagerFeeBPS(managerFeeBPS_);
    }

    // #endregion setter functions

    // #region getter functions

    /// @notice get full list of ranges, guaranteed to contain all active vault LP Positions.
    /// @return ranges list of ranges
    function getRanges() external view returns (Range[] memory) {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        return arrakisStorage.ranges;
    }

    function getPools() external view returns (address[] memory) {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        uint256 len = arrakisStorage.pools.length();
        address[] memory output = new address[](len);
        for (uint256 i; i < len; i++) {
            output[i] = arrakisStorage.pools.at(i);
        }

        return output;
    }

    function getRouters() external view returns (address[] memory) {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        uint256 len = arrakisStorage.routers.length();
        address[] memory output = new address[](len);
        for (uint256 i; i < len; i++) {
            output[i] = arrakisStorage.routers.at(i);
        }

        return output;
    }

    // #endregion getter functions

    // #region internal functions

    function _uniswapV3CallBack(uint256 amount0_, uint256 amount1_) internal {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        require(arrakisStorage.pools.contains(msg.sender), "CC");

        if (amount0_ > 0)
            arrakisStorage.token0.safeTransfer(msg.sender, amount0_);
        if (amount1_ > 0)
            arrakisStorage.token1.safeTransfer(msg.sender, amount1_);
    }

    function _withdrawManagerBalance() internal {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        uint256 amount0 = arrakisStorage.managerBalance0;
        uint256 amount1 = arrakisStorage.managerBalance1;

        arrakisStorage.managerBalance0 = 0;
        arrakisStorage.managerBalance1 = 0;

        /// @dev token can blacklist manager and make this function fail,
        /// so we use try catch to deal with blacklisting.

        if (amount0 > 0) {
            // solhint-disable-next-line no-empty-blocks
            try
                arrakisStorage.token0.transfer(arrakisStorage.manager, amount0)
            {} catch {
                amount0 = 0;
            }
        }

        if (amount1 > 0) {
            // solhint-disable-next-line no-empty-blocks
            try
                arrakisStorage.token1.transfer(arrakisStorage.manager, amount1)
            {} catch {
                amount1 = 0;
            }
        }

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    function _addPools(
        uint24[] calldata feeTiers_,
        address token0Addr_,
        address token1Addr_
    ) internal {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        for (uint256 i = 0; i < feeTiers_.length; i++) {
            address pool = arrakisStorage.factory.getPool(
                token0Addr_,
                token1Addr_,
                feeTiers_[i]
            );

            require(pool != address(0), "ZA");

            require(!arrakisStorage.pools.contains(pool), "P");

            // explicit.
            arrakisStorage.pools.add(pool);
        }
    }

    function _whitelistRouters(address[] calldata routers_) internal {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        for (uint256 i = 0; i < routers_.length; i++) {
            require(
                routers_[i] != address(arrakisStorage.token0) &&
                    routers_[i] != address(arrakisStorage.token1),
                "RT"
            );
            require(!arrakisStorage.routers.contains(routers_[i]), "CR");
            // explicit.
            arrakisStorage.routers.add(routers_[i]);
        }

        emit LogWhitelistRouters(routers_);
    }

    // #endregion internal functions
}
