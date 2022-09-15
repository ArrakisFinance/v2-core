// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IManagerProxyV2} from "../interfaces/IManagerProxyV2.sol";
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
import {Pool} from "../libraries/Pool.sol";
import {Position} from "../libraries/Position.sol";
import {Range, Rebalance, InitializePayload} from "../structs/SArrakisV2.sol";

// solhint-disable-next-line max-states-count
abstract contract ArrakisV2Storage is
    OwnableUpgradeable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";
    // solhint-disable-next-line const-name-snakecase
    uint16 public constant arrakisFeeBPS = 250;
    // above 10000 to safely avoid collisions for repurposed state var
    uint16 internal constant _RESTRICTED_MINT_ENABLED = 11111;

    IUniswapV3Factory public immutable factory;
    address public immutable arrakisTreasury;

    IERC20 public token0;
    IERC20 public token1;

    uint256 public init0;
    uint256 public init1;

    Range[] public ranges;

    // #region arrakis data

    uint256 public arrakisBalance0;
    uint256 public arrakisBalance1;

    // #endregion arrakis data

    // #region manager data

    IManagerProxyV2 public manager;
    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint16 public restrictedMintToggle;

    // #endregion manager data

    // #region Twap

    int24 public maxTwapDeviation;
    uint24 public twapDuration;

    uint24 public maxSlippage;

    // #endregion Twap

    EnumerableSet.AddressSet internal _pools;

    // #region events

    event LogMint(
        address indexed vault,
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In
    );

    event LogBurn(
        address indexed vault,
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out
    );

    event LPBurned(
        address indexed vault,
        address user,
        uint256 burnAmount0,
        uint256 burnAmount1
    );

    event LogRebalance(address indexed vault, Rebalance rebalanceParams);

    event LogFeesEarn(address indexed vault, uint256 fee0, uint256 fee1);
    event LogFeesEarnRebalance(
        address indexed vault,
        uint256 fee0,
        uint256 fee1
    );

    event LogWithdrawManagerBalance(
        address indexed vault,
        uint256 amount0,
        uint256 amount1
    );
    event LogWithdrawArrakisBalance(
        address indexed vault,
        uint256 amount0,
        uint256 amount1
    );

    // #region Setting events

    event LogSetInits(address indexed vault, uint256 init0, uint256 init1);
    event LogAddPools(address indexed vault, uint24[] feeTiers);
    event LogRemovePools(address indexed vault, address[] pools);
    event LogSetManager(
        address indexed vault,
        address oldManager,
        address newManager
    );
    event LogRestrictedMintToggle(
        address indexed vault,
        uint16 restrictedMintToggle
    );
    event LogSetMaxTwapDeviation(
        address indexed vault,
        int24 oldTwapDeviation,
        int24 maxTwapDeviation
    );
    event LogSetTwapDuration(
        address indexed vault,
        uint24 oldTwapDuration,
        uint24 newTwapDuration
    );
    event LogSetMaxSlippage(
        address indexed vault,
        uint24 oldMaxSlippage,
        uint24 newMaxSlippage
    );

    // #endregion Setting events

    // #endregion events

    // #region modifiers

    modifier onlyManager() {
        require(address(manager) == msg.sender, "no manager");
        _;
    }

    // #endregion modifiers

    constructor(IUniswapV3Factory factory_, address arrakisTreasury_) {
        require(address(factory_) != address(0), "factory");
        require(arrakisTreasury_ != address(0), "arrakis treasury");
        factory = factory_;
        arrakisTreasury = arrakisTreasury_;
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

        require(params_.manager != address(0), "NAZM");

        address me = address(this);

        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();

        _addPools(params_.feeTiers, params_.token0, params_.token1);

        token0 = IERC20(params_.token0);
        token1 = IERC20(params_.token1);

        _transferOwnership(params_.owner);

        manager = IManagerProxyV2(params_.manager);

        emit LogAddPools(me, params_.feeTiers);
        emit LogSetInits(me, init0 = params_.init0, init1 = params_.init1);
        emit LogSetManager(me, address(0), params_.manager);
        emit LogSetMaxTwapDeviation(
            me,
            maxTwapDeviation,
            maxTwapDeviation = params_.maxTwapDeviation
        );
        emit LogSetTwapDuration(
            me,
            twapDuration,
            twapDuration = params_.twapDuration
        );
        emit LogSetMaxSlippage(
            me,
            maxSlippage,
            maxSlippage = params_.maxSlippage
        );
    }

    // #region setter functions
    function setInits(uint256 init0_, uint256 init1_) external onlyOwner {
        require(totalSupply() == 0, "total supply");
        emit LogSetInits(address(this), init0 = init0_, init1 = init1_);
    }

    function addPools(uint24[] calldata feeTiers_) external onlyOwner {
        _addPools(feeTiers_, address(token0), address(token1));
        emit LogAddPools(address(this), feeTiers_);
    }

    function removePools(address[] calldata pools_) external onlyOwner {
        for (uint256 i = 0; i < pools_.length; i++) {
            require(pools_[i] != address(0), "address Zero");
            require(_pools.contains(pools_[i]), "not pool");

            _pools.remove(pools_[i]);
        }
        emit LogRemovePools(address(this), pools_);
    }

    function setManager(IManagerProxyV2 manager_) external onlyOwner {
        emit LogSetManager(
            address(this),
            address(manager),
            address(manager = manager_)
        );
    }

    function toggleRestrictMint() external onlyManager {
        emit LogRestrictedMintToggle(
            address(this),
            restrictedMintToggle = restrictedMintToggle ==
                _RESTRICTED_MINT_ENABLED
                ? 0
                : _RESTRICTED_MINT_ENABLED
        );
    }

    function setMaxTwapDeviation(int24 maxTwapDeviation_) external onlyOwner {
        emit LogSetMaxTwapDeviation(
            address(this),
            maxTwapDeviation,
            maxTwapDeviation = maxTwapDeviation_
        );
    }

    function setTwapDuration(uint24 twapDuration_) external onlyOwner {
        emit LogSetTwapDuration(
            address(this),
            twapDuration,
            twapDuration = twapDuration_
        );
    }

    function setMaxSlippage(uint24 maxSlippage_) external onlyOwner {
        emit LogSetMaxSlippage(
            address(this),
            maxSlippage,
            maxSlippage = maxSlippage_
        );
    }

    // #endregion setter functions

    // #region view/pure functions

    function rangeExist(Range calldata range_)
        public
        view
        returns (bool ok, uint256 index)
    {
        return Position.rangeExist(ranges, range_);
    }

    // #endregion view/pure functions

    // #region internal functions

    function _uniswapV3CallBack(uint256 amount0_, uint256 amount1_) internal {
        require(_pools.contains(msg.sender), "callback caller");

        if (
            amount0_ > 0 &&
            amount0_ <=
            token0.balanceOf(address(this)) -
                (managerBalance0 + arrakisBalance0)
        ) token0.safeTransfer(msg.sender, amount0_);
        if (
            amount1_ > 0 &&
            amount1_ <=
            token1.balanceOf(address(this)) -
                (managerBalance1 + arrakisBalance1)
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

            require(pool != address(0), "address Zero");
            require(!_pools.contains(pool), "pool");

            // explicit.
            _pools.add(pool);
        }
    }

    function _addRanges(
        Range[] calldata ranges_,
        address token0Addr_,
        address token1Addr_
    ) internal {
        for (uint256 i = 0; i < ranges_.length; i++) {
            (bool exist, ) = rangeExist(ranges_[i]);
            require(!exist, "range");
            // check that the pool exist on Uniswap V3.
            address pool = factory.getPool(
                token0Addr_,
                token1Addr_,
                ranges_[i].feeTier
            );
            require(pool != address(0), "NUP");
            require(_pools.contains(pool), "P");
            // TODO: can reuse the pool got previously.
            require(
                Pool.validateTickSpacing(
                    factory,
                    token0Addr_,
                    token1Addr_,
                    ranges_[i]
                ),
                "range"
            );

            ranges.push(ranges_[i]);
        }
    }

    function _removeRanges(Range[] calldata ranges_) internal {
        for (uint256 i = 0; i < ranges_.length; i++) {
            (bool exist, uint256 index) = rangeExist(ranges_[i]);
            require(exist, "NR");

            delete ranges[index];

            for (uint256 j = index; j < ranges.length - 1; j++) {
                ranges[j] = ranges[j + 1];
            }
            ranges.pop();
        }
    }

    // #endregion internal functions
}
