// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IManager} from "../interfaces/IManager.sol";
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
import {Range, Rebalance, InitializePayload} from "../structs/SArrakisV2.sol";

// solhint-disable-next-line max-states-count
abstract contract ArrakisV2Storage is
    OwnableUpgradeable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IUniswapV3Factory public immutable factory;

    IERC20 public token0;
    IERC20 public token1;

    uint256 public init0;
    uint256 public init1;

    Range[] public ranges;

    // #region manager data

    uint16 public managerFeeBPS;
    uint256 public managerBalance0;
    uint256 public managerBalance1;
    address public manager;
    address public restrictedMint;

    // #endregion manager data

    EnumerableSet.AddressSet internal _pools;
    EnumerableSet.AddressSet internal _routers;

    // #region burn buffer

    uint16 internal _burnBuffer;

    // #endregion burn buffer

    // #region events

    event LogMint(
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In
    );

    event LogBurn(
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out
    );

    event LPBurned(address user, uint256 burnAmount0, uint256 burnAmount1);

    event LogRebalance(Rebalance rebalanceParams);

    event LogCollectedFees(uint256 fee0, uint256 fee1);
    event LogUncollectedFees(uint256 fee0, uint256 fee1);

    event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
    event LogWithdrawArrakisBalance(uint256 amount0, uint256 amount1);

    // #region Setting events

    event LogSetInits(uint256 init0, uint256 init1);
    event LogAddPools(uint24[] feeTiers);
    event LogRemovePools(address[] pools);
    event LogSetManager(address newManager);
    event LogSetManagerFeeBPS(uint16 managerFeeBPS);
    event LogRestrictedMint(address minter);
    event LogWhitelistRouters(address[] routers);
    event LogBlacklistRouters(address[] routers);
    event LogSetBurnBuffer(uint16 newBurnBuffer);
    // #endregion Setting events

    // #endregion events

    // #region modifiers

    modifier onlyManager() {
        require(manager == msg.sender, "NM");
        _;
    }

    // #endregion modifiers

    constructor(IUniswapV3Factory factory_) {
        require(address(factory_) != address(0), "ZF");
        factory = factory_;
    }

    // solhint-disable-next-line function-max-lines
    function initialize(
        string calldata name_,
        string calldata symbol_,
        InitializePayload calldata params_
    ) external initializer {
        require(params_.feeTiers.length > 0, "NFT");
        require(params_.token0 != address(0), "T0");
        require(params_.token0 < params_.token1, "WTO");

        require(params_.init0 > 0 || params_.init1 > 0, "I");

        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();

        _addPools(params_.feeTiers, params_.token0, params_.token1);
        _whitelistRouters(params_.routers);

        token0 = IERC20(params_.token0);
        token1 = IERC20(params_.token1);

        _transferOwnership(params_.owner);

        manager = params_.manager;

        _burnBuffer = params_.burnBuffer;

        emit LogAddPools(params_.feeTiers);
        emit LogSetInits(init0 = params_.init0, init1 = params_.init1);
        emit LogSetManager(params_.manager);
        emit LogSetBurnBuffer(params_.burnBuffer);
    }

    // #region setter functions
    function setInits(uint256 init0_, uint256 init1_) external {
        require(init0_ > 0 || init1_ > 0, "I");
        require(totalSupply() == 0, "TS");
        address requiredCaller = restrictedMint == address(0)
            ? owner()
            : restrictedMint;
        require(msg.sender == requiredCaller, "R");
        emit LogSetInits(init0 = init0_, init1 = init1_);
    }

    function addPools(uint24[] calldata feeTiers_) external onlyOwner {
        _addPools(feeTiers_, address(token0), address(token1));
        emit LogAddPools(feeTiers_);
    }

    function removePools(address[] calldata pools_) external onlyOwner {
        for (uint256 i = 0; i < pools_.length; i++) {
            require(_pools.contains(pools_[i]), "NP");

            _pools.remove(pools_[i]);
        }
        emit LogRemovePools(pools_);
    }

    function whitelistRouters(address[] calldata routers_) external onlyOwner {
        _whitelistRouters(routers_);
        emit LogWhitelistRouters(routers_);
    }

    function blacklistRouters(address[] calldata routers_) external onlyOwner {
        for (uint256 i = 0; i < routers_.length; i++) {
            require(_routers.contains(routers_[i]), "RW");

            _routers.remove(routers_[i]);
        }
        emit LogBlacklistRouters(routers_);
    }

    function setManager(address manager_) external onlyOwner {
        emit LogSetManager(manager = manager_);
    }

    function setManagerFeeBPS(uint16 managerFeeBPS_) external onlyManager {
        emit LogSetManagerFeeBPS(managerFeeBPS = managerFeeBPS_);
    }

    function setRestrictedMint(address minter_) external onlyOwner {
        emit LogRestrictedMint(restrictedMint = minter_);
    }

    function setBurnBuffer(uint16 newBurnBuffer_) external onlyOwner {
        require(newBurnBuffer_ < 5000, "MTMB");
        emit LogSetBurnBuffer(_burnBuffer = newBurnBuffer_);
    }

    // #endregion setter functions

    // #region getter functions

    function getRanges() external view returns (Range[] memory) {
        return ranges;
    }

    // #endregion getter functions

    // #region internal functions

    function _uniswapV3CallBack(uint256 amount0_, uint256 amount1_) internal {
        require(_pools.contains(msg.sender), "CC");

        if (
            amount0_ > 0 &&
            amount0_ <= token0.balanceOf(address(this)) - managerBalance0
        ) token0.safeTransfer(msg.sender, amount0_);
        if (
            amount1_ > 0 &&
            amount1_ <= token1.balanceOf(address(this)) - managerBalance1
        ) token1.safeTransfer(msg.sender, amount1_);
    }

    function _addPools(
        uint24[] calldata feeTiers_,
        address token0Addr_,
        address token1Addr_
    ) internal {
        for (uint256 i = 0; i < feeTiers_.length; i++) {
            address pool = factory.getPool(
                token0Addr_,
                token1Addr_,
                feeTiers_[i]
            );

            require(pool != address(0), "ZA");
            require(!_pools.contains(pool), "P");

            // explicit.
            _pools.add(pool);
        }
    }

    function _whitelistRouters(address[] calldata routers_) internal {
        for (uint256 i = 0; i < routers_.length; i++) {
            require(
                routers_[i] != address(token0) &&
                    routers_[i] != address(token1),
                "RT"
            );
            require(!_routers.contains(routers_[i]), "CR");
            // explicit.
            _routers.add(routers_[i]);
        }
    }

    // #endregion internal functions
}
