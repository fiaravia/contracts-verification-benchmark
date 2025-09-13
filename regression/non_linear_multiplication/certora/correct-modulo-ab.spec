rule correct_modulo_ab {
    env e;

    require currentContract.get_c(e) == currentContract.get_b(e);
    assert currentContract.getAB(e) % 3 == 0;
}
