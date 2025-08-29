// SPDX-License-Identifier: GPL-3.0-only

rule owner_cannot_withdraw_before_deadline_not_player {
    env e;
    method f;
    calldataarg args;

    address owner = currentContract.owner;
    address player = currentContract.player;

    // the deadline has not passed yet
    require e.block.number < currentContract.deadline;

    // the owner is not the player
    require owner != player;

    // the owner is the sender of the transaction
    require owner == e.msg.sender;

    uint owner_balance_before = nativeBalances[owner];

    f(e, args);

    uint owner_balance_after = nativeBalances[owner];

    // the owner cannot withdraw any ETH
    assert owner_balance_after <= owner_balance_before;
}
