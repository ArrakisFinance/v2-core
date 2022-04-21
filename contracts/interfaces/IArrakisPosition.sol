// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

interface IArrakisPosition {
    function deposit(uint256 shares, uint256 total)
        external
        returns (uint256, uint256);

    function withdraw(uint256 shares, uint256 total)
        external
        returns (uint256, uint256);

    function underlying() external view returns (uint256, uint256);

    function initialRatio() external view returns (uint256, uint256);

    function underlyingAtPrice(uint256 sqrtPrice)
        external
        view
        returns (uint256, uint256);
}
