pragma solidity ^0.8.0;


contract ReturnsN {
    uint n;

    constructor(uint _n) payable{
        n = _n;
    }

    receive() external payable {
        (bool success, ) = msg.sender.call{value: n}("");
        require(success, "Failed to send ether");
    }
}