/// @custom:ghost

/// @custom:preghost function join
uint prev_amount = msg.value;
uint prev_initial_pot = initial_pot;
address prev_player = player;

/// @custom:postghost function join
assert(prev_amount == prev_initial_pot && prev_player == ZERO_ADDRESS);