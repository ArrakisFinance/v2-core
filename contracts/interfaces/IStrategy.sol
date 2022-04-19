// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

interface IStrategy {
    function deposit(uint256 proportion) external;

    function withdraw(uint256 proportion) external returns (uint256, uint256);

    function managerWithdrawal(address target)
        external
        returns (uint256, uint256);

    function underlyingBalances() external view returns (uint256, uint256);

    function underlyingBalancesAtPrice(uint256 sqrtPrice)
        external
        view
        returns (uint256, uint256);

    function managerBalances() external view returns (uint256, uint256);

    function depositAmounts(uint256 proportion)
        external
        view
        returns (uint256, uint256);
}
