/// @custom:version conforming to specifications

//SPDX-License-Identifier: GPL-3.0-only
pragma solidity >= 0.8.2;

// import "./Oracle.sol";

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

contract Pricebet {
    uint256 initial_pot;
    uint256 deadline;
    uint256 exchange_rate;
    address oracle;
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

    function join() public payable {
        require(msg.value == initial_pot);
        require(player == ZERO_ADDRESS, "Player already joined");
        player = payable(msg.sender);
    }

    function win() public {
        require(block.number < deadline);
        require(msg.sender == player);

        Oracle oracle_instance = Oracle(oracle);
        require(oracle_instance.get_exchange_rate() >= exchange_rate);

        (bool success, ) = player.call{value: address(this).balance}("");
        require(success);
    }

    function timeout() public {
        require(block.number >= deadline);

        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success);
    }

}