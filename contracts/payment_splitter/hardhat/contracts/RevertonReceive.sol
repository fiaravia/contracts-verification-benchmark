pragma solidity ^0.8.0;


contract RevertOnReceive {
    receive() external payable {
        revert("Too much eth");
    }
}