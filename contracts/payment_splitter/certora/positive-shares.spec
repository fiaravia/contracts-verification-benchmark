import "helper/methods.spec";
import "helper/invariants.spec";

rule positive_shares {
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant payee_shares_gt_zero();
    
    uint index;
    assert getShares(getPayee(index)) > 0;
}