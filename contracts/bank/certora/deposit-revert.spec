// SPDX-License-Identifier: GPL-3.0-only

rule deposit_revert {
    env e;

    mathint prev_credit_sender = currentContract.credits[e.msg.sender];
    // mathint MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    
    deposit@withrevert(e);
    
    assert lastReverted => e.msg.value + prev_credit_sender > max_uint;
}
