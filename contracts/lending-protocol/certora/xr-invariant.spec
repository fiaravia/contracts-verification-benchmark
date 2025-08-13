rule xr_invariant(address t) {
    env e;
    method f;
    calldataarg args;

    require (currentContract.isValidToken(e, t));

    // interests are already accrued
    require (e.block.number == currentContract.lastTotAccrued[t]);

    uint old_xr = currentContract.XR(e, t);

    f(e, args);

    uint new_xr = currentContract.XR(e, t);
    
    assert (
        // TODO: add other selectors
        f.selector == sig:deposit(uint, address).selector 
        => new_xr == old_xr); 
}