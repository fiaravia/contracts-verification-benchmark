// SPDX-License-Identifier: GPL-3.0-only

rule tx_idle_req {
    env e;
    method f;
    calldataarg args;

    // property: 
    // state==IDLE => exists a,f : <a:f()> state==REQ 

    // contrapositive:
    // (forall a,f : (<a:f()> state!=REQ)) => state!=IDLE 
    //  forall a,f : ((<a:f()> state!=REQ) => state!=IDLE) 

    Vault.States prev_state = currentContract.state;

    f(e, args);

    Vault.States post_state = currentContract.state;

    assert post_state != Vault.States.REQ => 
           prev_state != Vault.States.IDLE;
}
