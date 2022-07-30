// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IManagerProxy} from "./IManagerProxy.sol";
import {InitializePayload} from "../structs/SVaultV2.sol";
import {Range, Rebalance} from "../structs/SVaultV2.sol";

interface IVaultV2 {
    function initialize(
        string calldata name_,
        string calldata symbol_,
        InitializePayload calldata params_
    ) external;

    // #region state modifiying functions.

    function rebalance(
        Range[] calldata rangesToAdd_,
        Rebalance calldata rebalanceParams_,
        Range[] calldata rangesToRemove_
    ) external;

    // #endregion state modifiying functions.

    function totalSupply() external view returns (uint256);

    function factory() external view returns (IUniswapV3Factory);

    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function init0() external view returns (uint256);

    function init1() external view returns (uint256);

    function rangesLength() external view returns (uint256);

    function rangesArray() external view returns (Range[] memory);

    function arrakisFeeBPS() external view returns (uint16);

    function manager() external view returns (IManagerProxy);

    function twapDuration() external view returns (uint24);
}
