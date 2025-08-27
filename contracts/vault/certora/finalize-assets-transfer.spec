// SPDX-License-Identifier: GPL-3.0-only

// after a successful finalize(), exactly amount units of T pass from the control of the contract to that of the sender.

rule finalize_assets_transfer {
    env e;

    uint old_user_balance = nativeBalances[e.msg.sender];

    finalize(e);

    uint new_user_balance = nativeBalances[e.msg.sender];

    assert new_user_balance == old_user_balance + currentContract.amount;
}
