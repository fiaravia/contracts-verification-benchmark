import "helper/methods.spec";
import "helper/invariants.spec";


rule swappable_call_order {
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();

    env e;

    uint index1;
    uint index2;

    require index1 != index2;
    
    require index1 < currentContract.getPayeesLength();
    require index2 < currentContract.getPayeesLength();

    address addr1 = currentContract.payees[index1];
    address addr2 = currentContract.payees[index2];

    storage initial = lastStorage;

    release(e, addr1);
    release(e, addr2);
    storage final1 = lastStorage;

    release(e, addr2) at initial;
    release(e, addr1);
    storage final2 = lastStorage;
    assert final1 == final2;
} 