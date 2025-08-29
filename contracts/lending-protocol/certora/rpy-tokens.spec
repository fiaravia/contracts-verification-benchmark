// SPDX-License-Identifier: GPL-3.0-only

methods {
  // force the proper execution of the transfer() and transferFrom() functions
  // avoids HAVOC values
  function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
  function _.transfer(address,uint256) external => DISPATCHER(true);
}

rule rpy_tokens {
    env e;
    address t;
    address a;
    uint amt;
    
    require(a != currentContract);

    require(e.msg.sender == a);

    // xor over the two tokens of the contract
    require t == currentContract.tok0(e) || t == currentContract.tok1(e);
    require !(t == currentContract.tok0(e) && t == currentContract.tok1(e));
    require (t == currentContract.tok0(e)) != (t == currentContract.tok1(e));

    require(currentContract.tok0(e) == t); // t0 is IERC20; its functions can be used with t

    require(amt > 0);
    require(t.allowance(e, a,currentContract) >= amt);

    uint old_lp_bal = t.balanceOf(e, currentContract);
    uint old_a_bal = t.balanceOf(e, a);

    require(old_a_bal >= amt);
    uint old_res = currentContract.reserves[t];

    repay(e, amt, t);

    uint new_lp_bal = t.balanceOf(e, currentContract);
    uint new_a_bal = t.balanceOf(e, a);
    uint new_res = currentContract.reserves[t];

    assert(new_lp_bal == old_lp_bal + amt);
    assert(new_a_bal  == old_a_bal  - amt);

    assert(new_res == old_res + amt);
}
