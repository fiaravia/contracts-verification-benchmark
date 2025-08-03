/// @custom:invariant
function invariant() public {
    assert(state!=Vault.States.REQ || amount <= address(this).balance);
}