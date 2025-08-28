persistent ghost bool join_called { init_state axiom join_called==false; }
persistent ghost bool join_called_twice { init_state axiom join_called_twice==false; }

// NOTE: here we assume that join suceeds when it updates the player
// It does not seem possible to hook a call to a contract function

hook Sstore player address new_player (address old_player) {
    if (join_called) {
        join_called_twice = true;
    }
    join_called = true;
}

invariant join_only_once()
    (!join_called => currentContract.player == 0x0) &&
    (join_called => currentContract.player != 0x0) &&
    !join_called_twice;
