// SPDX-License-Identifier: GPL-3.0-only

// a transaction cancel() does not abort if: 
// 1) the signer uses the recovery key, and
// 2) the state is REQ.

rule cancel_not_revert {
    env e;

    require ( 
        e.msg.sender == currentContract.recovery 
        &&
        currentContract.state == Vault.States.REQ 
        &&
        e.msg.value == 0 // the sender must not transfer any ETH
    ); 

    cancel@withrevert(e);
    assert !lastReverted;
}
