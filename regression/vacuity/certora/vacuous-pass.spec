using Vacuity as V;

rule vacuous_pass {
	env e;
    uint256 x;

	// Precondition: v starts at 0
    require(V.v == 0);

    // Over-restrict so the call must revert
    require(x != 1);

    // Under this precondition, set(x) always reverts
    set(e, x);

    // Always false
    assert false == true;
}