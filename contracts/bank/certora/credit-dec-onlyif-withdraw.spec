// SPDX-License-Identifier: GPL-3.0-only

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
