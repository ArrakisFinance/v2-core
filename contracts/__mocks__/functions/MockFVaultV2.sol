// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Position as PositionHelper} from "../../libraries/Position.sol";
import {Twap} from "../../libraries/Twap.sol";
import {Underlying as UnderlyingHelper} from "../../libraries/Underlying.sol";
import {UniswapV3Amounts} from "../../libraries/UniswapV3Amounts.sol";
import {Pool} from "../../libraries/Pool.sol";
import {FeesEarnedPayload, UnderlyingPayload, RangeData, PositionUnderlying, Range} from "../../structs/SVaultV2.sol";

contract MockFVaultV2 {
    function subtractAdminFees(
        uint256 rawFee0_,
        uint256 rawFee1_,
        uint16 managerFeeBPS_,
        uint16 arrakisFeeBPS_
    ) external pure returns (uint256 fee0, uint256 fee1) {
        return
            UniswapV3Amounts.subtractAdminFees(
                rawFee0_,
                rawFee1_,
                managerFeeBPS_,
                arrakisFeeBPS_
            );
    }

    function getPositionId(
        address self_,
        int24 lowerTick_,
        int24 upperTick_
    ) external pure returns (bytes32 positionId) {
        return PositionHelper.getPositionId(self_, lowerTick_, upperTick_);
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
            UniswapV3Amounts.computeMintAmounts(
                current0_,
                current1_,
                totalSupply_,
                amount0Max_,
                amount1Max_
            );
    }

    function computeFeesEarned(FeesEarnedPayload calldata computeFeesEarned_)
        external
        view
        returns (uint256 fee)
    {
        return UniswapV3Amounts.computeFeesEarned(computeFeesEarned_);
    }

    function getTwap(IUniswapV3Pool pool_, uint24 twapDuration_)
        external
        view
        returns (int24)
    {
        return Twap.getTwap(pool_, twapDuration_);
    }

    function checkDeviation(
        IUniswapV3Pool pool_,
        uint24 twapDuration_,
        int24 maxTwapDeviation_
    ) external view {
        Twap.checkDeviation(pool_, twapDuration_, maxTwapDeviation_);
    }

    // function totalUnderlying(UnderlyingPayload calldata underlyingPayload_)
    //     external
    //     view
    //     returns (uint256 amount0, uint256 amount1)
    // {
    //     return UnderlyingHelper.totalUnderlying(underlyingPayload_);
    // }

    // function totalUnderlyingAtPrice(
    //     UnderlyingPayload calldata underlyingPayload_,
    //     uint160 sqrtRatioX96_
    // ) external view returns (uint256 amount0, uint256 amount1) {
    //     return
    //         UnderlyingHelper.totalUnderlyingAtPrice(
    //             underlyingPayload_,
    //             sqrtRatioX96_
    //         );
    // }

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
        return UnderlyingHelper.totalUnderlyingWithFees(underlyingPayload_);
    }

    function validateTickSpacing(
        IUniswapV3Factory factory_,
        address token0_,
        address token1_,
        Range memory range_
    ) external view returns (bool) {
        return Pool.validateTickSpacing(factory_, token0_, token1_, range_);
    }
}
