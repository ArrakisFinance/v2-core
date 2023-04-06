// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Position as PositionHelper} from "../../libraries/Position.sol";
import {Underlying as UnderlyingHelper} from "../../libraries/Underlying.sol";
import {Pool} from "../../libraries/Pool.sol";
import {
    ComputeFeesPayload,
    UnderlyingPayload,
    RangeData,
    PositionUnderlying,
    Range
} from "../../structs/SArrakisV2.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/LiquidityAmounts.sol";

contract MockFArrakisV2 {
    function getUnderlyingBalances(
        PositionUnderlying calldata positionUnderlying_
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
        return UnderlyingHelper.getUnderlyingBalances(positionUnderlying_);
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
        return UnderlyingHelper.totalUnderlyingWithFees(underlyingPayload_);
    }

    function validateTickSpacing(address pool_, Range memory range_)
        external
        view
        returns (bool)
    {
        return Pool.validateTickSpacing(pool_, range_);
    }

    function subtractAdminFees(
        uint256 rawFee0_,
        uint256 rawFee1_,
        uint16 managerFeeBPS_
    ) external pure returns (uint256 fee0, uint256 fee1) {
        return
            UnderlyingHelper.subtractAdminFees(
                rawFee0_,
                rawFee1_,
                managerFeeBPS_
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
        mintAmount = UnderlyingHelper.computeMintAmounts(
            current0_,
            current1_,
            totalSupply_,
            amount0Max_,
            amount1Max_
        );
        amount0 = FullMath.mulDivRoundingUp(
            mintAmount,
            current0_,
            totalSupply_
        );
        amount1 = FullMath.mulDivRoundingUp(
            mintAmount,
            current1_,
            totalSupply_
        );
    }

    function checkMulDiv(
        uint256 a,
        uint256 b,
        uint256 c
    ) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, c);
    }
}
