import "helper/methods.spec";
import "helper/invariants.spec";

using EthPayerHarness as harness;


rule release_not_revert_receive {

    env e;
    uint idx;
    address a = getPayee(idx);
    uint amt = releasable(a);

    require e.msg.value == 0;
    require a != currentContract;
    require idx < getPayeesLength();
    require getShares(a) > 0;
    require getTotalShares(e) > 0;
    require amt > 0;

    storage initial = lastStorage;

    harness.pay@withrevert(e, a, amt);
    require(!lastReverted);

    release@withrevert(e, a) at initial;
    assert !lastReverted;
}