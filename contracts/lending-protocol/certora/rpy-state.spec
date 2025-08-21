// SPDX-License-Identifier: GPL-3.0-only

// import "erc20.spec";

rule rpy_state {
    env e;
    address t0;
    address t1;
    address a;
    address b;
    uint amt;

    require(a != b && a!=0 && b!=0 && a!=currentContract && b!=currentContract);
    require(t0 != t1);

    // require (amt > 0);
    require (e.msg.sender == a);
    require (currentContract.isValidToken(e, t0));

    uint old_block = e.block.number;
    
    // require(isInterestAccrued(e, t0)); 
    //require(currentContract.last_global_update == e.block.number); 

    uint old_reserves_t0 = currentContract.reserves[t0];   
    uint old_reserves_t1 = currentContract.reserves[t1];

    uint old_credit_t0_a = currentContract.credit[t0][a];
    uint old_credit_t1_a = currentContract.credit[t1][a];
    uint old_credit_t0_b = currentContract.credit[t0][b];
    uint old_credit_t1_b = currentContract.credit[t1][b];

    uint old_debit_t0_a = currentContract.getAccruedDebt(e, t0, a);
    uint old_debit_t1_a = currentContract.getAccruedDebt(e, t1, a);
    uint old_debit_t0_b = currentContract.getAccruedDebt(e, t0, b);
    uint old_debit_t1_b = currentContract.getAccruedDebt(e, t1, b);

    uint old_sum_credits_t0 = currentContract.sum_credits[t0];
    uint old_sum_debits_t0 = currentContract.sum_debits[t0];
    uint old_xr_t0 = currentContract.XR(e, t0);
    
    repay@withrevert(e, amt, t0);
    require(!lastReverted);

    uint new_reserves_t0 = currentContract.reserves[t0];   
    uint new_reserves_t1 = currentContract.reserves[t1];

    uint new_credit_t0_a = currentContract.credit[t0][a];
    uint new_credit_t1_a = currentContract.credit[t1][a];
    uint new_credit_t0_b = currentContract.credit[t0][b];
    uint new_credit_t1_b = currentContract.credit[t1][b];
    uint new_xr_t0 = currentContract.XR(e, t0);

    uint new_debit_t0_a = currentContract.getAccruedDebt(e, t0, a);
    uint new_debit_t1_a = currentContract.getAccruedDebt(e, t1, a);
    uint new_debit_t0_b = currentContract.getAccruedDebt(e, t0, b);
    uint new_debit_t1_b = currentContract.getAccruedDebt(e, t1, b);

    uint new_sum_credits_t0 = currentContract.sum_credits[t0];
    uint new_sum_debits_t0 = currentContract.sum_debits[t0];
    
    uint new_block = e.block.number;

    require(new_block == old_block);

    assert(new_reserves_t0 == old_reserves_t0 + amt);
    assert(new_reserves_t1 == old_reserves_t1);

    assert(new_credit_t0_a == old_credit_t0_a);
    assert(new_credit_t1_a == old_credit_t1_a);

    assert(new_credit_t0_b == old_credit_t0_b);
    assert(new_credit_t1_b == old_credit_t1_b);

    //we are not checking the new xr

    assert(new_sum_credits_t0 == old_sum_credits_t0 );
    assert(new_sum_debits_t0 == old_sum_debits_t0 - amt);

    assert(new_debit_t0_a == old_debit_t0_a - amt);
    assert(new_debit_t1_a == old_debit_t1_a);
    assert(new_debit_t0_b == old_debit_t0_b);
    assert(new_debit_t1_b == old_debit_t1_b);
}
