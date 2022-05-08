// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3MultipositionStorage
} from "../abstract/UniswapV3MultipositionStorage.sol";
import {TickMath} from "../vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    FullMath,
    LiquidityAmounts
} from "../vendor/uniswap/LiquidityAmounts.sol";
import {Position, Range} from "../structs/SMultiposition.sol";

contract UniswapV3Multiposition is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    UniswapV3MultipositionStorage
{
    using SafeERC20 for IERC20;
    using TickMath for int24;
     using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        require(msg.sender == address(pool), "callback caller");

        if (amount0Owed > 0) token0.safeTransferFrom(_owner, msg.sender, amount0Owed);
        if (amount1Owed > 0) token1.safeTransferFrom(_owner, msg.sender, amount1Owed);
    }

    /// @notice Uniswap v3 callback fn, called back on pool.swap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        require(msg.sender == address(pool), "callback caller");

        if (amount0Delta > 0)
            token0.safeTransferFrom(_owner, msg.sender, uint256(amount0Delta));
        else if (amount1Delta > 0)
            token1.safeTransferFrom(_owner, msg.sender, uint256(amount1Delta));
    }

    function deposit(Position[] calldata params)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 a0; uint256 a1;
        for (uint256 i = 0; i < params.length; i++) {
            (a0, a1) = _addToPosition(
                params[i].lowerTick,
                params[i].upperTick,
                params[i].liquidity
            );
            amount0 += a0;
            amount1 += a1;
        }
    }
    
    function withdraw(Position[] calldata params)
        external
        onlyOwner
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 a0; uint256 a1; uint256 f0; uint256 f1;
        for (uint256 i = 0; i < params.length; i++) {
            (a0, a1, f0, f1) = _removeFromPosition(
                params[i].lowerTick,
                params[i].upperTick,
                params[i].liquidity
            );
            amount0 += a0;
            amount1 += a1;
            fee0 += fee0;
            fee1 += fee1;
        }
    }

    function withdrawAll()
        external
        onlyOwner
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 a0; uint256 a1; uint256 f0; uint256 f1;
        for (uint256 i = 0; i<_positionIds.length(); i++) {
            bytes32 positionId = _positionIds.at(i);
            Range memory range = ranges[positionId];
            (a0, a1, f0, f1) = _removeFromPosition(
                range.lowerTick,
                range.upperTick,
                type(uint128).max
            );
            amount0 += a0;
            amount1 += a1;
            fee0 += fee0;
            fee1 += fee1;
        }
    }

    function withdrawAllFees() external onlyOwner returns (uint256 fee0, uint256 fee1) {
        uint256 f0; uint256 f1;
        for (uint256 i = 0; i<_positionIds.length(); i++) {
            bytes32 positionId = _positionIds.at(i);
            Range memory range = ranges[positionId];
            (, , f0, f1) = _removeFromPosition(
                range.lowerTick,
                range.upperTick,
                0
            );
            fee0 += f0;
            fee1 += f1;
        }
    }

    function swap(
        int256 swapAmount,
        uint160 swapThresholdPrice,
        bool zeroForOne
    ) external onlyOwner returns (int256 amount0Delta, int256 amount1Delta) {
            return pool.swap(
                _owner,
                zeroForOne,
                swapAmount,
                swapThresholdPrice,
                ""
            );
    }

    function underlying()
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
        return _underlying(sqrtPriceX96, tick);
    }

    function underlyingAtPrice(uint160 sqrtPriceX96)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        (, int24 tick, , , , , ) = pool.slot0();
        return _underlying(sqrtPriceX96, tick);
    }

    function _addToPosition(int24 lowerTick, int24 upperTick, uint128 liquidity)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        bytes32 positionId = _getPositionId(lowerTick, upperTick);
        if (!_positionIds.contains(positionId)) {
            _positionIds.add(positionId);
            ranges[positionId] = Range({
                lowerTick: lowerTick,
                upperTick: upperTick
            });
        }

        (amount0, amount1) = pool.mint(address(this), lowerTick, upperTick, liquidity, "");
        //emit AddToPosition(lowerTick, upperTick, liquidity, amount0, amount1);
    }

    function _removeFromPosition(int24 lowerTick, int24 upperTick, uint128 liquidity)
        internal
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        bytes32 positionId = _getPositionId(lowerTick, upperTick);
        (uint128 currentLiquidity,,,,) = pool.positions(positionId);
        require(currentLiquidity > 0, "UniswapV3Multiposition::_removeFromPostion: position DNE");
        liquidity = type(uint128).max == liquidity ? currentLiquidity : liquidity;
        
        if (currentLiquidity == liquidity) {
            _positionIds.remove(positionId);
            delete ranges[positionId];
        }

        (amount0, amount1) = pool.burn(lowerTick, upperTick, liquidity);
        (uint128 total0, uint128 total1) =
            pool.collect(_owner, lowerTick, upperTick, type(uint128).max, type(uint128).max);

        fee0 = uint256(total0) - amount0;
        fee1 = uint256(total1) - amount1;
        //emit RemoveFromPosition(lowerTick, upperTick, liquidity, amount0, amount1, fee0, fee1);
    }

    function _getPositionId(int24 lowerTick, int24 upperTick)
        internal 
        view
        returns (bytes32 positionId)
    {
        return keccak256(abi.encodePacked(address(this), lowerTick, upperTick));
    }

    function _underlying(uint160 sqrtPriceX96, int24 tick)
        internal
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 a0; uint256 a1; uint256 f0; uint256 f1;
        for (uint256 i = 0; i<_positionIds.length(); i++) {
            bytes32 positionId = _positionIds.at(i);
            Range memory range = ranges[positionId];
            (a0, a1, f0, f1) = _positionUnderlying(
                positionId,
                sqrtPriceX96,
                tick,
                range.lowerTick,
                range.upperTick
            );
            amount0 += a0;
            amount1 += a1;
            fee0 += f0;
            fee1 += f1;
        }
    }

    function _positionUnderlying(
        bytes32 positionId,
        uint160 sqrtPriceX96,
        int24 tick,
        int24 lowerTick,
        int24 upperTick
    )
        internal
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        (
            uint128 liquidity,
            uint256 feeGrowthInside0Last,
            uint256 feeGrowthInside1Last,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = pool.positions(positionId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            lowerTick.getSqrtRatioAtTick(),
            upperTick.getSqrtRatioAtTick(),
            liquidity
        );
        // compute current fees earned
        fee0 =
            _computeFeesEarned(feeGrowthInside0Last, liquidity, tick, lowerTick, upperTick, true) +
                uint256(tokensOwed0);
        fee1 =
            _computeFeesEarned(feeGrowthInside1Last, liquidity, tick, lowerTick, upperTick, false) +
                uint256(tokensOwed1);
    }

    // solhint-disable-next-line function-max-lines
    function _computeFeesEarned(
        uint256 feeGrowthInsideLast,
        uint128 liquidity,
        int24 tick,
        int24 lowerTick,
        int24 upperTick,
        bool isZero
    ) private view returns (uint256 fee) {
        uint256 feeGrowthOutsideLower;
        uint256 feeGrowthOutsideUpper;
        uint256 feeGrowthGlobal;
        if (isZero) {
            feeGrowthGlobal = pool.feeGrowthGlobal0X128();
            (, , feeGrowthOutsideLower, , , , , ) = pool.ticks(lowerTick);
            (, , feeGrowthOutsideUpper, , , , , ) = pool.ticks(upperTick);
        } else {
            feeGrowthGlobal = pool.feeGrowthGlobal1X128();
            (, , , feeGrowthOutsideLower, , , , ) = pool.ticks(lowerTick);
            (, , , feeGrowthOutsideUpper, , , , ) = pool.ticks(upperTick);
        }

        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (tick >= lowerTick) {
                feeGrowthBelow = feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (tick < upperTick) {
                feeGrowthAbove = feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside =
                feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(
                liquidity,
                feeGrowthInside - feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }
}