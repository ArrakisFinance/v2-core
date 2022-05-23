// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {_subtractAdminFees, _getPositionId, _computeMintAmounts, _computeFeesEarned, _getTwap, _checkDeviation, _mintAmounts, _totalUnderlying, _totalUnderlyingAtPrice, _totalUnderlyingWithFees, _underlying, _underlyingAtPrice, _getUnderlyingBalances, _validateTickSpacing} from "../../functions/FVaultV2.sol";
import {ComputeFeesEarned, UnderlyingPayload, UnderStruct, PositionUnderlying, Range} from "../../structs/SMultiposition.sol";

contract MockFVaultV2 {
    function subtractAdminFees(
        uint256 rawFee0_,
        uint256 rawFee1_,
        uint16 managerFeeBPS_
    ) external pure returns (uint256 fee0, uint256 fee1) {
        return _subtractAdminFees(rawFee0_, rawFee1_, managerFeeBPS_);
    }

    function getPositionId(
        address self_,
        int24 lowerTick_,
        int24 upperTick_
    ) external view returns (bytes32 positionId) {
        return _getPositionId(self_, lowerTick_, upperTick_);
    }

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    )
        external
        pure
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        return
            _computeMintAmounts(
                current0_,
                current1_,
                totalSupply_,
                amount0Max_,
                amount1Max_
            );
    }

    function computeFeesEarned(ComputeFeesEarned calldata computeFeesEarned_)
        external
        view
        returns (uint256 fee)
    {
        return _computeFeesEarned(computeFeesEarned_);
    }

    function getTwap(IUniswapV3Pool pool_, uint24 twapDuration_)
        external
        view
        returns (int24)
    {
        return _getTwap(pool_, twapDuration_);
    }

    function checkDeviation(
        IUniswapV3Pool pool_,
        uint24 twapDuration_,
        int24 maxTwapDeviation_
    ) external view {
        _checkDeviation(pool_, twapDuration_, maxTwapDeviation_);
    }

    function mintAmounts(
        UnderlyingPayload memory underlyingPayload_,
        uint256 init0_,
        uint256 init1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    )
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        return
            _mintAmounts(
                underlyingPayload_,
                init0_,
                init1_,
                totalSupply_,
                amount0Max_,
                amount1Max_
            );
    }

    function totalUnderlying(UnderlyingPayload calldata underlyingPayload_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _totalUnderlying(underlyingPayload_);
    }

    function totalUnderlyingAtPrice(
        UnderlyingPayload calldata underlyingPayload_,
        uint160 sqrtRatioX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return _totalUnderlyingAtPrice(underlyingPayload_, sqrtRatioX96_);
    }

    function totalUnderlyingWithFees(
        UnderlyingPayload calldata underlyingPayload_
    )
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _totalUnderlyingWithFees(underlyingPayload_);
    }

    function underlying(UnderStruct memory underlying_)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _underlying(underlying_);
    }

    function underlyingAtPrice(
        UnderStruct calldata underlying_,
        uint160 sqrtPriceX96_
    )
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _underlyingAtPrice(underlying_, sqrtPriceX96_);
    }

    function getUnderlyingBalances(
        PositionUnderlying calldata positionUnderlying_
    )
        external
        view
        returns (
            uint256 amount0Current,
            uint256 amount1Current,
            uint256 fee0,
            uint256 fee1
        )
    {
        return _getUnderlyingBalances(positionUnderlying_);
    }

    function validateTickSpacing(
        IUniswapV3Factory factory_,
        address token0_,
        address token1_,
        Range memory range_
    ) external view returns (bool) {
        return _validateTickSpacing(factory_, token0_, token1_, range_);
    }
}
