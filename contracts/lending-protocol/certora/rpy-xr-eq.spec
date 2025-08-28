// SPDX-License-Identifier: GPL-3.0-only

// import "erc20.spec";


rule rpy_xr_eq {
    env e;
    address t0;
    address t1;
    address a;
    address b;
    uint amt;

    require(a != b && a!=0 && b!=0 && a!=currentContract && b!=currentContract);
    require(t0 != t1);

    require (e.msg.sender == a);
    require (currentContract.isValidToken(e, t0));



    uint old_reserves_t0 = currentContract.reserves[t0];   
    uint old_xr_t0 = currentContract.XR(e, t0);

    uint old_sum_credits_t0 = currentContract.sum_credits[t0];
    uint old_sum_debits_t0 = currentContract.sum_debits[t0];

    mathint old_computed_xr_t0; 
    if (old_sum_credits_t0 == 0) {
        old_computed_xr_t0 = 1000000;
    }
    else {
        old_computed_xr_t0 = ((old_reserves_t0 + old_sum_debits_t0) * 1000000) / old_sum_credits_t0;
    }

    repay(e, amt, t0);

    uint new_reserves_t0 = currentContract.reserves[t0];   
    uint new_xr_t0 = currentContract.XR(e, t0);

    uint new_sum_credits_t0 = currentContract.sum_credits[t0];
    uint new_sum_debits_t0 = currentContract.sum_debits[t0];


    mathint new_computed_xr_t0; 
    
    if (new_sum_credits_t0 == 0) {
        new_computed_xr_t0 = 1000000;
    }
    else {
        new_computed_xr_t0 = ((new_reserves_t0 + new_sum_debits_t0) * 1000000) / new_sum_credits_t0;
    }

    assert(old_xr_t0 == old_computed_xr_t0);
    assert(new_xr_t0 == new_computed_xr_t0);


    // XR should not change on repay
    assert(old_xr_t0 == new_xr_t0);
}