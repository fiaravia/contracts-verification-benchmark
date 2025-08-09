function invariant(uint choice, uint u1, address a) public payable {
    uint currb = a.balance;
    if (choice == 0) {
        deposit();
    } else if (choice == 1) {
        withdraw(u1);
    } else {
        require(false);
    }
    uint newb = a.balance;

    require(newb < currb);
    assert(choice == 0);
    assert(msg.sender == a);
}
