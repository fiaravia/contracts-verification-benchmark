/// @custom:ghost
uint256 old_user_balance;
uint256 new_user_balance;

/// @custom:preghost function finalize
old_user_balance = address(receiver).balance;

/// @custom:postghost function finalize
new_user_balance = address(receiver).balance;
assert(new_user_balance == old_user_balance + amount);
