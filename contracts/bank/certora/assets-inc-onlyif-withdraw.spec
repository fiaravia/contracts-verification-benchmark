// SPDX-License-Identifier: GPL-3.0-only

// if the assets of a user A are increased after a transaction [of the Bank contract], then that transaction must be a withdraw() where A is the sender

rule assets_inc_onlyif_withdraw {
    env e; 
    method f;
    calldataarg args;
    address a;

    require e.msg.sender != currentContract;
    require a != currentContract;

    mathint old_a_balance = nativeBalances[a];
    f(e, args);
    mathint new_a_balance = nativeBalances[a];

    assert new_a_balance > old_a_balance => (f.selector == sig:withdraw(uint).selector && e.msg.sender == a);
}
