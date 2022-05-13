// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    FullMath,
    LiquidityAmounts
} from "./vendor/uniswap/LiquidityAmounts.sol";
import {VaultV2Storage} from "./abstract/VaultV2Storage.sol";
import {Range, Position, RebalanceParams} from "./structs/SMultiposition.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

contract VaultV2 is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    VaultV2Storage
{
    using SafeERC20 for IERC20;
    using TickMath for int24;
    using EnumerableSet for EnumerableSet.AddressSet;

    event Minted(
        address receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In
    );

    event Burned(
        address receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out
    );

    event Rebalance(
        int24[] lowerTicks,
        int24[] upperTicks,
        uint128[] liquidityBefores,
        uint128 liquidityAfters
    );

    event FeesEarned(uint256 fee0, uint256 fee1);

    // solhint-disable-next-line no-empty-blocks
    constructor(IUniswapV3Factory factory_) VaultV2Storage(factory_) {}

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata /*_data*/
    ) external override {
        require(_pools.contains(msg.sender), "callback caller");

        if (amount0Owed > 0)
            token0.safeTransferFrom(_owner, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            token1.safeTransferFrom(_owner, msg.sender, amount1Owed);
    }

    /// @notice Uniswap v3 callback fn, called back on pool.swap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        require(_pools.contains(msg.sender), "callback caller");

        if (amount0Delta > 0)
            token0.safeTransferFrom(_owner, msg.sender, uint256(amount0Delta));
        else if (amount1Delta > 0)
            token1.safeTransferFrom(_owner, msg.sender, uint256(amount1Delta));
    }

    function mint(uint256 mintAmount_, address receiver_)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 totalSupply = totalSupply();
        (uint256 current0, uint256 current1) =
            totalSupply > 0 ? underlying() : (_init0, _init1);
        uint256 denominator = totalSupply > 0 ? totalSupply : 1 ether;
        amount0 = FullMath.mulDivRoundingUp(mintAmount_, current0, denominator);
        amount1 = FullMath.mulDivRoundingUp(mintAmount_, current1, denominator);

        // transfer amounts owed to contract
        if (amount0 > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amount1);
        }

        _mint(receiver_, mintAmount_);
        emit Minted(receiver_, mintAmount_, amount0, amount1);
    }

    function burn(uint256 burnAmount_, address receiver_)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(burnAmount_ > 0, "burn 0");

        uint256 totalSupply = totalSupply();
        amount0 = FullMath.mulDiv(
            token0.balanceOf(address(this)),
            burnAmount_,
            totalSupply
        );
        amount1 = FullMath.mulDiv(
            token1.balanceOf(address(this)),
            burnAmount_,
            totalSupply
        );

        // TODO: here buffer implementation.

        emit Burned(receiver_, burnAmount_, amount0, amount1);
    }

    // solhint-disable-next-line function-max-lines
    function rebalance(RebalanceParams memory rebalanceParams_)
        external
        nonReentrant
        onlyOperators
    {
        // Burns
        uint256 totalFee0 = 0;
        uint256 totalFee1 = 0;
        for (uint256 i = 0; i < rebalanceParams_.removes.length; i++) {
            IUniswapV3Pool pool =
                IUniswapV3Pool(
                    factory.getPool(
                        address(token0),
                        address(token1),
                        rebalanceParams_.removes[i].range.feeTier
                    )
                );
            require(_pools.contains(address(pool)), "pool");

            (, , uint256 fee0, uint256 fee1) =
                _withdraw(
                    pool,
                    rebalanceParams_.removes[i].range.lowerTick,
                    rebalanceParams_.removes[i].range.upperTick,
                    rebalanceParams_.removes[i].liquidity
                );

            _applyFees(fee0, fee1);
            (fee0, fee1) = _subtractAdminFees(fee0, fee1);
            totalFee0 += fee0;
            totalFee1 += fee1;
        }

        emit FeesEarned(totalFee0, totalFee1);

        // Swap

        if (rebalanceParams_.swap.amountIn > 0) {
            uint256 wantedPrice =
                rebalanceParams_.swap.zeroForOne
                    ? FullMath.mulDiv(
                        rebalanceParams_.swap.amountIn,
                        rebalanceParams_.swap.expectedMinReturn,
                        ERC20(address(token1)).decimals()
                    )
                    : FullMath.mulDiv(
                        rebalanceParams_.swap.expectedMinReturn,
                        rebalanceParams_.swap.amountIn,
                        ERC20(address(token1)).decimals()
                    );

            _checkSlippage(wantedPrice, rebalanceParams_.swap.zeroForOne);
            {
                uint256 balance0Before = token0.balanceOf(address(this));
                uint256 balance1Before = token1.balanceOf(address(this));
                (bool success, ) =
                    rebalanceParams_.swap.router.call(
                        rebalanceParams_.swap.payload
                    );
                require(success, "swap");

                uint256 balance0After = token0.balanceOf(address(this));
                uint256 balance1After = token1.balanceOf(address(this));

                require(
                    rebalanceParams_.swap.zeroForOne
                        ? (balance1After >=
                            balance1Before +
                                rebalanceParams_.swap.expectedMinReturn) &&
                            (balance0After ==
                                balance0Before - rebalanceParams_.swap.amountIn)
                        : (balance0After >=
                            balance0Before +
                                rebalanceParams_.swap.expectedMinReturn) &&
                            (balance1After ==
                                balance1Before -
                                    rebalanceParams_.swap.amountIn),
                    "swap failed"
                );
            }
        }

        // Mints

        for (uint256 i = 0; i < rebalanceParams_.deposits.length; i++) {
            IUniswapV3Pool pool =
                IUniswapV3Pool(
                    factory.getPool(
                        address(token0),
                        address(token1),
                        rebalanceParams_.deposits[i].range.feeTier
                    )
                );
            pool.mint(
                address(this),
                rebalanceParams_.deposits[i].range.lowerTick,
                rebalanceParams_.deposits[i].range.upperTick,
                rebalanceParams_.deposits[i].liquidity,
                ""
            );
        }

        // TODO : emit rebalance event.
        //emit Rebalance();
    }

    function withdrawManagerBalance() external {
        uint256 amount0 = managerBalance0;
        uint256 amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(managerTreasury, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(managerTreasury, amount1);
        }
    }

    // #region public view functions

    function underlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        for (uint256 i = 0; i < ranges.length; i++) {
            (uint256 a0, uint256 a1, , ) = singleUnderlying(ranges[i]);
            amount0 += a0;
            amount1 += a1;
        }
    }

    function underlyingWithFees()
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        for (uint256 i = 0; i < ranges.length; i++) {
            (uint256 a0, uint256 a1, uint256 f0, uint256 f1) =
                singleUnderlying(ranges[i]);
            amount0 += a0;
            amount1 += a1;
            fee0 += f0;
            fee1 += f1;
        }
    }

    function singleUnderlying(Range memory range_)
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        IUniswapV3Pool v3Pool;
        {
            address pool =
                factory.getPool(
                    address(token0),
                    address(token1),
                    range_.feeTier
                );
            require(_pools.contains(pool), "pool");
            v3Pool = IUniswapV3Pool(pool);
        }

        (amount0, amount1, fee0, fee1) = _underlying(range_, v3Pool);
    }

    /// @notice this function is not marked view because of internal delegatecalls
    /// but it should be staticcalled from off chain
    function mintAmounts(uint256 amount0Max, uint256 amount1Max)
        public
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        uint256 totalSupply = totalSupply();

        (uint256 current0, uint256 current1) =
            totalSupply > 0 ? underlying() : (_init0, _init1);

        return
            _computeMintAmounts(
                current0,
                current1,
                totalSupply > 0 ? totalSupply : 1 ether,
                amount0Max,
                amount1Max
            );
    }

    // #endregion public view functions

    // #region internal functions

    function _withdraw(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity_
    )
        internal
        returns (
            uint256 burn0,
            uint256 burn1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 preBalance0 = token0.balanceOf(address(this));
        uint256 preBalance1 = token1.balanceOf(address(this));

        (burn0, burn1) = pool_.burn(lowerTick_, upperTick_, liquidity_);

        pool_.collect(
            address(this),
            lowerTick_,
            upperTick_,
            type(uint128).max,
            type(uint128).max
        );

        fee0 = token0.balanceOf(address(this)) - preBalance0 - burn0;
        fee1 = token1.balanceOf(address(this)) - preBalance1 - burn1;
    }

    function _applyFees(uint256 _fee0, uint256 _fee1) internal {
        managerBalance0 += (_fee0 * managerFeeBPS) / 10000;
        managerBalance1 += (_fee1 * managerFeeBPS) / 10000;
    }

    // #endregion internal functions

    // #region internal view functions

    function _subtractAdminFees(uint256 rawFee0, uint256 rawFee1)
        internal
        view
        returns (uint256 fee0, uint256 fee1)
    {
        uint256 deduct0 = (rawFee0 * (managerFeeBPS)) / 10000;
        uint256 deduct1 = (rawFee1 * (managerFeeBPS)) / 10000;
        fee0 = rawFee0 - deduct0;
        fee1 = rawFee1 - deduct1;
    }

    function _underlying(Range memory range_, IUniswapV3Pool pool_)
        internal
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fee0,
            uint256 fee1
        )
    {
        uint256 a0;
        uint256 a1;
        uint256 f0;
        uint256 f1;
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool_.slot0();
        bytes32 positionId = _getPositionId(range_.lowerTick, range_.upperTick);
        PositionUnderlying memory positionUnderlying =
            PositionUnderlying({
                positionId: positionId,
                sqrtPriceX96: sqrtPriceX96,
                tick: tick,
                lowerTick: range_.lowerTick,
                upperTick: range_.upperTick,
                pool: pool_
            });
        (a0, a1, f0, f1) = _positionUnderlying(positionUnderlying);
        amount0 += a0;
        amount1 += a1;
        fee0 += f0;
        fee1 += f1;
    }

    // solhint-disable-next-line ordering
    struct PositionUnderlying {
        bytes32 positionId;
        uint160 sqrtPriceX96;
        int24 tick;
        int24 lowerTick;
        int24 upperTick;
        IUniswapV3Pool pool;
    }

    // solhint-disable-next-line function-max-lines
    function _positionUnderlying(PositionUnderlying memory positionUnderlying_)
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
        ) = positionUnderlying_.pool.positions(positionUnderlying_.positionId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            positionUnderlying_.sqrtPriceX96,
            positionUnderlying_.lowerTick.getSqrtRatioAtTick(),
            positionUnderlying_.upperTick.getSqrtRatioAtTick(),
            liquidity
        );
        // compute current fees earned
        fee0 =
            _computeFeesEarned(
                ComputeFeesEarned({
                    feeGrowthInsideLast: feeGrowthInside0Last,
                    liquidity: liquidity,
                    tick: positionUnderlying_.tick,
                    lowerTick: positionUnderlying_.lowerTick,
                    upperTick: positionUnderlying_.upperTick,
                    isZero: true,
                    pool: positionUnderlying_.pool
                })
            ) +
            uint256(tokensOwed0);
        fee1 =
            _computeFeesEarned(
                ComputeFeesEarned({
                    feeGrowthInsideLast: feeGrowthInside1Last,
                    liquidity: liquidity,
                    tick: positionUnderlying_.tick,
                    lowerTick: positionUnderlying_.lowerTick,
                    upperTick: positionUnderlying_.upperTick,
                    isZero: false,
                    pool: positionUnderlying_.pool
                })
            ) +
            uint256(tokensOwed1);
    }

    function _getPositionId(int24 lowerTick_, int24 upperTick_)
        internal
        view
        returns (bytes32 positionId)
    {
        return
            keccak256(abi.encodePacked(address(this), lowerTick_, upperTick_));
    }

    function _getPoolRangeId(
        int24 lowerTick_,
        int24 upperTick_,
        uint24 feeTier_
    ) internal view returns (bytes32 poolRangeId) {
        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    lowerTick_,
                    upperTick_,
                    feeTier_
                )
            );
    }

    function _computeMintAmounts(
        uint256 current0,
        uint256 current1,
        uint256 totalSupply,
        uint256 amount0Max,
        uint256 amount1Max
    )
        internal
        pure
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        // compute proportional amount of tokens to mint
        if (current0 == 0 && current1 > 0) {
            mintAmount = FullMath.mulDiv(amount1Max, totalSupply, current1);
        } else if (current1 == 0 && current0 > 0) {
            mintAmount = FullMath.mulDiv(amount0Max, totalSupply, current0);
        } else if (current0 > 0 && current1 > 0) {
            uint256 amount0Mint =
                FullMath.mulDiv(amount0Max, totalSupply, current0);
            uint256 amount1Mint =
                FullMath.mulDiv(amount1Max, totalSupply, current1);
            require(
                amount0Mint > 0 && amount1Mint > 0,
                "ArrakisVaultV2: mint 0"
            );

            mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        } else {
            revert("ArrakisVaultV2: panic");
        }

        // compute amounts owed to contract
        amount0 = FullMath.mulDivRoundingUp(mintAmount, current0, totalSupply);
        amount1 = FullMath.mulDivRoundingUp(mintAmount, current1, totalSupply);
    }

    struct ComputeFeesEarned {
        uint256 feeGrowthInsideLast;
        uint256 liquidity;
        int24 tick;
        int24 lowerTick;
        int24 upperTick;
        bool isZero;
        IUniswapV3Pool pool;
    }

    // solhint-disable-next-line function-max-lines
    function _computeFeesEarned(ComputeFeesEarned memory computeFeesEarned_)
        private
        view
        returns (uint256 fee)
    {
        uint256 feeGrowthOutsideLower;
        uint256 feeGrowthOutsideUpper;
        uint256 feeGrowthGlobal;
        if (computeFeesEarned_.isZero) {
            feeGrowthGlobal = computeFeesEarned_.pool.feeGrowthGlobal0X128();
            (, , feeGrowthOutsideLower, , , , , ) = computeFeesEarned_
                .pool
                .ticks(computeFeesEarned_.lowerTick);
            (, , feeGrowthOutsideUpper, , , , , ) = computeFeesEarned_
                .pool
                .ticks(computeFeesEarned_.upperTick);
        } else {
            feeGrowthGlobal = computeFeesEarned_.pool.feeGrowthGlobal1X128();
            (, , , feeGrowthOutsideLower, , , , ) = computeFeesEarned_
                .pool
                .ticks(computeFeesEarned_.lowerTick);
            (, , , feeGrowthOutsideUpper, , , , ) = computeFeesEarned_
                .pool
                .ticks(computeFeesEarned_.upperTick);
        }

        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (computeFeesEarned_.tick >= computeFeesEarned_.lowerTick) {
                feeGrowthBelow = feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (computeFeesEarned_.tick < computeFeesEarned_.upperTick) {
                feeGrowthAbove = feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside =
                feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(
                computeFeesEarned_.liquidity,
                feeGrowthInside - computeFeesEarned_.feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }

    function _checkSlippage(uint256 swapThresholdPrice, bool zeroForOne)
        internal
        view
    {
        uint256 currentPrice = _getPriceX96FromSqrtPriceX96(_getSqrtTwapX96());

        if (zeroForOne) {
            require(
                swapThresholdPrice >=
                    currentPrice -
                        FullMath.mulDiv(
                            currentPrice,
                            10000,
                            uint256(maxTwapDeviation)
                        ),
                "high slippage"
            );
        } else {
            require(
                swapThresholdPrice <=
                    currentPrice +
                        FullMath.mulDiv(
                            currentPrice,
                            uint256(maxTwapDeviation),
                            10000
                        ),
                "high slippage"
            );
        }
    }

    function _getSqrtTwapX96() internal view returns (uint160 sqrtPriceX96) {
        // checking the price of the first is enough, because we suppose the market is efficient.
        require(_pools.at(0) != address(0), "pool");
        IUniswapV3Pool uniswapV3Pool = IUniswapV3Pool(_pools.at(0));
        if (twapDuration == 0) {
            // return the current price if twapDuration == 0
            (sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapDuration; // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) =
                uniswapV3Pool.observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24(
                    (tickCumulatives[1] - tickCumulatives[0]) /
                        int56(uint56(twapDuration))
                )
            );
        }
    }

    function _getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceX96)
    {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    // #endregion internal view functions
}
