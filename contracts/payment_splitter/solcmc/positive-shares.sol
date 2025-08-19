//positive-shares invariant
function invariant(uint index) public view {
    require(index < payees.length, "Index out of bounds");
    assert(shares[payees[index]] > 0);
}

