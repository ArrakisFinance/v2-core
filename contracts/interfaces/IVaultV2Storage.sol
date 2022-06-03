// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {InitializeParams} from "../structs/SVaultV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Range} from "../structs/SVaultV2.sol";

interface IVaultV2Storage {
    function initialize(
        string calldata name_,
        InitializeParams calldata params_
    ) external virtual;

    function totalSupply() external view virtual returns (uint256);

    function factory() external view virtual returns (IUniswapV3Factory);

    function token0() external view virtual returns (IERC20);

    function token1() external view virtual returns (IERC20);

    function init0() external view virtual returns (uint256);

    function init1() external view virtual returns (uint256);

    function rangesLength() external view virtual returns (uint256);

    function rangesArray() external view returns (Range[] memory);

    function managerFeeBPS() external view virtual returns (uint16);
}
