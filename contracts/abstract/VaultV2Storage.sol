// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IVaultV2Storage} from "../interfaces/IVaultV2Storage.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {_validateTickSpacing} from "../functions/FVaultV2.sol";
import {Range, InitializeParams} from "../structs/SMultiposition.sol";

// solhint-disable-next-line max-states-count
abstract contract VaultV2Storage is
    IVaultV2Storage,
    OwnableUninitialized,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IUniswapV3Factory public immutable factory;

    IERC20 public token0;
    IERC20 public token1;

    EnumerableSet.AddressSet internal _operators;
    EnumerableSet.AddressSet internal _pools;

    uint256 internal _init0;
    uint256 internal _init1;

    Range[] public ranges;

    address public managerTreasury;
    uint16 public managerFeeBPS;
    uint256 public managerBalance0;
    uint256 public managerBalance1;

    int24 public maxTwapDeviation;
    uint24 public twapDuration;

    uint24 public burnSlippage;

    // #region modifiers

    modifier onlyOperators() {
        require(_operators.contains(msg.sender), "no operators");
        _;
    }

    // #endregion modifiers

    constructor(IUniswapV3Factory factory_) {
        require(address(factory_) != address(0), "factory");
        factory = factory_;
    }

    function initialize(
        string calldata name_,
        InitializeParams calldata params_
    ) external initializer {
        require(params_.feeTiers.length > 0, "no fee tier");
        require(params_.token0 != address(0), "token0");
        require(params_.token1 != address(0), "token1");

        __ERC20_init(name_, "ARK-T");

        _owner = params_.owner;

        token0 = IERC20(params_.token0);
        token1 = IERC20(params_.token1);

        for (uint256 i = 0; i < params_.operators.length; i++) {
            _operators.add(params_.operators[i]);
        }

        for (uint256 i = 0; i < params_.feeTiers.length; i++) {
            address pool =
                factory.getPool(
                    params_.token0,
                    params_.token1,
                    params_.feeTiers[i]
                );
            require(pool != address(0), "pool does not exist");
            _pools.add(pool);
        }

        for (uint256 i = 0; i < params_.ranges.length; i++) {
            ranges[i] = params_.ranges[i];
        }

        _init0 = params_.init0;
        _init1 = params_.init1;

        managerTreasury = params_.managerTreasury;
        managerFeeBPS = params_.managerFeeBPS;
        maxTwapDeviation = params_.maxTwapDeviation;
        twapDuration = params_.twapDuration;
        burnSlippage = params_.burnSlippage;
    }

    // #region setter functions

    function addOperators(address[] memory operators_) external onlyOwner {
        for (uint256 i = 0; i < operators_.length; i++) {
            require(!_operators.contains(operators_[i]), "operator");

            _operators.add(operators_[i]);
        }
    }

    function removeOperators(address[] memory operators_) external onlyOwner {
        for (uint256 i = 0; i < operators_.length; i++) {
            require(_operators.contains(operators_[i]), "not operator");

            _operators.remove(operators_[i]);
        }
    }

    function addPools(address[] memory pools_) external onlyOwner {
        for (uint256 i = 0; i < pools_.length; i++) {
            require(!_pools.contains(pools_[i]), "pool");

            _pools.add(pools_[i]);
        }
    }

    function removePools(address[] memory pools_) external onlyOwner {
        for (uint256 i = 0; i < pools_.length; i++) {
            require(_pools.contains(pools_[i]), "not pool");

            _pools.remove(pools_[i]);
        }
    }

    function addRanges(Range[] memory ranges_) external onlyOwner {
        address token0Addr = address(token0);
        address token1Addr = address(token1);
        for (uint256 i = 0; i < ranges_.length; i++) {
            (bool exist, ) = rangeExist(ranges_[i]);
            require(!exist, "range");
            require(
                _validateTickSpacing(
                    factory,
                    token0Addr,
                    token1Addr,
                    ranges_[i]
                ),
                "range"
            );

            ranges.push(ranges_[i]);
        }
    }

    function removeRanges(Range[] memory ranges_) external onlyOwner {
        for (uint256 i = 0; i < ranges_.length; i++) {
            (bool exist, uint256 index) = rangeExist(ranges_[i]);
            require(exist, "not range");

            delete ranges[index];
        }
    }

    function setManagerTreasury(address managerTreasury_) external onlyOwner {
        managerTreasury = managerTreasury_;
    }

    function setMaxTwapDeviation(int24 maxTwapDeviation_) external onlyOwner {
        maxTwapDeviation = maxTwapDeviation_;
    }

    function setTwapDuration(uint24 twapDuration_) external onlyOwner {
        twapDuration = twapDuration_;
    }

    /// @dev should higher than 10000
    function setBurnSlippage(uint24 burnSlippage_) external onlyOwner {
        require(burnSlippage_ > 0, "burn slippage");

        burnSlippage = burnSlippage_;
    }

    // #endregion setter functions

    // #region view/pure functions

    function rangeExist(Range memory range_)
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
}
