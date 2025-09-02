//release-balance-payee invariant

function invariant(uint index) public {
    require(index < payees.length, "Index out of bounds");
    address payable a = payable(payees[index]);

    uint amt = releasable(a);

    uint balBefore_a = address(a).balance;

    release(a);

    uint balAfter_a = address(a).balance;

    assert(balBefore_a + amt == balAfter_a);
}

