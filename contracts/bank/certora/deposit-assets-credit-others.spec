// SPDX-License-Identifier: GPL-3.0-only

// after a successful deposit(amount), the balances of any user but the sender are preserved.

rule deposit_assets_balance_others {
    env e;
    address a;

    require a != e.msg.sender;

    mathint old_a_balance = currentContract.balances[a];
    deposit(e);
    mathint new_a_balance = currentContract.balances[a];

    assert new_a_balance == old_a_balance;
}
