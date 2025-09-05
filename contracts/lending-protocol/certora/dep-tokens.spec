// SPDX-License-Identifier: GPL-3.0-only

// import "erc20.spec";
methods {
  // force the proper execution of the transfer() and transferFrom() functions
  // avoids HAVOC values
  function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
  function _.transfer(address,uint256) external => DISPATCHER(true);
}

rule dep_tokens {
    env e;
    address t;
    address a;
    uint amt;
    
    require(a != currentContract);

    require(e.msg.sender == a);
    require(currentContract.isValidToken(e, t));

    // xor over the two tokens of the contract
    require t == currentContract.tok0(e) || t == currentContract.tok1(e);
    require !(t == currentContract.tok0(e) && t == currentContract.tok1(e));
    require (t == currentContract.tok0(e)) != (t == currentContract.tok1(e));

    require(amt > 0);
    require(t.allowance(e, a,currentContract) >= amt);

    uint old_lp_bal = t.balanceOf(e, currentContract);
    uint old_a_bal = t.balanceOf(e, a);

    require(old_a_bal >= amt);
    uint old_res = currentContract.reserves[t];

    deposit(e, amt, t);

    uint new_lp_bal = t.balanceOf(e, currentContract);
    uint new_a_bal = t.balanceOf(e, a);
    uint new_res = currentContract.reserves[t];

    assert(new_lp_bal == old_lp_bal + amt);
    assert(new_a_bal  == old_a_bal  - amt);

    assert(new_res == old_res + amt);
}


/*
rule dep_tokens {
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
        
    require (currentContract.reserves[t0] == 0);

    uint old_reserves_t0 = currentContract.reserves[t0];   
    uint old_reserves_t1 = currentContract.reserves[t1];
    uint old_credit_t0_a = currentContract.credit[t0][a];
    uint old_credit_t1_a = currentContract.credit[t1][a];
    uint old_credit_t0_b = currentContract.credit[t0][b];
    uint old_credit_t1_b = currentContract.credit[t1][b];
    uint old_xr_t0 = currentContract.XR(e, t0);

    // uint old_balance_t0_a = currentContract.getTokenBalance(e, t0, a);
    // uint old_balance_t1_a = t1.balanceOf(e, a);

    // uint old_balance_t0_LP = currentContract.getTokenBalance(e, t0, currentContract);
    // uint old_balance_t1_LP = t1.balanceOf(e, currentContract);

    require(old_xr_t0 >= 1000000);

    deposit(e, amt, t0);

    uint new_reserves_t0 = currentContract.reserves[t0];   
    uint new_reserves_t1 = currentContract.reserves[t1];
    uint new_credit_t0_a = currentContract.credit[t0][a];
    uint new_credit_t1_a = currentContract.credit[t1][a];
    uint new_credit_t0_b = currentContract.credit[t0][b];
    uint new_credit_t1_b = currentContract.credit[t1][b];
    uint new_xr_t0 = currentContract.XR(e, t0);

    // uint new_balance_t0_a = t0.balanceOf(e, a);
    // uint new_balance_t1_a = t1.balanceOf(e, a);
    
    // uint new_balance_t0_LP = t0.balanceOf(e, LP);
    // uint new_balance_t0_LP = currentContract.getTokenBalance(e, t0, currentContract);

    // uint new_balance_t1_LP = t1.balanceOf(e, currentContract);

    assert(new_reserves_t0 == old_reserves_t0 + amt);
    assert(new_reserves_t1 == old_reserves_t1);

    // assert(new_balance_t0_a == old_balance_t0_a - amt);
    // assert(new_balance_t1_a == old_balance_t1_a);

    // assert(new_balance_t0_LP == old_balance_t0_LP + amt);
    // assert(new_balance_t1_LP == old_balance_t1_LP);

    assert(new_credit_t0_a == old_credit_t0_a + (amt * 1000000) / old_xr_t0);
    assert(new_xr_t0 >= 1000000);

    assert(new_credit_t1_a == old_credit_t1_a);

    assert(new_credit_t0_b == old_credit_t0_b);
    assert(new_credit_t1_b == old_credit_t1_b);
}
*/