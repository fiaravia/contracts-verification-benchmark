import "helper/methods.spec";
import "helper/invariants.spec";

invariant fair_split (uint index)
    
    index < currentContract.getPayeesLength() => 
    
    getReleased(currentContract.payees[index]) <= (
        (getBalance() + currentContract.totalReleased) * 
        currentContract.shares[currentContract.payees[index]] /
        currentContract.totalShares
    ) 
    {
        preserved {
            requireInvariant shares_sum_eq_totalShares();
            requireInvariant released_sum_totalReleased();
            requireInvariant payee_shares_gt_zero();
        }
    }