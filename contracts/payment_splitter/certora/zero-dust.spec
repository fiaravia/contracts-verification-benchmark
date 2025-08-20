import "helper/methods.spec";
import "helper/invariants.spec";

rule zero_dust {

    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();
    requireInvariant payee_shares_gt_zero();

    assert currentContract.getTotalReleasable() == getBalance();
}
