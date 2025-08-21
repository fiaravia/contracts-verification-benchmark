import "helper/methods.spec";
import "helper/invariants.spec";

invariant fair_split_geq (env e,uint index)(
    index < getPayeesLength() 
    => 

    ((getBalance() + currentContract.totalReleased) * 
    currentContract.getShares(currentContract.payees[index])) /
    currentContract.getTotalShares(e) >= currentContract.getReleased(currentContract.payees[index]))
    {
        preserved {
            requireInvariant shares_sum_eq_totalShares();
            requireInvariant released_sum_totalReleased();
            requireInvariant payee_shares_gt_zero();
        }
    }

