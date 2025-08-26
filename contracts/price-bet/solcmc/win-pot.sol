/// @custom:ghost

/// @custom:preghost function win
uint prev_player_balance = address(player).balance;

/// @custom:postghost function win
uint post_player_balance = address(player).balance;
assert(post_player_balance >= prev_player_balance + 2 * initial_pot);