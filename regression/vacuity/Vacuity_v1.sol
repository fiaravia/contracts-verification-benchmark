// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Vacuity {
    uint256 public v=0;

    /// This function succeeds only when x == 1; on success sets v = 1.
    function set(uint256 x) external {
        require(x == 1, "only 1 allowed");
        v = x;
    }
}
