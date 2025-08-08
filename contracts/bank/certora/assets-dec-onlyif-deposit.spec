// SPDX-License-Identifier: GPL-3.0-only

// if the assets of a user A are decreased after a transaction, 
// then that transaction must be a deposit() where A is the sender

rule assets_dec_onlyif_deposit {
    env e; 
    method f;
    calldataarg args;
    address a;

    require e.msg.sender != currentContract;
    require a != currentContract;

    mathint old_a_balance = nativeBalances[a];
    f(e, args);
    mathint new_a_balance = nativeBalances[a];

    assert new_a_balance < old_a_balance => (f.selector == sig:deposit().selector && e.msg.sender == a);
}
