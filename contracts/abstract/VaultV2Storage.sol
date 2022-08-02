// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManagerProxyV2} from "../interfaces/IManagerProxyV2.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pool} from "../libraries/Pool.sol";
import {Range, InitializePayload} from "../structs/SVaultV2.sol";

// solhint-disable-next-line max-states-count
abstract contract VaultV2Storage is
    OwnableUninitialized,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // solhint-disable-next-line const-name-snakecase
    string public constant version = "1.0.0";
    // solhint-disable-next-line const-name-snakecase
    uint16 public constant arrakisFeeBPS = 250;

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

    // #endregion manager data

    // #region Twap

    int24 public maxTwapDeviation;
    uint24 public twapDuration;

    uint24 public maxSlippage;

    // #endregion Twap

    EnumerableSet.AddressSet internal _operators;
    EnumerableSet.AddressSet internal _pools;

    modifier onlyManager() {
        require(
           address(manager) == msg.sender
            , "no manager");
        _;
    }

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
        require(params_.feeTiers.length > 0, "no fee tier");
        require(params_.token0 != address(0), "token0");
        require(params_.token1 != address(0), "token1");
        require(params_.operators.length > 0, "no operators");

        require(params_.init0 > 0, "init0");
        require(params_.init1 > 0, "init1");

        require(params_.maxSlippage > 0, "max slippage 0");

        require(params_.manager != address(0), "no Address Zero Manager");

        require(params_.maxTwapDeviation > 0, "maxTwapDeviation");
        require(params_.twapDuration > 0, "maxTwapDeviation");

        __ERC20_init(name_, symbol_);
        __ReentrancyGuard_init();

        for (uint256 i = 0; i < params_.feeTiers.length; i++) {
            address pool = factory.getPool(
                params_.token0,
                params_.token1,
                params_.feeTiers[i]
            );
            require(pool != address(0), "pool does not exist");
            require(!_pools.contains(pool), "pool");
            _pools.add(pool);
        }

        token0 = IERC20(params_.token0);
        token1 = IERC20(params_.token1);

        _owner = params_.owner;

        _addOperators(params_.operators);

        init0 = params_.init0;
        init1 = params_.init1;

        manager = IManagerProxyV2(params_.manager);
        maxTwapDeviation = params_.maxTwapDeviation;
        twapDuration = params_.twapDuration;
        maxSlippage = params_.maxSlippage;
    }

    // #region setter functions

    function addOperators(address[] calldata operators_) external onlyOwner {
        _addOperators(operators_);
    }

    function removeOperators(address[] calldata operators_) external onlyOwner {
        for (uint256 i = 0; i < operators_.length; i++) {
            require(operators_[i] != address(0), "address Zero");
            require(_operators.contains(operators_[i]), "not an operator");

            _operators.remove(operators_[i]);
        }
    }

    function addPools(address[] calldata pools_) external onlyOwner {
        _addPools(pools_);
    }

    function removePools(address[] calldata pools_) external onlyOwner {
        for (uint256 i = 0; i < pools_.length; i++) {
            require(pools_[i] != address(0), "address Zero");
            require(_pools.contains(pools_[i]), "not pool");

            _pools.remove(pools_[i]);
        }
    }

    function setManager(IManagerProxyV2 manager_) external onlyOwner {
        manager = manager_;
    }

    function setMaxTwapDeviation(int24 maxTwapDeviation_) external onlyOwner {
        maxTwapDeviation = maxTwapDeviation_;
    }

    function setTwapDuration(uint24 twapDuration_) external onlyOwner {
        twapDuration = twapDuration_;
    }

    // #endregion setter functions

    // #region view/pure functions

    function rangesLength() external view returns (uint256) {
        return ranges.length;
    }

    function rangesArray() external view returns (Range[] memory) {
        return ranges;
    }

    function rangeExist(Range calldata range_)
        public
        view
        returns (bool ok, uint256 index)
    {
        for (uint256 i = 0; i < ranges.length; i++) {
            ok =
                range_.lowerTick == ranges[i].lowerTick &&
                range_.upperTick == ranges[i].upperTick &&
                range_.feeTier == ranges[i].feeTier;
            index = i;
            if (ok) break;
        }
    }

    // #endregion view/pure functions

    // #region internal functions

    function _addOperators(
        address[] calldata operators_
    ) internal {
        for (uint256 i = 0; i < operators_.length; i++) {
            require(operators_[i] != address(0), "address Zero");
            require(!_operators.contains(operators_[i]), "operator");

            _operators.add(operators_[i]);
        }
    }

    function _addPools(address[] calldata pools_) internal {
        for (uint256 i = 0; i < pools_.length; i++) {
            // explicit
            require(pools_[i] != address(0), "address Zero");
            require(!_pools.contains(pools_[i]), "pool");

            _pools.add(pools_[i]);
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
            require(
                pool != address(0),
                "uniswap pool does not exist"
            );
            require(
                _pools.contains(pool),
                "pool"
            );
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
            require(exist, "not range");

            delete ranges[index];
        }
    }

    // #endregion internal functions
}
