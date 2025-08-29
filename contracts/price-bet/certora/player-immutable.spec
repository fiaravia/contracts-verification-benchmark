persistent ghost bool player_set { init_state axiom player_set==false; }
persistent ghost bool player_set_twice { init_state axiom player_set_twice==false; }

// NOTE: here we assume that join suceeds when it updates the player
// It does not seem possible to hook a call to a contract function

hook Sstore player address new_player (address old_player) {
    if (player_set) {
        player_set_twice = true;
    }
    player_set = true;
}

invariant player_immutable()
    (!player_set => currentContract.player == 0x0) &&
    (player_set => currentContract.player != 0x0) &&
    !player_set_twice;
