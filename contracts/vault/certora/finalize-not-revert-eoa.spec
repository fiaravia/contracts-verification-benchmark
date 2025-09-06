// SPDX-License-Identifier: GPL-3.0-only

// a finalize() transaction does not abort if:
// 1) it is sent by the owner, 
// 2) in state REQ, and 
// 3) at least wait_time time units have elapsed after request_timestamp

/// @custom:run certoraRun versions/Vault_v1.sol:Vault versions/lib/EOA.sol:EOA --verify Vault:certora/finalize-not-revert-eoa.spec --link Vault:receiver=EOA

rule finalize_not_revert_eoa {
    env e;

    // technical assumptions: the receiver is not the Vault contract itself
    require currentContract.receiver != currentContract;

    // technical assumption: no ETH is sent with the call
    require e.msg.value == 0; // the sender must not transfer any ETH

    require 
        e.msg.sender == currentContract.owner &&
        currentContract.state == Vault.States.REQ &&
        e.block.number >= currentContract.request_time + currentContract.wait_time;

    finalize@withrevert(e);
    assert !lastReverted;
}
