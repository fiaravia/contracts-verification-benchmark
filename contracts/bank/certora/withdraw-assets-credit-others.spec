// SPDX-License-Identifier: GPL-3.0-only

// after a successful withdraw(amount), the balances of any user but the sender are preserved.

rule withdraw_assets_credit_others {
    env e;
    uint256 amount;
    address a; // other address

    require a != e.msg.sender;

    mathint old_other_credit = currentContract.credits[a];
    withdraw(e,amount);
    mathint new_other_credit = currentContract.credits[a];

    assert new_other_credit == old_other_credit;
}
