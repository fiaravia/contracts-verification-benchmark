/// @custom:ghost

/// @custom:preghost function win
uint prev_player_balance = address(player).balance;
uint prev_contract_balance = address(this).balance;
require (player != address(this));

/// @custom:postghost function win
uint post_player_balance = address(player).balance;
assert(post_player_balance >= prev_player_balance + prev_contract_balance);