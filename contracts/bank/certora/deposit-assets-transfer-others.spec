// SPDX-License-Identifier: GPL-3.0-only

// after a successful deposit(amount), the assets controlled by any user but the sender are preserved.

rule deposit_assets_transfer_others {
    env e; 
    address a; // other address

    require a != e.msg.sender;
    require a != currentContract;

    mathint old_other_balance = nativeBalances[a];
    deposit(e);
    mathint new_other_balance = nativeBalances[a];

    assert new_other_balance == old_other_balance;
}
