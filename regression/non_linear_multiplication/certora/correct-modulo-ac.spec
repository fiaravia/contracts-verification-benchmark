rule correct_modulo_ac {
    env e;

    require currentContract.get_c(e) == currentContract.get_b(e);
    assert currentContract.getAC(e) % 3 == 0;
}
