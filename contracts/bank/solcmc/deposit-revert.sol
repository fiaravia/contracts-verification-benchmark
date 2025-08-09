/// @custom:preghost function deposit
uint prev_credit_sender = credits[msg.sender];
uint MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

/// @custom:postghost function deposit
assert(MAX_UINT - prev_credit_sender >= msg.value);
