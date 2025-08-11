function invariant(address a, uint amount) public {
    require (a != msg.sender);

    uint old_other_credit = credits[a];
    withdraw(amount);
    uint new_other_credit = credits[a];

    assert (new_other_credit == old_other_credit);
}