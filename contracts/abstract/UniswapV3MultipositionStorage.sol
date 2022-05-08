// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {Range} from "../structs/SMultiposition.sol";

/// @dev Single Global upgradeable state var storage base: APPEND ONLY
/// @dev Add all inherited contracts with state vars here: APPEND ONLY
// solhint-disable-next-line max-states-count
abstract contract UniswapV3MultipositionStorage is
    OwnableUninitialized,
    Initializable
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set internal _positionIds;

    IERC20 public token0;
    IERC20 public token1;
    IUniswapV3Pool public pool;
    mapping(bytes32 => Range) public ranges;

    function initialize(
        address uniswapV3Pool,
        address owner
    ) external initializer {
        pool = IUniswapV3Pool(uniswapV3Pool);
        token0 = IERC20(IUniswapV3Pool(uniswapV3Pool).token0());
        token1 = IERC20(IUniswapV3Pool(uniswapV3Pool).token1());
        _owner = owner;
    }

    function positionIds() external view returns (bytes32[] memory) {
        return _positionIds.values();
    }
}