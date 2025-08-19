// SPDX-License-Identifier: GPL-3.0-only

/// @custom:run certoraRun versions/PriceBet_v1.sol:PriceBet --verify PriceBet:certora/only-owner-or-player-receive.spec

// in any state after join(), only the owner or the player can receive ETH from the contract

rule only_owner_or_player_receive {
    env e;
    method f;
    calldataarg args;

    // address of the user who will receive the tokens
    address a;

    // the player has joined
    require currentContract.player != 0;

    uint a_balance_before = nativeBalances[a];

    f(e, args);

    uint a_balance_after = nativeBalances[a];

    assert 
        a_balance_after>a_balance_before 
        => 
        a==currentContract.owner || a==currentContract.player;
}
