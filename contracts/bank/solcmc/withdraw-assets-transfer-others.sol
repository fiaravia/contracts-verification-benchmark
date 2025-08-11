function invariant(address a, uint amount) public {
    require (a != msg.sender);

    uint old_other_balance = a.balance;
    withdraw(amount);
    uint new_other_balance = a.balance;

    assert (new_other_balance == old_other_balance);
}