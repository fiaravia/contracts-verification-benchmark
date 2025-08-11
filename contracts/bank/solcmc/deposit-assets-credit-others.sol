function invariant(address a) public payable {
    require (a != msg.sender);

    uint old_other_credit = credits[a];
    deposit();
    uint new_other_credit = credits[a];

    assert (new_other_credit == old_other_credit);
}