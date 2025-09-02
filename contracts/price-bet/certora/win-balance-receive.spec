// SPDX-License-Identifier: GPL-3.0-only

rule win_balance_receive {
    env e;

    address player = currentContract.player;
    require player != currentContract;

    uint prev_player_balance = nativeBalances[player];
    uint prev_contract_balance = nativeBalances[currentContract];

    win(e);

    uint post_player_balance = nativeBalances[player];

    assert post_player_balance == prev_player_balance + prev_contract_balance;
}
