using LendingProtocol as lp;

rule rpy_additivity {
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

    repay(e1, amount1, token);
    repay(e2, amount2, token);

    storage s12 = lastStorage;

    require e3.msg.sender == e1.msg.sender;
    require amount3 == amount1 + amount2;

    repay(e3, amount3, token) at initial;

    storage s3 = lastStorage;
    
    // avoids cheap violation, since the block number that would not normally be saved, is saved in the contract
    require (e1.block.number == blocknumber);
    require (e2.block.number == blocknumber);
    require (e3.block.number == blocknumber);

    assert s12[lp] == s3[lp];
}
