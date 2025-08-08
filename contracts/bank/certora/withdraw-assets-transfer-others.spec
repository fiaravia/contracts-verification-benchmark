// SPDX-License-Identifier: GPL-3.0-only

// after a successful withdraw(amount), the assets controlled by any user but the sender are preserved.

rule withdraw_assets_transfer_others {
    env e;
    uint256 amount;
    address a; // other address

    require a != e.msg.sender;
    require a != currentContract;

    mathint old_user_balance = nativeBalances[a];
    withdraw(e,amount);
    mathint new_user_balance = nativeBalances[a];

    assert new_user_balance == old_user_balance;
}
