import "helper/methods.spec";

rule release_not_revert {
    env e;
    uint idx;

    require e.msg.value == 0;

    require idx < getPayeesLength();
    address a = getPayee(idx);

    require getShares(a) > 0;
    require getTotalShares(e) > 0;
    require releasable(a) > 0;

    release@withrevert(e, a);
    assert !lastReverted;
}