// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Withdraw, UnderlyingPayload} from "../structs/SArrakisV2.sol";
import {Position} from "../libraries/Position.sol";
import {
    ArrakisStorage,
    ArrakisStorageLib
} from "../libraries/ArrakisStorageLib.sol";
import {hundredPercent} from "../constants/CArrakisV2.sol";
import {Pool} from "../libraries/Pool.sol";
import {Underlying as UnderlyingHelper} from "../libraries/Underlying.sol";
import {IArrakisV2} from "../interfaces/IArrakisV2.sol";

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
import {hundredPercent} from "../constants/CArrakisV2.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library Invest {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    event LogCollectedFees(uint256 fee0, uint256 fee1);

    event LogRebalance(
        Rebalance rebalanceParams,
        uint256 swapDelta0,
        uint256 swapDelta1
    );

    event LogMint(
        address indexed receiver,
        uint256 mintAmount,
        uint256 amount0In,
        uint256 amount1In
    );

    event LogBurn(
        address indexed receiver,
        uint256 burnAmount,
        uint256 amount0Out,
        uint256 amount1Out
    );

    event LPBurned(
        address indexed user,
        uint256 burnAmount0,
        uint256 burnAmount1
    );

    /// @notice rebalance ArrakisV2 vault's UniswapV3 positions
    /// @param rebalanceParams_ rebalance params, containing ranges where
    /// we need to collect tokens and ranges where we need to mint liquidity.
    /// Also contain swap payload to changes token0/token1 proportion.
    /// @dev only Manager contract can call this function.
    // solhint-disable-next-line function-max-lines, code-complexity

    struct RebalanceLocalVars {
        uint256 aggregator0;
        uint256 aggregator1;
        IERC20 token0;
        IERC20 token1;
    }

    /// @notice mint Arrakis V2 shares by depositing underlying
    /// @param mintAmount_ represent the amount of Arrakis V2 shares to mint.
    /// @param receiver_ address that will receive Arrakis V2 shares.
    /// @return amount0 amount of token0 needed to mint mintAmount_ of shares.
    /// @return amount1 amount of token1 needed to mint mintAmount_ of shares.
    // solhint-disable-next-line function-max-lines, code-complexity
    function mint(
        uint256 mintAmount_,
        address receiver_,
        uint256 ts
    ) external returns (uint256 amount0, uint256 amount1) {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        require(mintAmount_ > 0, "MA");
        address me = address(this);
        bool isTotalSupplyGtZero = ts > 0;
        if (isTotalSupplyGtZero) {
            (amount0, amount1) = UnderlyingHelper.totalUnderlyingForMint(
                UnderlyingPayload({
                    ranges: arrakisStorage.ranges,
                    factory: arrakisStorage.factory,
                    token0: address(arrakisStorage.token0),
                    token1: address(arrakisStorage.token1),
                    self: me
                }),
                mintAmount_,
                ts
            );
        } else {
            uint256 denominator = 1 ether;
            uint256 init0M = arrakisStorage.init0;
            uint256 init1M = arrakisStorage.init1;

            amount0 = FullMath.mulDivRoundingUp(
                mintAmount_,
                init0M,
                denominator
            );
            amount1 = FullMath.mulDivRoundingUp(
                mintAmount_,
                init1M,
                denominator
            );

            /// @dev check ratio against small values that skew init ratio
            if (FullMath.mulDiv(mintAmount_, init0M, denominator) == 0) {
                amount0 = 0;
            }
            if (FullMath.mulDiv(mintAmount_, init1M, denominator) == 0) {
                amount1 = 0;
            }

            uint256 amount0Mint = init0M != 0
                ? FullMath.mulDiv(amount0, denominator, init0M)
                : type(uint256).max;
            uint256 amount1Mint = init1M != 0
                ? FullMath.mulDiv(amount1, denominator, init1M)
                : type(uint256).max;

            require(
                (amount0Mint < amount1Mint ? amount0Mint : amount1Mint) ==
                    mintAmount_,
                "A0&A1"
            );
        }

        // transfer amounts owed to contract
        if (amount0 > 0) {
            arrakisStorage.token0.safeTransferFrom(msg.sender, me, amount0);
        }
        if (amount1 > 0) {
            arrakisStorage.token1.safeTransferFrom(msg.sender, me, amount1);
        }

        if (isTotalSupplyGtZero) {
            for (uint256 i; i < arrakisStorage.ranges.length; i++) {
                Range memory range = arrakisStorage.ranges[i];
                IUniswapV3Pool pool = IUniswapV3Pool(
                    arrakisStorage.factory.getPool(
                        address(arrakisStorage.token0),
                        address(arrakisStorage.token1),
                        range.feeTier
                    )
                );
                uint128 liquidity = Position.getLiquidityByRange(
                    pool,
                    me,
                    range.lowerTick,
                    range.upperTick
                );

                liquidity = SafeCast.toUint128(
                    FullMath.mulDiv(liquidity, mintAmount_, ts)
                );

                if (liquidity == 0) continue;

                pool.mint(me, range.lowerTick, range.upperTick, liquidity, "");
            }
        }
        emit LogMint(receiver_, mintAmount_, amount0, amount1);
    }

    /// @notice burn Arrakis V2 shares and withdraw underlying.
    /// @param burnAmount_ amount of vault shares to burn.
    /// @param receiver_ address to receive underlying tokens withdrawn.
    /// @return amount0 amount of token0 sent to receiver
    /// @return amount1 amount of token1 sent to receiver
    // solhint-disable-next-line function-max-lines, code-complexity
    function burn(
        uint256 burnAmount_,
        address receiver_,
        uint256 ts
    ) external returns (uint256 amount0, uint256 amount1) {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        Withdraw memory total;
        for (uint256 i; i < arrakisStorage.ranges.length; i++) {
            Range memory range = arrakisStorage.ranges[i];
            IUniswapV3Pool pool = IUniswapV3Pool(
                arrakisStorage.factory.getPool(
                    address(arrakisStorage.token0),
                    address(arrakisStorage.token1),
                    range.feeTier
                )
            );
            uint128 liquidity = Position.getLiquidityByRange(
                pool,
                address(this),
                range.lowerTick,
                range.upperTick
            );

            liquidity = SafeCast.toUint128(
                FullMath.mulDiv(liquidity, burnAmount_, ts)
            );

            if (liquidity == 0) continue;

            Withdraw memory withdraw = _withdraw(
                pool,
                range.lowerTick,
                range.upperTick,
                liquidity
            );

            total.fee0 += withdraw.fee0;
            total.fee1 += withdraw.fee1;

            total.burn0 += withdraw.burn0;
            total.burn1 += withdraw.burn1;
        }

        if (burnAmount_ == ts) delete arrakisStorage.ranges;

        _applyFees(total.fee0, total.fee1);

        uint256 leftOver0 = arrakisStorage.token0.balanceOf(address(this)) -
            arrakisStorage.managerBalance0 -
            total.burn0;
        uint256 leftOver1 = arrakisStorage.token1.balanceOf(address(this)) -
            arrakisStorage.managerBalance1 -
            total.burn1;

        // the proportion of user balance.
        amount0 = FullMath.mulDiv(leftOver0, burnAmount_, ts);
        amount1 = FullMath.mulDiv(leftOver1, burnAmount_, ts);

        amount0 += total.burn0;
        amount1 += total.burn1;

        if (amount0 > 0) {
            arrakisStorage.token0.safeTransfer(receiver_, amount0);
        }

        if (amount1 > 0) {
            arrakisStorage.token1.safeTransfer(receiver_, amount1);
        }

        // For monitoring how much user burn LP token for getting their token back.
        emit LPBurned(msg.sender, total.burn0, total.burn1);
        emit LogCollectedFees(total.fee0, total.fee1);
        emit LogBurn(receiver_, burnAmount_, amount0, amount1);
    }

    function rebalance(Rebalance calldata rebalanceParams_) external {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        RebalanceLocalVars memory rebalanceLocalVars;
        rebalanceLocalVars.token0 = arrakisStorage.token0;
        rebalanceLocalVars.token1 = arrakisStorage.token1;

        // Burns.
        IUniswapV3Factory mFactory = arrakisStorage.factory;

        {
            Withdraw memory aggregator;
            for (uint256 i; i < rebalanceParams_.burns.length; i++) {
                IUniswapV3Pool pool = IUniswapV3Pool(
                    mFactory.getPool(
                        address(rebalanceLocalVars.token0),
                        address(rebalanceLocalVars.token1),
                        rebalanceParams_.burns[i].range.feeTier
                    )
                );

                uint128 liquidity = Position.getLiquidityByRange(
                    pool,
                    address(this),
                    rebalanceParams_.burns[i].range.lowerTick,
                    rebalanceParams_.burns[i].range.upperTick
                );

                if (liquidity == 0) continue;

                uint128 liquidityToWithdraw;

                if (rebalanceParams_.burns[i].liquidity == type(uint128).max)
                    liquidityToWithdraw = liquidity;
                else liquidityToWithdraw = rebalanceParams_.burns[i].liquidity;

                Withdraw memory withdraw = _withdraw(
                    pool,
                    rebalanceParams_.burns[i].range.lowerTick,
                    rebalanceParams_.burns[i].range.upperTick,
                    liquidityToWithdraw
                );

                if (liquidityToWithdraw == liquidity) {
                    (bool exists, uint256 index) = Position.rangeExists(
                        arrakisStorage.ranges,
                        rebalanceParams_.burns[i].range
                    );
                    require(exists, "RRNE");

                    arrakisStorage.ranges[index] = arrakisStorage.ranges[
                        arrakisStorage.ranges.length - 1
                    ];
                    arrakisStorage.ranges.pop();
                }

                aggregator.burn0 += withdraw.burn0;
                aggregator.burn1 += withdraw.burn1;

                aggregator.fee0 += withdraw.fee0;
                aggregator.fee1 += withdraw.fee1;
            }

            require(aggregator.burn0 >= rebalanceParams_.minBurn0, "B0");
            require(aggregator.burn1 >= rebalanceParams_.minBurn1, "B1");

            if (aggregator.fee0 > 0 || aggregator.fee1 > 0) {
                _applyFees(aggregator.fee0, aggregator.fee1);

                emit LogCollectedFees(aggregator.fee0, aggregator.fee1);
            }
        }

        // Swap.
        if (rebalanceParams_.swap.amountIn > 0) {
            require(
                arrakisStorage.routers.contains(rebalanceParams_.swap.router),
                "NR"
            );

            uint256 balance0Before = rebalanceLocalVars.token0.balanceOf(
                address(this)
            );
            uint256 balance1Before = rebalanceLocalVars.token1.balanceOf(
                address(this)
            );

            rebalanceLocalVars.token0.safeApprove(
                address(rebalanceParams_.swap.router),
                0
            );
            rebalanceLocalVars.token1.safeApprove(
                address(rebalanceParams_.swap.router),
                0
            );

            rebalanceLocalVars.token0.safeApprove(
                address(rebalanceParams_.swap.router),
                balance0Before
            );
            rebalanceLocalVars.token1.safeApprove(
                address(rebalanceParams_.swap.router),
                balance1Before
            );

            (bool success, ) = rebalanceParams_.swap.router.call(
                rebalanceParams_.swap.payload
            );
            require(success, "SC");

            uint256 balance0After = rebalanceLocalVars.token0.balanceOf(
                address(this)
            );
            uint256 balance1After = rebalanceLocalVars.token1.balanceOf(
                address(this)
            );
            if (rebalanceParams_.swap.zeroForOne) {
                require(
                    (balance1After >=
                        balance1Before +
                            rebalanceParams_.swap.expectedMinReturn) &&
                        (balance0After >=
                            balance0Before - rebalanceParams_.swap.amountIn),
                    "SF"
                );
                balance0After = balance0Before - balance0After;
                balance1After = balance1After - balance1Before;
            } else {
                require(
                    (balance0After >=
                        balance0Before +
                            rebalanceParams_.swap.expectedMinReturn) &&
                        (balance1After >=
                            balance1Before - rebalanceParams_.swap.amountIn),
                    "SF"
                );
                balance0After = balance0After - balance0Before;
                balance1After = balance1Before - balance1After;
            }
            emit LogRebalance(rebalanceParams_, balance0After, balance1After);
        } else {
            emit LogRebalance(rebalanceParams_, 0, 0);
        }

        // Mints.
        for (uint256 i; i < rebalanceParams_.mints.length; i++) {
            (bool exists, ) = Position.rangeExists(
                arrakisStorage.ranges,
                rebalanceParams_.mints[i].range
            );
            address pool = mFactory.getPool(
                address(rebalanceLocalVars.token0),
                address(rebalanceLocalVars.token1),
                rebalanceParams_.mints[i].range.feeTier
            );
            if (!exists) {
                // check that the pool exists on Uniswap V3.

                require(pool != address(0), "NUP");
                require(arrakisStorage.pools.contains(pool), "P");
                require(
                    Pool.validateTickSpacing(
                        pool,
                        rebalanceParams_.mints[i].range
                    ),
                    "RTS"
                );

                arrakisStorage.ranges.push(rebalanceParams_.mints[i].range);
            }

            (uint256 amt0, uint256 amt1) = IUniswapV3Pool(pool).mint(
                address(this),
                rebalanceParams_.mints[i].range.lowerTick,
                rebalanceParams_.mints[i].range.upperTick,
                rebalanceParams_.mints[i].liquidity,
                ""
            );
            rebalanceLocalVars.aggregator0 += amt0;
            rebalanceLocalVars.aggregator1 += amt1;
        }
        require(
            rebalanceLocalVars.aggregator0 >= rebalanceParams_.minDeposit0,
            "D0"
        );
        require(
            rebalanceLocalVars.aggregator1 >= rebalanceParams_.minDeposit1,
            "D1"
        );

        require(
            arrakisStorage.token0.balanceOf(address(this)) >=
                arrakisStorage.managerBalance0,
            "MB0"
        );
        require(
            arrakisStorage.token1.balanceOf(address(this)) >=
                arrakisStorage.managerBalance1,
            "MB1"
        );
    }

    function collectFeesOnPools() external {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        uint256 fees0;
        uint256 fees1;
        for (uint256 i; i < arrakisStorage.ranges.length; i++) {
            Range memory range = arrakisStorage.ranges[i];
            IUniswapV3Pool pool = IUniswapV3Pool(
                arrakisStorage.factory.getPool(
                    address(arrakisStorage.token0),
                    address(arrakisStorage.token1),
                    range.feeTier
                )
            );

            /// @dev to update the position and collect fees.
            pool.burn(range.lowerTick, range.upperTick, 0);

            (uint256 collect0, uint256 collect1) = _collectFees(
                pool,
                range.lowerTick,
                range.upperTick
            );

            fees0 += collect0;
            fees1 += collect1;
        }

        _applyFees(fees0, fees1);
        emit LogCollectedFees(fees0, fees1);
    }

    function _withdraw(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity_
    ) internal returns (Withdraw memory withdraw) {
        (withdraw.burn0, withdraw.burn1) = pool_.burn(
            lowerTick_,
            upperTick_,
            liquidity_
        );

        (uint256 collect0, uint256 collect1) = _collectFees(
            pool_,
            lowerTick_,
            upperTick_
        );

        withdraw.fee0 = collect0 - withdraw.burn0;
        withdraw.fee1 = collect1 - withdraw.burn1;
    }

    function _applyFees(uint256 fee0_, uint256 fee1_) internal {
        ArrakisStorage storage arrakisStorage = ArrakisStorageLib.getStorage();

        uint16 mManagerFeeBPS = arrakisStorage.managerFeeBPS;
        arrakisStorage.managerBalance0 +=
            (fee0_ * mManagerFeeBPS) /
            hundredPercent;
        arrakisStorage.managerBalance1 +=
            (fee1_ * mManagerFeeBPS) /
            hundredPercent;
    }

    function _collectFees(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_
    ) internal returns (uint256 collect0, uint256 collect1) {
        (collect0, collect1) = pool_.collect(
            address(this),
            lowerTick_,
            upperTick_,
            type(uint128).max,
            type(uint128).max
        );
    }
}
