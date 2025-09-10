/// @custom:run solc ../contracts/price-bet/solcmc/build/contracts/PriceBet_win-revert_v1.sol --model-checker-engine chc --model-checker-timeout 0 --model-checker-targets assert --model-checker-show-unproved --model-checker-ext-calls trusted

// a transaction win() reverts if:
// 1) the deadline has expired, or 
// 2) the sender is not the player, or 
// 3) the oracle exchange rate is smaller than the bet exchange rate.

/// @custom:ghost

/// @custom:preghost function win
address ghost_player = player;
address ghost_oracle = oracle;
uint ghost_exchange_rate = exchange_rate;

/// @custom:postghost function win
assert(
    block.number < deadline &&
    ghost_player == msg.sender &&
    Oracle(ghost_oracle).get_exchange_rate() >= exchange_rate
);
