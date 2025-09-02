import "helper/methods.spec";

rule release_not_revert {
    env e;
    uint idx;
    address a = getPayee(idx);

    require e.msg.value == 0;
    require idx < getPayeesLength();
    require getShares(a) > 0;
    require getTotalShares(e) > 0;
    require releasable(a) > 0;

    release@withrevert(e, a);
    assert !lastReverted;
}