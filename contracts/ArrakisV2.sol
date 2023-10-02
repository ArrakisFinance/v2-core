// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV3MintCallback
} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory,
    ArrakisV2Storage,
    IERC20,
    SafeERC20,
    EnumerableSet,
    Range,
    Rebalance
} from "./abstract/ArrakisV2Storage.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {Withdraw, UnderlyingPayload} from "./structs/SArrakisV2.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Invest} from "./libraries/Invest.sol";

/// @title ArrakisV2 LP vault version 2
/// @notice Smart contract managing liquidity providing strategy for a given token pair
/// using multiple Uniswap V3 LP positions on multiple fee tiers.
/// @author Arrakis Finance
/// @dev DO NOT ADD STATE VARIABLES - APPEND THEM TO ArrakisV2Storage
contract ArrakisV2 is IUniswapV3MintCallback, ArrakisV2Storage {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(
        uint256 amount0Owed_,
        uint256 amount1Owed_,
        bytes calldata /*_data*/
    ) external override {
        _uniswapV3CallBack(amount0Owed_, amount1Owed_);
    }

    /// @notice mint Arrakis V2 shares by depositing underlying
    /// @param mintAmount_ represent the amount of Arrakis V2 shares to mint.
    /// @param receiver_ address that will receive Arrakis V2 shares.
    /// @return amount0 amount of token0 needed to mint mintAmount_ of shares.
    /// @return amount1 amount of token1 needed to mint mintAmount_ of shares.
    // solhint-disable-next-line function-max-lines, code-complexity
    function mint(uint256 mintAmount_, address receiver_)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 ts = totalSupply();
        (amount0, amount1) = Invest.mint(mintAmount_, receiver_, ts);
        _mint(receiver_, mintAmount_);
    }

    /// @notice burn Arrakis V2 shares and withdraw underlying.
    /// @param burnAmount_ amount of vault shares to burn.
    /// @param receiver_ address to receive underlying tokens withdrawn.
    /// @return amount0 amount of token0 sent to receiver
    /// @return amount1 amount of token1 sent to receiver
    // solhint-disable-next-line function-max-lines, code-complexity
    function burn(uint256 burnAmount_, address receiver_)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(burnAmount_ > 0, "BA");

        uint256 ts = totalSupply();
        require(ts > 0, "TS");

        _burn(msg.sender, burnAmount_);

        return Invest.burn(burnAmount_, receiver_, ts);
    }

    /// @notice rebalance ArrakisV2 vault's UniswapV3 positions
    /// @param rebalanceParams_ rebalance params, containing ranges where
    /// we need to collect tokens and ranges where we need to mint liquidity.
    /// Also contain swap payload to changes token0/token1 proportion.
    /// @dev only Manager contract can call this function.
    // solhint-disable-next-line function-max-lines, code-complexity
    function rebalance(Rebalance calldata rebalanceParams_)
        external
        onlyManager
        nonReentrant
    {
        Invest.rebalance(rebalanceParams_);
    }

    /// @notice will send manager fees to manager
    /// @dev anyone can call this function
    function withdrawManagerBalance() external nonReentrant {
        _withdrawManagerBalance();
    }
}
