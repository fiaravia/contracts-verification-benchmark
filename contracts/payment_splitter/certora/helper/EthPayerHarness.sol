// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EthPayerHarness {
    function pay(address payable to, uint256 amt) external payable {
        require(msg.value >= amt, "need >= amt");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "receiver rejected ETH");
    }

    function hasCode(address a) external view returns (bool) {
        return a.code.length > 0;
    }
}