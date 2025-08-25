import "helper/methods.spec";
import "helper/invariants.spec";

/*
rule naive_proportionality() {
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();
    requireInvariant payee_shares_gt_zero();
    requireInvariant out_of_bounds_payee();

    env e;
    uint i; uint j;
    
    require i < getPayeesLength() && j < getPayeesLength();
    require i != j;
    
    address a = currentContract.getPayee(e, i);
    address b = currentContract.getPayee(e, j);

    require currentContract.getShares(e,a) > 0;
    require currentContract.getShares(e,b) > 0;

    // align "already paid" so only the current owed part differs
    require currentContract.getReleased(e, a) == currentContract.getReleased(e, b);

    // Naive claim: exact proportionality of what's owed
    // (would hold without floors; v1 violates due to rounding)
    assert currentContract.releasable(e, a) * currentContract.getShares(e, b)
        == currentContract.releasable(e, b) * currentContract.getShares(e, a);
}
*/


/*
rule one_over_n_exact_payout {
  env e;
  address p = currentContract.getPayee(e, 0);        // or however you pick a payee
  uint n = currentContract.getPayeesLength(e);
  require n > 0;

  // p has exactly 1/n of the shares:
  require currentContract.getShares(e, p) * n == currentContract.getTotalShares(e);

  // exact payout for a 1/n holder:
  assert currentContract.releasable(e, p)
      == (currentContract.totalReleased + currentContract.getBalance()) / n - currentContract.getReleased(e, p);
}*/
invariant sum_releasable_le_balance()
  getTotalReleasable() <= getBalance();

rule proportional_when_divisible {
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();
    requireInvariant payee_shares_gt_zero();
    requireInvariant out_of_bounds_payee();

    env e; uint i; uint j;
    require getPayeesLength() == currentContract.payees.length;
    require i < getPayeesLength() && j < getPayeesLength();
    require i != j;

    address a = currentContract.getPayee(e, i);
    address b = currentContract.getPayee(e, j);

    mathint sa = to_mathint(currentContract.getShares(e, a));
    mathint sb = to_mathint(currentContract.getShares(e, b));
    mathint S  = to_mathint(currentContract.getTotalShares(e));
    mathint T  = to_mathint(currentContract.getBalance(e))
               + to_mathint(currentContract.getSumOfReleased(e));

    // Kill rounding: T must be a multiple of S
    mathint q;
    require T == q * S;            // existential “let q = T/S”
    require sa > 0 && sb > 0 && S > 1;

    // (optional) align histories to remove another source of asymmetry
    require currentContract.getReleased(e, a) == currentContract.getReleased(e, b);

    assert to_mathint(currentContract.releasable(e, a)) * sb
        == to_mathint(currentContract.releasable(e, b)) * sa;
}
/*

rule naive_proportionality_should_fail_v1 {
    requireInvariant shares_sum_eq_totalShares();
    requireInvariant released_sum_totalReleased();
    requireInvariant payee_shares_gt_zero();
    requireInvariant out_of_bounds_payee();
    requireInvariant sum_releasable_le_balance();

    env e;
    uint i; uint j;
    
    require i < getPayeesLength() && j < getPayeesLength();
    require i != j;
    
    address a = currentContract.getPayee(e, i);
    address b = currentContract.getPayee(e, j);
    
    // Cast all uint256 reads to mathint once
    mathint sa = to_mathint(currentContract.getShares(e, a));
    mathint sb = to_mathint(currentContract.getShares(e, b));
    mathint S  = to_mathint(currentContract.getTotalShares(e));
    mathint T  = to_mathint(currentContract.getBalance(e)) 
               + to_mathint(currentContract.getSumOfReleased(e));
    
    // Typical nontriviality guards (optional but useful for v1-fail goal)
    require sa > 0 && sb > 0;
    // require sa != sb;        // unsat on v2 → vacuous P!, okay if that’s intended
    require S > 1 && T > 0;
     
    require currentContract.getReleased(e, a) == currentContract.getReleased(e, b);
    
    // Keep the assertion in mathint to avoid overflow headaches
    assert to_mathint(currentContract.releasable(e, a)) * sb
        == to_mathint(currentContract.releasable(e, b)) * sa;
}*/
/*
rule nonlinear_proportionality_bound() {
    env e;
    address a;
    address b;

    // Sanity: a meaningful PaymentSplitter state
    require currentContract.getPayeesLength(e) > 1;
    require currentContract.getTotalShares(e) > 0;
    // (Holds in well-formed v1 states; narrows away nonsense states.)
    require currentContract.getSumOfShares(e) == currentContract.getTotalShares(e);

    // Pick two distinct positive-share accounts
    require a != b;
    require currentContract.getShares(e, a) > 0;
    require currentContract.getShares(e, b) > 0;

    // Align already-released so only rounding remains as a source of asymmetry
    require currentContract.getReleased(e, a) == currentContract.getReleased(e, b);

    // Optional: keep multiplications in comfortable ranges (helps avoid wrap nightmares)
    require currentContract.getShares(e, a) <= 10^18;
    require currentContract.getShares(e, b) <= 10^18;

    // | sA * rB - sB * rA | < sA + sB
    // Encode as two strict inequalities (CVL has no abs()):
    assert currentContract.releasable(e, a) * currentContract.getShares(e, b)
           + currentContract.getShares(e, a) + currentContract.getShares(e, b)
           > currentContract.releasable(e, b) * currentContract.getShares(e, a);

    assert currentContract.releasable(e, b) * currentContract.getShares(e, a)
           + currentContract.getShares(e, a) + currentContract.getShares(e, b)
           > currentContract.releasable(e, a) * currentContract.getShares(e, b);
}*/