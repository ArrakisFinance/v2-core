// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {InitializePayload} from "../structs/SArrakisV2.sol";
import {Range, Rebalance} from "../structs/SArrakisV2.sol";

import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IArrakisV2 is IERC20Upgradeable {
    // #region events
    event LogCollectedFees(uint256 fee0, uint256 fee1);
    event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);

    // #region Setting events
    event LogSetInits(uint256 init0, uint256 init1);
    event LogAddPools(uint24[] feeTiers);
    event LogRemovePools(address[] pools);
    event LogSetManager(address newManager);
    event LogSetManagerFeeBPS(uint16 managerFeeBPS);
    event LogWhitelistRouters(address[] routers);
    event LogBlacklistRouters(address[] routers);

    // #endregion Setting events

    // #endregion events

    function initialize(
        string calldata name_,
        string calldata symbol_,
        InitializePayload calldata params_
    ) external;

    // #region state modifiying functions.

    function mint(uint256 mintAmount_, address receiver_)
        external
        returns (uint256 amount0, uint256 amount1);

    function burn(uint256 burnAmount_, address receiver_)
        external
        returns (uint256 amount0, uint256 amount1);

    function rebalance(Rebalance calldata rebalanceParams_) external;

    function withdrawManagerBalance() external;

    function setInits(uint256 init0_, uint256 init1_) external;

    function addPools(uint24[] calldata feeTiers_) external;

    function removePools(address[] calldata pools_) external;

    function whitelistRouters(address[] calldata routers_) external;

    function blacklistRouters(address[] calldata routers_) external;

    function setManager(address manager_) external;

    function setManagerFeeBPS(uint16 managerFeeBPS_) external;

    // #endregion state modifiying functions.

    function token0() external view returns (IERC20);

    function token1() external view returns (IERC20);

    function init0() external view returns (uint256);

    function init1() external view returns (uint256);

    function manager() external view returns (address);

    function managerFeeBPS() external view returns (uint16);

    function managerBalance0() external view returns (uint256);

    function managerBalance1() external view returns (uint256);

    function getRanges() external view returns (Range[] memory);

    function getPools() external view returns (address[] memory);

    function getRouters() external view returns (address[] memory);
}
