// SPDX-License-Identifier: GPL-3.0-only

// after a successful deposit(), the credits of any user but the sender are preserved.

rule deposit_assets_credit_others {
    env e;
    address a;

    require a != e.msg.sender;

    mathint old_a_balance = currentContract.credits[a];
    deposit(e);
    mathint new_a_balance = currentContract.credits[a];

    assert new_a_balance == old_a_balance;
}
