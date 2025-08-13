rule xr_invariant(address t) {
    env e;
    method f;
    calldataarg args;

    // TODO: fix 
    // uint old_xr = currentContract.XR(t);

    require (currentContract.isValidToken(e, t));

    f(e, args);

    uint new_xr = currentContract.XR(e, t);
    assert (new_xr >= 1000000); 
}