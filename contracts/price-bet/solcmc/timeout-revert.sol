/// @custom:ghost

/// @custom:preghost function timeout
uint prev_deadline = deadline;

/// @custom:postghost function timeout
assert(block.number >= prev_deadline);