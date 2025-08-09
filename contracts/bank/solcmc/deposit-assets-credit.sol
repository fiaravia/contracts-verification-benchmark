/// @custom:preghost function deposit
uint old_user_credit = credits[msg.sender];

/// @custom:postghost function deposit
uint new_user_credit = credits[msg.sender];
assert(new_user_credit == old_user_credit + msg.value);
