// SPDX-License-Identifier: GPL-3.0-only

// in any blockchain state, the owner key and the recovery key cannot be changed after the contract is deployed

rule keys_invariant_global {
    env e;
    method f;
    calldataarg args;

    address old_owner = currentContract.owner;
    address old_recovery = currentContract.recovery;
  
    f(e, args); 
    
    assert currentContract.owner == old_owner && currentContract.recovery == old_recovery;
}
