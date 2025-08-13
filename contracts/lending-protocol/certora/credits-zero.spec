// Lemma 3.3
invariant credits_zero(address token)
    currentContract.totCredit[token] == 0 => 
    (currentContract.totDebit[token] == 0 && currentContract.reserves[token] == 0);
