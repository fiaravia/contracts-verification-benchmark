/// @custom:preghost function join
require (block.number < deadline);
require(owner != player);
require(owner != address(this));
uint prev_owner_balance = address(owner).balance;

/// @custom:postghost function join
uint post_owner_balance = address(owner).balance;
assert (post_owner_balance <= prev_owner_balance);


/// @custom:preghost function win
require (block.number < deadline);
require(owner != player);
require(owner != address(this));
uint prev_owner_balance = address(owner).balance;

/// @custom:postghost function win
uint post_owner_balance = address(owner).balance;
assert (post_owner_balance <= prev_owner_balance);


/// @custom:preghost function timeout
require (block.number < deadline);
require(owner != player);
require(owner != address(this));
uint prev_owner_balance = address(owner).balance;

/// @custom:postghost function timeout
uint post_owner_balance = address(owner).balance;
assert (post_owner_balance <= prev_owner_balance);
