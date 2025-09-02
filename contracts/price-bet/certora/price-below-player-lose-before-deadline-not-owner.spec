// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet versions/PriceBet_v1.sol:Oracle --verify PriceBet:certora/price-below-player-lose-before-deadline-not-owner.spec --link PriceBet:oracle=Oracle

using Oracle as oracle;

rule price_below_player_lose_before_deadline_not_owner {
    env e;
    method f;
    calldataarg args;

    address player = currentContract.player;

    // the player has joined
    require player != 0;

    // the player is not the owner
    require player != currentContract.owner;

    // the sender is the player
    require e.msg.sender == player;

    // the deadline has not passed
    require e.block.number < currentContract.deadline;

    // the price is below the target price
    require oracle.exchange_rate < currentContract.exchange_rate;

    uint player_balance_before = nativeBalances[player];

    f(e, args);

    uint player_balance_after = nativeBalances[player];

    assert player_balance_after <= player_balance_before; 
}
