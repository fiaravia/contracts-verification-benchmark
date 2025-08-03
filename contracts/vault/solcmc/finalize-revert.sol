/// @custom:ghost

/// @custom:preghost function finalize
Vault.States prev_state = state;
uint prev_request_time = request_time;
uint prev_wait_time = wait_time;

/// @custom:postghost function finalize
assert(msg.sender == owner && prev_state == Vault.States.REQ && block.number >= prev_request_time + prev_wait_time);