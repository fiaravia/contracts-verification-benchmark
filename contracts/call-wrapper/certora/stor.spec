rule stor {
    env e;
    address called;

    mathint before = currentContract.data;
    callwrap(e, called);
    mathint after = currentContract.data;

    assert before == after;
}
