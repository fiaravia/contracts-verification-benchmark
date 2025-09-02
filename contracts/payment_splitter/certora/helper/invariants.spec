import "methods.spec";

/*
Notare che senza la `require currentContract.totalShares > 0;` contenuta nell'invariant il test fallisce, probabile
che il Prover abbia difficoltà a verificare require presenti nel costruttore
*/
invariant shares_sum_eq_totalShares()
    getSumOfShares() == currentContract.totalShares && currentContract.totalShares > 0;

invariant payee_shares_gt_zero ()
    //forall uint index. index < currentContract.payees.length =>
    forall uint index. index < currentContract.payees.length =>
    currentContract.shares[currentContract.payees[index]] > 0;

invariant released_sum_totalReleased()
    getSumOfReleased() == currentContract.totalReleased;


invariant out_of_bounds_payee()
    forall uint index. index >= currentContract.payees.length =>
    currentContract.shares[currentContract.payees[index]] == 0;

