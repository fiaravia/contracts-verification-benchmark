/// @custom:ghost
Vault.States prev_state;

/// @custom:preghost function cancel
prev_state = state;

/// @custom:postghost function cancel
assert(msg.sender == recovery && prev_state == Vault.States.REQ);
