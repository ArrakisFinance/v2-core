// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FullMath} from "./vendor/uniswap/LiquidityAmounts.sol";
import {VaultV2Storage} from "./abstract/VaultV2Storage.sol";
import {
    Rebalance,
    Withdraw,
    UnderlyingPayload,
    BurnLiquidity,
    UnderlyingOutput,
    Range
} from "./structs/SVaultV2.sol";
import {Twap} from "./libraries/Twap.sol";
import {Underlying as UnderlyingHelper} from "./libraries/Underlying.sol";
import {UniswapV3Amounts} from "./libraries/UniswapV3Amounts.sol";
import {_liquidityZeroError, _poolError} from "./errors/EVaultV2.sol";

contract VaultV2 is
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback,
    VaultV2Storage
{
    using SafeERC20 for IERC20;
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

    event LPBurned(
        address user,
        uint256 burnAmount0,
        uint256 burnAmount1
    );

    event FeesEarned(uint256 fee0, uint256 fee1);
    event FeesEarnedRebalance(uint256 fee0, uint256 fee1);

    event WithdrawManagerBalance(uint256 amount0, uint256 amount1);
    event WithdrawArrakisBalance(uint256 amount0, uint256 amount1);

    // solhint-disable-next-line no-empty-blocks
    constructor(IUniswapV3Factory factory_, address arrakisTreasury_) 
        VaultV2Storage(factory_, arrakisTreasury_) 
    {}

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(
        uint256 amount0Owed_,
        uint256 amount1Owed_,
        bytes calldata /*_data*/
    ) external override {
        require(_pools.contains(msg.sender), "callback caller");

        if (amount0Owed_ > 0) token0.safeTransfer(msg.sender, amount0Owed_);
        if (amount1Owed_ > 0) token1.safeTransfer(msg.sender, amount1Owed_);
    }

    /// @notice Uniswap v3 callback fn, called back on pool.swap
    function uniswapV3SwapCallback(
        int256 amount0Delta_,
        int256 amount1Delta_,
        bytes calldata /*data*/
    ) external override {
        require(_pools.contains(msg.sender), "callback caller");

        if (amount0Delta_ > 0)
            token0.safeTransferFrom(_owner, msg.sender, uint256(amount0Delta_));
        else if (amount1Delta_ > 0)
            token1.safeTransferFrom(_owner, msg.sender, uint256(amount1Delta_));
    }

    function mint(uint256 mintAmount_, address receiver_)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(
            restrictedMintToggle != 11111 || msg.sender == address(manager),
            "restricted"
        );
        require(mintAmount_ > 0, "mint amount");
        uint256 totalSupply = totalSupply();
        (
            uint256 current0,
            uint256 current1,
            uint256 fee0,
            uint256 fee1
        ) = totalSupply > 0
                ? UnderlyingHelper.totalUnderlyingWithFees(
                    UnderlyingPayload({
                        ranges: ranges,
                        factory: factory,
                        token0: address(token0),
                        token1: address(token1),
                        self: address(this)
                    })
                )
                : (init0, init1, 0, 0);
        uint256 denominator = totalSupply > 0 ? totalSupply : 1 ether;
        amount0 = FullMath.mulDivRoundingUp(mintAmount_, current0, denominator);
        amount1 = FullMath.mulDivRoundingUp(mintAmount_, current1, denominator);

        _mint(receiver_, mintAmount_);

        // transfer amounts owed to contract
        if (amount0 > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amount1);
        }

        emit FeesEarned(fee0, fee1);
        emit Minted(receiver_, mintAmount_, amount0, amount1);
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function burn(
        BurnLiquidity[] calldata burns,
        uint256 burnAmount_,
        address receiver_
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        uint256 totalSupply = totalSupply();
        require(totalSupply > 0, "total supply");
        
        UnderlyingOutput memory underlying;
        (
            underlying.amount0,
            underlying.amount1,
            underlying.fee0,
            underlying.fee1
        ) = UnderlyingHelper.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: ranges,
                factory: factory,
                token0: address(token0),
                token1: address(token1),
                self: address(this)
            })
        );
        underlying.leftOver0 = token0.balanceOf(address(this));
        underlying.leftOver1 = token1.balanceOf(address(this));

        {
            {
                (uint256 fee0, uint256 fee1) = UniswapV3Amounts
                    .subtractAdminFees(
                        underlying.fee0,
                        underlying.fee1,
                        manager.managerFeeBPS(),
                        arrakisFeeBPS
                    );
                underlying.amount0 -= underlying.fee0 - fee0;
                underlying.amount1 -= underlying.fee1 - fee1;
            }

            // the proportion of user balance.
            amount0 = FullMath.mulDiv(
                underlying.amount0,
                burnAmount_,
                totalSupply
            );
            amount1 = FullMath.mulDiv(
                underlying.amount1,
                burnAmount_,
                totalSupply
            );
        }

        if (
            underlying.leftOver0 >= amount0 && underlying.leftOver1 >= amount1
        ) {
            _burn(msg.sender, burnAmount_);

            if (amount0 > 0) {
                token0.safeTransfer(receiver_, amount0);
            }

            if (amount1 > 0) {
                token1.safeTransfer(receiver_, amount1);
            }

            emit Burned(receiver_, burnAmount_, amount0, amount1);
            return (amount0, amount1);
        }

        // not at the begining of the function
        require(burns.length > 0, "burns");

        _burn(msg.sender, burnAmount_);

        Withdraw memory total;
        {
            for (uint256 i = 0; i < burns.length; i++) {
                if (burns[i].liquidity == 0) _liquidityZeroError(burns[i]);

                address pool = factory.getPool(
                    address(token0),
                    address(token1),
                    burns[i].range.feeTier
                );

                if (!_pools.contains(pool)) _poolError(burns[i].range.feeTier);

                Withdraw memory withdraw = _withdraw(
                    IUniswapV3Pool(pool),
                    burns[i].range.lowerTick,
                    burns[i].range.upperTick,
                    burns[i].liquidity
                );

                total.fee0 += withdraw.fee0;
                total.fee1 += withdraw.fee1;

                total.burn0 += withdraw.burn0;
                total.burn1 += withdraw.burn1;
            }

            _applyFees(total.fee0, total.fee1);
            (total.fee0, total.fee1) = UniswapV3Amounts.subtractAdminFees(
                total.fee0,
                total.fee1,
                manager.managerFeeBPS(),
                arrakisFeeBPS
            );
        }

        if (amount0 > 0) {
            token0.safeTransfer(receiver_, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(receiver_, amount1);
        }

        // For monitoring how much user burn LP token for getting their token back.
        emit LPBurned(msg.sender, total.burn0, total.burn1);

        emit FeesEarned(total.fee0, total.fee1);
        emit Burned(receiver_, burnAmount_, amount0, amount1);
    }

    function rebalance(
        Range[] calldata ranges_,
        Rebalance calldata rebalanceParams_,
        Range[] calldata rangesToRemove_
    )
        external
        onlyManager
    {
        _addRanges(ranges_, address(token0), address(token1));
        _rebalance(rebalanceParams_);
        _removeRanges(rangesToRemove_);
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function _rebalance(Rebalance calldata rebalanceParams_)
        internal
        nonReentrant
    {
        // Burns
        uint256 totalFee0 = 0;
        uint256 totalFee1 = 0;
        for (uint256 i = 0; i < rebalanceParams_.removes.length; i++) {
            address poolAddr = factory.getPool(
                address(token0),
                address(token1),
                rebalanceParams_.removes[i].range.feeTier
            );
            IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
            if (!_pools.contains(poolAddr))
                _poolError(rebalanceParams_.removes[i].range.feeTier);

            Twap.checkDeviation(pool, twapDuration, maxTwapDeviation);

            Withdraw memory withdraw = _withdraw(
                pool,
                rebalanceParams_.removes[i].range.lowerTick,
                rebalanceParams_.removes[i].range.upperTick,
                rebalanceParams_.removes[i].liquidity
            );

            totalFee0 += withdraw.fee0;
            totalFee1 += withdraw.fee1;
        }

        if (totalFee0 > 0 || totalFee1 > 0) {
            _applyFees(totalFee0, totalFee1);
            (totalFee0, totalFee1) = UniswapV3Amounts.subtractAdminFees(
                totalFee0,
                totalFee1,
                manager.managerFeeBPS(),
                arrakisFeeBPS
            );

            emit FeesEarnedRebalance(totalFee0, totalFee1);
        }

        // Swap

        if (rebalanceParams_.swap.amountIn > 0) {
            {
                require(!_pools.contains(rebalanceParams_.swap.pool), "no pool");

                uint256 balance0Before = token0.balanceOf(address(this));
                uint256 balance1Before = token1.balanceOf(address(this));

                token0.safeApprove(address(rebalanceParams_.swap.router), 0);
                token1.safeApprove(address(rebalanceParams_.swap.router), 0);

                token0.safeApprove(address(rebalanceParams_.swap.router), balance0Before);
                token1.safeApprove(address(rebalanceParams_.swap.router), balance1Before);

                (bool success, ) = rebalanceParams_.swap.router.call(
                    rebalanceParams_.swap.payload
                );
                require(success, "swap");

                token0.safeApprove(address(rebalanceParams_.swap.router), 0);
                token1.safeApprove(address(rebalanceParams_.swap.router), 0);

                uint256 balance0After = token0.balanceOf(address(this));
                uint256 balance1After = token1.balanceOf(address(this));

                uint8 token0Decimals = ERC20(address(token0)).decimals();
                uint8 token1Decimals = ERC20(address(token1)).decimals();
                if (rebalanceParams_.swap.zeroForOne) {
                    require(
                        FullMath.mulDiv(
                            rebalanceParams_.swap.expectedMinReturn,
                            10**token0Decimals,
                            rebalanceParams_.swap.amountIn
                        ) > FullMath.mulDiv(
                            Twap.getPrice0(
                                IUniswapV3Pool(rebalanceParams_.swap.pool),
                                twapDuration
                            ),
                            maxSlippage,
                            10000
                        ),
                        "slippage"
                    );
                    require(
                        (balance1After >=
                            balance1Before +
                                rebalanceParams_.swap.expectedMinReturn) &&
                            (balance0After ==
                                balance0Before -
                                    rebalanceParams_.swap.amountIn),
                        "swap failed"
                    );
                }
                else {
                    require(
                        FullMath.mulDiv(
                            rebalanceParams_.swap.expectedMinReturn,
                            10**token1Decimals,
                            rebalanceParams_.swap.amountIn
                        ) > FullMath.mulDiv(
                            Twap.getPrice1(
                                IUniswapV3Pool(rebalanceParams_.swap.pool),
                                twapDuration
                            ),
                            maxSlippage,
                            10000
                        ),
                        "slippage"
                    );
                    require(
                        (balance0After >=
                            balance0Before +
                                rebalanceParams_.swap.expectedMinReturn) &&
                            (balance1After ==
                                balance1Before -
                                    rebalanceParams_.swap.amountIn),
                        "swap failed"
                    );
                }
            }
        }

        // Mints.
        for (uint256 i = 0; i < rebalanceParams_.deposits.length; i++) {
            IUniswapV3Pool pool = IUniswapV3Pool(
                factory.getPool(
                    address(token0),
                    address(token1),
                    rebalanceParams_.deposits[i].range.feeTier
                )
            );

            (bool exist, ) = rangeExist(rebalanceParams_.deposits[i].range);
            require(exist, "not range");

            Twap.checkDeviation(pool, twapDuration, maxTwapDeviation);

            pool.mint(
                address(this),
                rebalanceParams_.deposits[i].range.lowerTick,
                rebalanceParams_.deposits[i].range.upperTick,
                rebalanceParams_.deposits[i].liquidity,
                ""
            );
        }
    }

    function withdrawManagerBalance() external {
        uint256 amount0 = managerBalance0;
        uint256 amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(address(manager), amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(address(manager), amount1);
        }

        emit WithdrawManagerBalance(amount0, amount1);
    }

    function withdrawArrakisBalance() external {
        uint256 amount0 = arrakisBalance0;
        uint256 amount1 = arrakisBalance1;

        arrakisBalance0 = 0;
        arrakisBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(arrakisTreasury, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(arrakisTreasury, amount1);
        }

        emit WithdrawArrakisBalance(amount0, amount1);
    }

    function _withdraw(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity_
    ) internal returns (Withdraw memory withdraw) {
        uint256 preBalance0 = token0.balanceOf(address(this));
        uint256 preBalance1 = token1.balanceOf(address(this));

        (withdraw.burn0, withdraw.burn1) = pool_.burn(
            lowerTick_,
            upperTick_,
            liquidity_
        );

        pool_.collect(
            address(this),
            lowerTick_,
            upperTick_,
            type(uint128).max,
            type(uint128).max
        );

        withdraw.fee0 =
            token0.balanceOf(address(this)) -
            preBalance0 -
            withdraw.burn0;
        withdraw.fee1 =
            token1.balanceOf(address(this)) -
            preBalance1 -
            withdraw.burn1;
    }

    function _applyFees(uint256 fee0_, uint256 fee1_) internal {
        uint16 managerFeeBPS = manager.managerFeeBPS();
        managerBalance0 += (fee0_ * managerFeeBPS) / 10000;
        managerBalance1 += (fee1_ * managerFeeBPS) / 10000;
        arrakisBalance0 += (fee0_ * arrakisFeeBPS) / 10000;
        arrakisBalance1 += (fee1_ * arrakisFeeBPS) / 10000;
    }
}
