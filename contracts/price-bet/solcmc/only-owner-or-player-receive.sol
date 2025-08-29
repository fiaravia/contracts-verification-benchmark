/// @custom:ghost
address receiver;
uint receiver_balance_before;

function set_receiver(address a) public {
    receiver = a;
    receiver_balance_before = address(a).balance;
}

function check_receiver() public view {
    require (receiver != address(this));
    require (receiver != owner);
    require (receiver != player);

    assert (address(receiver).balance <= receiver_balance_before);   
}
