/// @custom:preghost function withdraw
uint old_user_credit = credits[msg.sender];

/// @custom:postghost function withdraw
uint new_user_credit = credits[msg.sender];
assert(new_user_credit == old_user_credit - amount);
