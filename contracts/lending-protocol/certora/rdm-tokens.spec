// SPDX-License-Identifier: GPL-3.0-only

methods {
  // force the proper execution of the transfer() and transferFrom() functions
  // avoids HAVOC values
  function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
  function _.transfer(address,uint256) external => DISPATCHER(true);
}

rule rdm_tokens {
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

    uint xr = XR(e, t);

    mathint rdm_amt = amt * xr / 1000000;

    require(rdm_amt > 0);

    require(t.allowance(e, currentContract, a) >= rdm_amt);

    uint old_lp_bal = t.balanceOf(e, currentContract);
    uint old_a_bal = t.balanceOf(e, a);

    require(old_lp_bal >= rdm_amt);
    uint old_res = currentContract.reserves[t];

    redeem(e, amt, t);

    uint new_lp_bal = t.balanceOf(e, currentContract);
    uint new_a_bal = t.balanceOf(e, a);
    uint new_res = currentContract.reserves[t];

    assert(new_lp_bal == old_lp_bal - rdm_amt);
    assert(new_a_bal  == old_a_bal  + rdm_amt);
    assert(new_res == old_res - rdm_amt);
}