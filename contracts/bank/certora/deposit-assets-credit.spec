// SPDX-License-Identifier: GPL-3.0-only

rule deposit_assets_credit {
    env e;

    mathint old_user_balance = currentContract.credits[e.msg.sender];
    deposit(e);
    mathint new_user_balance = currentContract.credits[e.msg.sender];

    assert new_user_balance == old_user_balance + e.msg.value;
}
