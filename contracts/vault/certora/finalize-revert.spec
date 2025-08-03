// SPDX-License-Identifier: GPL-3.0-only

// a transaction finalize() aborts if:
// 1) the sender is not the owner, or 
// 2) the state is not REQ, or
// 3) wait_time time units have not elapsed after request_timestamp

rule finalize_revert {
    env e;

    require 
        e.msg.sender != currentContract.owner || 
        currentContract.state != Vault.States.REQ ||
        e.block.number < currentContract.request_time + currentContract.wait_time;

    finalize@withrevert(e);
    assert lastReverted;
}
