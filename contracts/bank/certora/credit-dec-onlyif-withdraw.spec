// SPDX-License-Identifier: GPL-3.0-only

// if the credit of a user A is decreased after a transaction (of the Bank contract), 
// then that transaction must be a withdraw where A is the sender

rule credit_dec_onlyif_withdraw {
    env e;
    method f;
    calldataarg args;
    address a;

    mathint currb = currentContract.credits[a];
    f(e, args);
    mathint newb = currentContract.credits[a];

    assert (newb < currb => (f.selector == sig:withdraw(uint).selector && e.msg.sender == a));
}
