// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ArrakisVaultV2Storage} from "./abstract/ArrakisVaultV2Storage.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FullMath} from "./vendor/uniswap/FullMath.sol";
import {IArrakisPosition} from "./interfaces/IArrakisPosition.sol";

contract ArrakisVaultV2 is ArrakisVaultV2Storage {
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

    event Rebalance(); // TODO: what data to log here

    event ManagerWithdrawal(uint256 amount0, uint256 amount1);

    modifier onlyOperators() {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        require(
            internalData._operators.contains(msg.sender),
            "ArrakisVaultV2: only operators"
        );
        _;
    }

    /// @notice mint ArrakisVaultV2 Shares by supplying underlying assets
    /// @dev to compute the amount of tokens necessary to mint `mintAmount` see mintAmounts
    /// @param mintAmount amount of shares to mint
    /// @param receiver account to receive the minted shares
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    // solhint-disable-next-line function-max-lines, code-complexity
    function mint(uint256 mintAmount, address receiver)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 totalSupply = totalSupply();
        (uint256 current0, uint256 current1) =
            totalSupply > 0 ? underlying() : _initialRatio();
        uint256 denominator = totalSupply > 0 ? totalSupply : 1 ether;
        amount0 = FullMath.mulDivRoundingUp(mintAmount, current0, denominator);
        amount1 = FullMath.mulDivRoundingUp(mintAmount, current1, denominator);

        require(mintAmount > 0, "ArrakisVaultV2: mint 0");

        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();
        // transfer amounts owed to contract
        if (amount0 > 0) {
            publicData.token0.safeTransferFrom(
                msg.sender,
                address(this),
                amount0
            );
        }
        if (amount1 > 0) {
            publicData.token1.safeTransferFrom(
                msg.sender,
                address(this),
                amount1
            );
        }

        for (uint256 i = 0; i < internalData._positions.length(); i++) {
            (bool success, ) =
                internalData._positions.at(i).delegatecall(
                    abi.encodeWithSelector(
                        IArrakisPosition.deposit.selector,
                        mintAmount,
                        denominator
                    )
                );
            require(success, "ArrakisVaultV2: low level delegatecall failed");
        }

        _mint(receiver, mintAmount);
        emit Minted(receiver, mintAmount, amount0, amount1);
    }

    /// @notice burn ArrakisVaultV2 Shares and receive underlying assets
    /// @param burnAmount number of shares to burn
    /// @param receiver account to receive the underlying amounts of token0 and token1
    /// @return amount0 amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 amount of token1 transferred to receiver for burning `burnAmount`
    // solhint-disable-next-line function-max-lines
    function burn(uint256 burnAmount, address receiver)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(burnAmount > 0, "ArrakisVaultV2: burn 0");

        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        uint256 totalSupply = totalSupply();
        amount0 = FullMath.mulDiv(
            publicData.token0.balanceOf(address(this)),
            burnAmount,
            totalSupply
        );
        amount1 = FullMath.mulDiv(
            publicData.token1.balanceOf(address(this)),
            burnAmount,
            totalSupply
        );

        uint256 feeCollected0;
        uint256 feeCollected1;
        for (uint256 i = 0; i < internalData._positions.length(); i++) {
            (bool success, bytes memory data) =
                internalData._positions.at(i).delegatecall(
                    abi.encodeWithSelector(
                        IArrakisPosition.withdraw.selector,
                        burnAmount,
                        totalSupply
                    )
                );
            require(success, "ArrakisVaultV2: low level delegatecall failed");
            (uint256 credit0, uint256 credit1, uint256 fee0, uint256 fee1) =
                abi.decode(data, (uint256, uint256, uint256, uint256));
            amount0 += credit0;
            amount1 += credit1;
            feeCollected0 += fee0;
            feeCollected1 += fee1;
        }
        publicData.managerBalance0 += feeCollected0;
        publicData.managerBalance1 += feeCollected1;

        _burn(msg.sender, burnAmount);

        if (amount0 > 0) {
            publicData.token0.safeTransfer(receiver, amount0);
        }

        if (amount1 > 0) {
            publicData.token1.safeTransfer(receiver, amount1);
        }

        emit Burned(receiver, burnAmount, amount0, amount1);
    }

    function rebalance(address[] calldata targets, bytes[] calldata payloads)
        external
        nonReentrant
        onlyOperators
    {
        require(
            targets.length == payloads.length,
            "ArrakisVaultV2: array mismatch"
        );

        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        for (uint256 i = 0; i < targets.length; i++) {
            if (internalData._positions.contains(targets[i])) {
                (bool success, ) = targets[i].delegatecall(payloads[i]);
                require(
                    success,
                    "ArrakisVaultV2: low level delegatecall failed"
                );
            } else if (internalData._targets.contains(targets[i])) {
                (bool success, ) = targets[i].call(payloads[i]);
                require(success, "ArrakisVaultV2: low level call failed");
            } else {
                revert("ArrakisVaultV2: only authorized targets");
            }
        }

        emit Rebalance();
    }

    function managerWithdrawal() external nonReentrant {
        VaultV2PublicStorage storage publicData = _vaultV2PublicStorage();

        uint256 amount0 = publicData.managerBalance0;
        uint256 amount1 = publicData.managerBalance1;
        publicData.managerBalance0 = 0;
        publicData.managerBalance1 = 0;
        if (amount0 > 0) {
            publicData.token0.safeTransfer(publicData.managerTreasury, amount0);
        }
        if (amount1 > 0) {
            publicData.token1.safeTransfer(publicData.managerTreasury, amount1);
        }
        emit ManagerWithdrawal(amount0, amount1);
    }

    /// @notice this function is not marked view because of internal delegatecalls
    /// but it should be staticcalled from off chain
    function mintAmounts(uint256 amount0Max, uint256 amount1Max)
        public
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 mintAmount
        )
    {
        uint256 totalSupply = totalSupply();
        (uint256 current0, uint256 current1) =
            totalSupply > 0 ? underlying() : _initialRatio();

        return
            _computeMintAmounts(
                current0,
                current1,
                totalSupply > 0 ? totalSupply : 1 ether,
                amount0Max,
                amount1Max
            );
    }

    /// @notice this function is not marked view because of internal delegatecalls
    /// but it should be staticcalled from off chain
    function underlying() public returns (uint256 amount0, uint256 amount1) {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        for (uint256 i = 0; i < internalData._positions.length(); i++) {
            (bool success, bytes memory data) =
                internalData._positions.at(i).delegatecall(
                    abi.encodeWithSelector(IArrakisPosition.underlying.selector)
                );
            require(success, "ArrakisVaultV2: low level delegatecall failed");
            (uint256 val0, uint256 val1) = abi.decode(data, (uint256, uint256));
            amount0 += val0;
            amount1 += val1;
        }
    }

    /// @notice this function is not marked view because of internal delegatecalls
    /// but it should be staticcalled from off chain
    function underlyingAtPrice(uint160 sqrtRatioX96)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        for (uint256 i = 0; i < internalData._positions.length(); i++) {
            (bool success, bytes memory data) =
                internalData._positions.at(i).delegatecall(
                    abi.encodeWithSelector(
                        IArrakisPosition.underlyingAtPrice.selector,
                        sqrtRatioX96
                    )
                );
            require(success, "ArrakisVaultV2: low level delegatecall failed");
            (uint256 val0, uint256 val1) = abi.decode(data, (uint256, uint256));
            amount0 += val0;
            amount1 += val1;
        }
    }

    function _initialRatio()
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        VaultV2InternalStorage storage internalData = _vaultV2InternalStorage();

        for (uint256 i = 0; i < internalData._positions.length(); i++) {
            (bool success, bytes memory data) =
                internalData._positions.at(i).delegatecall(
                    abi.encodeWithSelector(
                        IArrakisPosition.initialRatio.selector
                    )
                );
            require(success, "ArrakisVaultV2: low level delegatecall failed");
            (uint256 val0, uint256 val1) = abi.decode(data, (uint256, uint256));
            amount0 += val0;
            amount1 += val1;
        }
    }

    // solhint-disable-next-line function-max-lines, code-complexity
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
}
