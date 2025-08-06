/// @custom:ghost

/// @custom:preghost function finalize
uint256 old_contract_balance = address(this).balance;
uint256 old_amount = amount;

/// @custom:postghost function finalize
assert(address(this).balance == old_contract_balance - old_amount);
