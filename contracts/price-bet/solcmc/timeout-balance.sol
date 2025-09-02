/// @custom:ghost

/// @custom:preghost function timeout
uint prev_contract_balance = address(this).balance;
uint prev_owner_balance = address(owner).balance;
require (owner != address(this));

/// @custom:postghost function timeout
assert (address(owner).balance == prev_owner_balance + prev_contract_balance);