import "helper/methods.spec";
import "helper/invariants.spec";

invariant fair_split_geq_no_overflow (env e,uint index)(
    // (totalReceived * shares[a]) / totalShares >= released[a]

    index < getPayeesLength() &&    
    getPayeesLength() > 0 &&
    ((getBalance() + currentContract.totalReleased) * currentContract.getShares(currentContract.payees[index])) <= max_uint &&  
    currentContract.getTotalShares(e) <= max_uint 
    => 

    ((getBalance() + currentContract.totalReleased) * 
    currentContract.getShares(currentContract.payees[index]))/
    currentContract.getTotalShares(e) >= currentContract.getReleased(currentContract.payees[index]))
    {
        preserved {
            requireInvariant shares_sum_eq_totalShares();
            requireInvariant released_sum_totalReleased();
            requireInvariant payee_shares_gt_zero();
            requireInvariant out_of_bounds_payee();
        }
    }

