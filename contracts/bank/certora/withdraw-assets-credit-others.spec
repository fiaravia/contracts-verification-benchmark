// SPDX-License-Identifier: GPL-3.0-only

// after a successful withdraw(amount), the balances of any user but the sender are preserved.

rule withdraw_assets_balance {
    env e;
    uint256 amount;
    address a; // other address

    require a != e.msg.sender;

    mathint old_other_balance = currentContract.balances[a];
    withdraw(e,amount);
    mathint new_other_balance = currentContract.balances[a];

    assert new_other_balance == old_other_balance;
}
