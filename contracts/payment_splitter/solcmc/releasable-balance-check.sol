// releasable-balance-check invariant
function invariant(uint index) public view {
    require(index < payees.length, "Index out of bounds");
    assert(releasable(payees[index]) <= address(this).balance);
}

/*

rule releasable_balance_check {
    
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();
    requireInvariant payee_shares_gt_zero();

    require currentContract.payees.length < 4;

    uint index;

    require index < currentContract.payees.length;

    address payee = currentContract.payees[index];

    
    mathint releasable = releasable(payee);
    mathint balance = getBalance();
    
    assert releasable(payee) <= getBalance();
}

 */