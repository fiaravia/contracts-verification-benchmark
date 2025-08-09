// SPDX-License-Identifier: GPL-3.0-only

// if the credit of a user A is increased after a transaction (of the Bank contract), then that transaction must be a `deposit` where A is the sender.

rule credit_inc_onlyif_deposit {
    env e;
    method f;
    calldataarg args;
    address a;

    mathint currb = currentContract.credits[a];
    f(e, args);
    mathint newb = currentContract.credits[a];

    assert(newb > currb => (f.selector == sig:deposit().selector && e.msg.sender == a));
}
