/// @custom:ghost

/// @custom:preghost function withdraw
address prev_owner = owner;
Vault.States prev_state = state;
uint prev_balance = address(this).balance;

/// @custom:postghost function withdraw
assert(amount <= prev_balance &&
       msg.sender == prev_owner && 
       prev_state == Vault.States.IDLE);