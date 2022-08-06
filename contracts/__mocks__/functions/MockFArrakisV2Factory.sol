// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {_getTokenOrder, _append} from "../../functions/FArrakisV2Factory.sol";

contract MockFArrakisV2Factory {
    function getTokenOrder(address tokenA_, address tokenB_)
        external
        pure
        returns (address token0, address token1)
    {
        return _getTokenOrder(tokenA_, tokenB_);
    }

    function append(
        string memory a_,
        string memory b_,
        string memory c_,
        string memory d_
    ) external pure returns (string memory) {
        return _append(a_, b_, c_, d_);
    }
}
