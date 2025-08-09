/// @custom:preghost function withdraw
bool pre = amount == 0 || amount > credits[msg.sender];

/// @custom:postghost function withdraw
assert(!pre);
