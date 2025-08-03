/// @custom:invariant
function invariant() public {
    assert(state == Vault.States.IDLE || state == Vault.States.REQ);
}