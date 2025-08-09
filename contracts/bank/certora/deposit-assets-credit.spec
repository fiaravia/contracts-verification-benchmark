// SPDX-License-Identifier: GPL-3.0-only

rule deposit_assets_credit {
    env e;

    mathint old_user_credit = currentContract.credits[e.msg.sender];
    deposit(e);
    mathint new_user_credit = currentContract.credits[e.msg.sender];

    assert new_user_credit == old_user_credit + e.msg.value;
}
