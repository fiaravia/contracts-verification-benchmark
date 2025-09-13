// SPDX-License-Identifier: GPL-3.0-only

rule tx_req_idle {
    env e;
    method f;
    calldataarg args;

    // property: 
    // state==REQ => exists a,f : <a:f()> state==IDLE 

    // contrapositive:
    // (forall a,f : (<a:f()> state!=IDLE)) => state!=REQ 
    //  forall a,f : ((<a:f()> state!=IDLE) => state!=REQ) 

    Vault.States prev_state = currentContract.state;

    f(e, args);

    Vault.States post_state = currentContract.state;

    assert post_state != Vault.States.IDLE => 
           prev_state != Vault.States.REQ;
}
