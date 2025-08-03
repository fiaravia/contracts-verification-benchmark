/// @custom:ghost

/// @custom:preghost function cancel
Vault.States prev_state = state;

/// @custom:postghost function cancel
assert(msg.sender == recovery && prev_state == Vault.States.REQ);
