// SPDX-License-Identifier: GPL-3.0-only

rule player_cannot_withdraw_after_deadline_not_owner {
    env e;
    method f;
    calldataarg args;

    address owner = currentContract.owner;
    address player = currentContract.player;

    // the deadline has passed
    require e.block.number >= currentContract.deadline;

    // the player is not the owner 
    require player != owner;

    // the player is the sender of the transaction
    require player == e.msg.sender;

    uint player_balance_before = nativeBalances[player];

    f(e, args);

    uint player_balance_after = nativeBalances[player];

    // the player cannot withdraw any ETH
    assert player_balance_after <= player_balance_before;
}
