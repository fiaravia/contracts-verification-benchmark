using LendingProtocol as lp;

rule rdm_additivity {
    env e1;
    env e2;
    env e3;
    address token;
    uint amount1;
    uint amount2;
    uint amount3;
    uint blocknumber;

    storage initial = lastStorage;

    require e1.msg.sender == e2.msg.sender;

    redeem(e1, amount1, token);
    redeem(e2, amount2, token);

    storage s12 = lastStorage;

    require e3.msg.sender == e1.msg.sender;
    require amount3 == amount1 + amount2;

    redeem(e3, amount3, token) at initial;

    storage s3 = lastStorage;
    
    assert s12[lp] == s3[lp];
}
