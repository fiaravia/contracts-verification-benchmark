import "helper/methods.spec";
import "helper/invariants.spec";

invariant fair_split_eq_no_overflow (env e, uint index)
    // released[a] + releasable(a) == (totalReceived * shares[a]) / totalShares

    index < currentContract.getPayeesLength() => // implication excludes non-payees 
    
    getReleased(currentContract.payees[index]) + 
    currentContract.releasable(currentContract.payees[index]) == (
        ((getBalance() + currentContract.totalReleased) * 
        currentContract.getShares(currentContract.payees[index])) /
        currentContract.getTotalShares(e)
    ) 
    {
        preserved {
            requireInvariant shares_sum_eq_totalShares();
            requireInvariant released_sum_totalReleased();
            requireInvariant payee_shares_gt_zero();
            requireInvariant out_of_bounds_payee();
        }
    }
