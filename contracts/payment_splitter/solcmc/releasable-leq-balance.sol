// releasable-balance-check invariant
function invariant(uint index) public view {
    require(index < payees.length, "Index out of bounds");
    assert(releasable(payees[index]) <= address(this).balance);
}
