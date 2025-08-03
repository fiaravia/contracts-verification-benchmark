/// @custom:ghost

/// @custom:preghost function withdraw
Vault.States prev_state = state;

/// @custom:postghost function withdraw
assert(prev_state == Vault.States.IDLE && state == Vault.States.REQ);


/// @custom:preghost function finalize
Vault.States prev_state = state;

/// @custom:postghost function finalize
assert(prev_state == Vault.States.REQ && state == Vault.States.IDLE);


/// @custom:preghost function cancel
Vault.States prev_state = state;

/// @custom:postghost function cancel
assert(prev_state == Vault.States.REQ && state == Vault.States.IDLE);
