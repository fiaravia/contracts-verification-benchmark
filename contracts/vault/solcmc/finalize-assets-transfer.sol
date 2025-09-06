/// @custom:ghost

/// @custom:preghost function finalize
uint old_receiver_balance = address(receiver).balance;
uint old_contract_balance = address(this).balance;
uint old_amount = amount;
// technical assumption
require (receiver != address(this));

/// @custom:postghost function finalize
uint new_receiver_balance = address(receiver).balance;
uint new_contract_balance = address(this).balance;
assert(new_receiver_balance == old_receiver_balance + old_amount);
assert(new_contract_balance == old_contract_balance - old_amount);
