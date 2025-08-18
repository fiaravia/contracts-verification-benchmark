// Lemma 3.3
invariant credits_zero(address token)
    currentContract.sum_credits[token] == 0 => 
    (currentContract.sum_debits[token] == 0 && currentContract.reserves[token] == 0);
