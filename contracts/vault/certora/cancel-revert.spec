// SPDX-License-Identifier: GPL-3.0-only

// a transaction cancel() aborts if: 
// 1) the signer uses a key different from the recovery key, or
// 2) the state is not REQ.

rule cancel_revert {
    env e;

    require 
        e.msg.sender != currentContract.recovery ||
        currentContract.state != Vault.States.REQ;

    cancel@withrevert(e);
    assert lastReverted;
}
