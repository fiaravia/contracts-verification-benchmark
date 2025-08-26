//SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

/// @custom:version `join` and `win` use (broken) balance invariants as guards for state transitions

contract PriceBet {
    uint256 initial_pot;        // pot transferred from the owner to the contract
    uint256 deadline;           // a time limit after which the player loses the bet
    uint256 exchange_rate;      // target exchange rate that must be reached in order for the player to win the bet.      
    address oracle;             // contract queried for the exchange rate between two given tokens
    address payable owner;
    address payable player;

    // workaround for bug in solc v0.8.30
    address constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);

    constructor(address _oracle, uint256 _timeout, uint256 _exchange_rate) payable {
        require (msg.value > 0);
        initial_pot = msg.value;
        owner = payable(msg.sender);
        oracle = _oracle;
        deadline = block.number + _timeout;
        exchange_rate = _exchange_rate;
    }

    // join allows a player to join the bet. This requires the player to deposit an amount of ETH equal to the initial pot.
    function join() public payable {
        require(address(this).balance == 2*initial_pot, "Player already joined");
        require(msg.sender != ZERO_ADDRESS, "Sender cannot be the zero address");

        // we require that join can only be performed before the deadline
        require(block.number < deadline, "Bet has timed out");

        player = payable(msg.sender);
    }

    // win allows the joined player to withdraw the whole contract balance if the oracle exchange rate is greater than the bet rate. 
    // win can be called multiple times before the deadline. This action is disabled after the deadline
    function win() public {
        require(block.number < deadline, "Bet has timed out");
        require(address(this).balance == 2*initial_pot, "Player has not joined yet");
        // Warning: at deployment time, we cannot know for sure that address oracle actually contains a deployment of contract Oracle
        Oracle oracle_instance = Oracle(oracle);
        require(oracle_instance.get_exchange_rate() >= exchange_rate);

        (bool success, ) = player.call{value: address(this).balance}("");
        require(success);
    }

    // timeout can be called by anyone after the deadline, and transfers the whole contract balance to the owner
    function timeout() public {
        require(block.number >= deadline, "Bet has not timed out yet");

        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success);
    }
}

contract Oracle {
    address owner;
    uint exchange_rate;

    constructor(uint init_rate) {
        owner = msg.sender;
        exchange_rate = init_rate;
    }

    function get_exchange_rate() public view returns(uint) {
        return exchange_rate;
    }

    function set_exchange_rate(uint new_rate) public {
        require(msg.sender == owner);
        exchange_rate = new_rate;
    }
}