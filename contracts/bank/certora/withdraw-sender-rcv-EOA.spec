// SPDX-License-Identifier: GPL-3.0-only

rule withdraw_sender_rcv_EOA {
    env e;
    uint256 amount;

    require (e.msg.sender == e.tx.origin);

    mathint old_sender_balance = nativeBalances[e.msg.sender];
    withdraw(e,amount);
    mathint new_sender_balance = nativeBalances[e.msg.sender];

    assert new_sender_balance == old_sender_balance + to_mathint(amount);
}
