// SPDX-License-Identifier: GPL-3.0-only

// after a successful finalize(), exactly amount units of T pass from the control of the contract to that of the sender.

rule finalize_asset_transfer {
    env e;
    uint256 amount;

    mathint old_user_balance = nativeBalances[e.msg.sender];

    finalize(e);

    mathint new_user_balance = nativeBalances[e.msg.sender];
    assert new_user_balance == old_user_balance + to_mathint(currentContract.amount);
}