/// @custom:preghost function join
require (block.number >= deadline);
require (msg.sender == player);
require(player != address(this));
uint prev_player_balance = address(player).balance;

/// @custom:postghost function join
uint post_player_balance = address(player).balance;
assert (post_player_balance <= prev_player_balance);


/// @custom:preghost function win
require (block.number >= deadline);
require (msg.sender == player);
require(player != address(this));
uint prev_player_balance = address(player).balance;

/// @custom:postghost function win
uint post_player_balance = address(player).balance;
assert (post_player_balance <= prev_player_balance);


/// @custom:preghost function timeout
require (block.number >= deadline);
require (msg.sender == player);
require(player != address(this));
uint prev_player_balance = address(player).balance;

/// @custom:postghost function timeout
uint post_player_balance = address(player).balance;
assert (post_player_balance <= prev_player_balance);
