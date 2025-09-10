rule ab_eq_ac {
    env e;
    require currentContract.get_c(e) == currentContract.get_b(e);
    assert currentContract.getAB(e) == currentContract.getAC(e);
}
