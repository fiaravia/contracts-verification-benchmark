/// @custom:ghost

/// @custom:preghost function join
uint prev_initial_pot = initial_pot;

/// @custom:postghost function join
assert(address(this).balance == 2 * prev_initial_pot);