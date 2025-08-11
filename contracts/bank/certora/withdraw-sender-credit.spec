// SPDX-License-Identifier: GPL-3.0-only

rule withdraw_sender_credit {
    env e;
    uint256 amount;

    mathint old_sender_credit = currentContract.credits[e.msg.sender];
    withdraw(e,amount);
    mathint new_sender_credit = currentContract.credits[e.msg.sender];

    assert new_sender_credit == old_sender_credit - to_mathint(amount);
}
