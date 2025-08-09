function invariant(address a) public payable {
    require (a != msg.sender);

    uint old_other_balance = a.balance;
    deposit();
    uint new_other_balance = a.balance;

    assert (new_other_balance == old_other_balance);
}