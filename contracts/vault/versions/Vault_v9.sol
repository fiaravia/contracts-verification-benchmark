// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

/// @custom:version `cancel` updates the recovery key before checking `msg.sender`, and then restores it
contract Vault {
    enum States{IDLE, REQ}

    address owner;
    address recovery;
    uint wait_time;

    address receiver;
    uint request_time;
    uint amount;
    States state;
    
    constructor (address payable recovery_, uint wait_time_) payable {
    	require(msg.sender != recovery_);
        require(wait_time_ > 0);
        owner = msg.sender;
        recovery = recovery_;
        wait_time = wait_time_;
        state = States.IDLE;
    }

    receive() external payable { }

    function withdraw(address receiver_, uint amount_) public {
        require(state == States.IDLE);
        require(amount_ <= address(this).balance);
        require(msg.sender == owner);

        request_time = block.number;
        amount = amount_;
        receiver = receiver_;
        state = States.REQ;
    }

    function finalize() public {
        require(state == States.REQ);
        require(block.number >= request_time + wait_time);
        require(msg.sender == owner);

        state = States.IDLE;	
        (bool succ,) = receiver.call{value: amount}("");
        require(succ);
    }

    function cancel() public {
        require(state == States.REQ);
	address old_recovery = recovery;
	recovery = owner;
        require(msg.sender == recovery);
	recovery = old_recovery;
        state = States.IDLE;
    }
}
