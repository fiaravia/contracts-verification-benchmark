// import "deposit-post.spec";
// import "redeem-post.spec";

// use rule deposit_post;
// use rule redeem_post;

rule xr_invariant(address t) {
    env e;
    method f;
    calldataarg args;

    require (currentContract.isValidToken(e, t));

    // interests are already accrued
    require (currentContract.isInterestAccrued(e, t));

    uint old_xr = currentContract.XR(e, t);

    // tentative requires to make the property hold
    require(e.msg.sender!=currentContract);
    require(old_xr >= 1000000);

    f(e, args);

    uint new_xr = currentContract.XR(e, t);
    uint new_sum_credits = currentContract.sum_credits[t];

    assert(f.selector == sig:deposit(uint, address).selector => new_xr == old_xr);
    assert(f.selector == sig:borrow(uint, address).selector => new_xr == old_xr);
    assert(f.selector == sig:repay(uint, address).selector => new_xr == old_xr);
    assert(f.selector == sig:redeem(uint, address).selector && new_sum_credits > 0 => new_xr == old_xr);
    assert(f.selector == sig:liquidate(uint, address, address, address).selector => new_xr == old_xr); 
}