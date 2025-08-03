/// @custom:ghost
address prev_owner;
address prev_recovery;

/// @custom:postghost constructor
prev_owner = owner;
prev_recovery = recovery;

/// @custom:invariant
function invariant() public {
    assert(prev_owner == owner);
    assert(prev_recovery == recovery);
}