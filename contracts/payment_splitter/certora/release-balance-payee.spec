import "helper/methods.spec";

rule release_balance_payee {
    env e;
    uint idx;
    address a = getPayee(idx);
    uint amt = releasable(a);

    require e.msg.value == 0;
    require idx < getPayeesLength();
    require a != currentContract;
    require getShares(a) > 0;
    require getTotalShares(e) > 0;
    require amt > 0;

    uint bal_before_a = nativeBalances[a];

    release(e, a);

    uint bal_after_a = nativeBalances[a];

    assert bal_before_a + amt == bal_after_a;
}