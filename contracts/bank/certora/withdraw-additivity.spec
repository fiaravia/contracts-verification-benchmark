// SPDX-License-Identifier: GPL-3.0-only

// two (successful) withdraw of n1 and n2 units of T (performed by the same sender) are equivalent to 
// a single withdraw of n1+n2 units of T, if n1+n2 is less than or equal to the sender's operation limit

using Bank as c;

rule withdraw_additivity {
    env e1;
    env e2;
    env e3;
    uint v1; 
    uint v2;
    uint v3;

    storage initial = lastStorage;

    require e1.msg.sender == e2.msg.sender;
    //require v1 + v2 <= currentContract.opLimit;

    withdraw(e1, v1);
    withdraw(e2, v2);

    storage s12 = lastStorage;

    require e3.msg.sender == e1.msg.sender;
    require v3 == v1 + v2;

    withdraw(e3, v3) at initial;
    storage s3 = lastStorage;

    assert s12[c] == s3[c];
}
