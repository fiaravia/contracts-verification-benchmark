// SPDX-License-Identifier: GPL-3.0-only

rule deposit_revert {
    env e;

    // this condition is needed to avoid trivial reverts due to insufficient balance
    require nativeBalances[e.msg.sender] >= e.msg.value; 

    mathint prev_credit_sender = currentContract.credits[e.msg.sender];
    // mathint MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    
    deposit@withrevert(e);
    
    assert lastReverted => e.msg.value + prev_credit_sender > max_uint;
}
