import "helper/methods.spec";
import "helper/invariants.spec";


rule non_zero_payees {
    requireInvariant payee_shares_gt_zero();
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();

    uint index;

    require index < currentContract.getPayeesLength();
    assert currentContract.payees[index] != 0;
}

