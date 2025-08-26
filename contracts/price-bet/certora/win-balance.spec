// SPDX-License-Identifier: GPL-3.0-only

rule win_balance {
    env e;

    uint prev_player_balance = nativeBalances[currentContract.player];
    
    win(e);

    uint post_player_balance = nativeBalances[currentContract.player];

    assert(post_player_balance >= prev_player_balance + nativeBalances[currentContract]);
}
