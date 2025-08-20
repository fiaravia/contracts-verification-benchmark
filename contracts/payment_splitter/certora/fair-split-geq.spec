import "helper/methods.spec";
import "helper/invariants.spec";

invariant fair_split_for_v3 (uint index)
    index < getPayeesLength() 
    => 
    getReleased(currentContract.payees[index]) <= (getBalance() + currentContract.totalReleased) / currentContract.getPayeesLength() ;


