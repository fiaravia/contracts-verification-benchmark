/// @custom:ghost
uint join_not_reverted = 0;

/// @custom:preghost function join

/// @custom:postghost function join
join_not_reverted += 1;
assert(join_not_reverted <= 1);