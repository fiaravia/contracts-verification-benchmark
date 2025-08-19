function invariant(uint256 index) public view {
    require(index < payees.length);

    address account = payees[index];
    uint256 totalReceived = address(this).balance + totalReleased;
    assert(getReleased(account) <= 
        ((getBalance() + totalReleased)* shares[account] / totalShares));
}
