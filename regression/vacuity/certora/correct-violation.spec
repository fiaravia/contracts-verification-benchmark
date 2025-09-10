using Vacuity as V;

rule correct_violation {
	env e;
    uint256 x;

	// Precondition: v starts at 0
    require(V.v == 0);

    // Only state where it does not revert
    require(x == 1);

    // Under this precondition, set(x) should not revert and reach the assertion
    set(e, x);

    // Always false
    assert false == true;
}