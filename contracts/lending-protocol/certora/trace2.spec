// SPDX-License-Identifier: GPL-3.0-only

// import "erc20.spec";

rule trace1 {
    env e1;
    address t0;
    address t1;
    address a;
    address b;
    require(a != b && a!=0 && b!=0 && a!=currentContract && b!=currentContract);
    require(t0 != t1);

    // Set initial state
    require (currentContract.reserves[t0] == 0);
    require (currentContract.reserves[t1] == 0);
    require (currentContract.sum_credits[t0] == 0);
    require (currentContract.sum_credits[t1] == 0);
    require (currentContract.sum_debits[t0] == 0);
    require (currentContract.sum_debits[t1] == 0);

    require (currentContract.credit[t0][a] == 0);
    require (currentContract.credit[t0][b] == 0);
    require (currentContract.credit[t1][a] == 0);
    require (currentContract.credit[t1][b] == 0);

    require (currentContract.debit[t0][a] == 0);
    require (currentContract.debit[t0][b] == 0);
    require (currentContract.debit[t1][a] == 0);
    require (currentContract.debit[t1][b] == 0);

    // Warning: Certora is not able to infer the (constant) value of ratePerPeriod, so we require it 
    require(currentContract.ratePerPeriod == 100000); // 10% interest rate
    
    // A:deposit(50:T0)

    // require(e1.block.number > 0);
    require(e1.msg.sender == a);
    require(e1.msg.value == 0);

    uint reserve_t0_0 = currentContract.reserves[t0];   
    uint reserve_t1_0 = currentContract.reserves[t1];
    uint credit_t0_a_0 = currentContract.credit[t0][a];

    deposit(e1, 50, t0); 
    
    uint reserve_t0_1 = currentContract.reserves[t0];
    uint reserve_t1_1 = currentContract.reserves[t1];   
    uint credit_t0_a_1 = currentContract.credit[t0][a];
    uint credit_t1_b_1 = currentContract.credit[t1][b];

    // B:deposit(50:T1)

    env e2;
    // require(e2.block.number == e1.block.number);
    require(e2.msg.sender == b);
    require(e2.msg.value == 0);

    deposit(e2, 50, t1);
    
    uint reserve_t0_2 = currentContract.reserves[t0];
    uint reserve_t1_2 = currentContract.reserves[t1];
    uint credit_t0_a_2 = currentContract.credit[t0][a];
    uint credit_t1_b_2 = currentContract.credit[t1][b];
    uint debit_t0_b_2 = currentContract.debit[t0][b];

    // B:borrow(30:T0)

    env e3;
    // require(e3.block.number == e2.block.number);
    require(e3.msg.sender == b);
    require(e3.msg.value == 0);

    borrow(e3, 30, t0);
    
    uint reserve_t0_3 = currentContract.reserves[t0];
    uint reserve_t1_3 = currentContract.reserves[t1];
    uint credit_t0_a_3 = currentContract.credit[t0][a];
    uint credit_t1_b_3 = currentContract.credit[t1][b];
    uint debit_t0_b_3 = currentContract.debit[t0][b];
    uint debit_t1_b_3 = currentContract.debit[t1][b];

    // accrueInt()
    env e4;
    accrueInt(e4);

    uint reserve_t0_4 = currentContract.reserves[t0];
    uint reserve_t1_4 = currentContract.reserves[t1];
    uint xr_t0_4 = currentContract.XR(e4, t0);
    uint credit_t0_a_4 = currentContract.credit[t0][a];
    uint credit_t1_b_4 = currentContract.credit[t1][b];
    uint debit_t0_b_4 = currentContract.debit[t0][b];
    uint debit_t1_b_4 = currentContract.debit[t1][b];

    // B:repay(5:T0)

    env e5;
    require(e5.msg.sender == b);
    require(e5.msg.value == 0);

    repay(e5, 5, t0);

    uint reserve_t0_5 = currentContract.reserves[t0];
    uint credit_t0_a_5 = currentContract.credit[t0][a];
    uint debit_t0_b_5 = currentContract.debit[t0][b];

    // Asserts

    // A:deposit(50:T0)
    assert(reserve_t0_1 == reserve_t0_0 + 50);
    assert(reserve_t1_1 == reserve_t1_0);
    assert(credit_t0_a_1 == credit_t0_a_0 + 50);
            
    // B:deposit(50:T1)
    assert(reserve_t0_2 == reserve_t0_1);
    assert(reserve_t1_2 == reserve_t1_1 + 50);
    assert(credit_t1_b_2 == credit_t1_b_1 + 50);

    // B:borrow(30:T0)
    assert(reserve_t0_3 == reserve_t0_2 - 30);
    assert(reserve_t1_3 == reserve_t1_2);
    assert(credit_t0_a_3 == credit_t0_a_2);
    assert(credit_t1_b_3 == credit_t1_b_2);
    assert(debit_t0_b_3  == debit_t0_b_2 + 30);

    // int
    // B:repay(5:T0)

    assert(reserve_t0_4 == reserve_t0_3);
    assert(reserve_t1_4 == reserve_t1_3);

    // assert(xr_t0_4 == ((20 + (30 + 3)) * 1000000)/50);
    assert(credit_t1_b_4 == credit_t1_b_3);

    // B's debit before int:  30
    // B's debit after  int:  33
    assert(debit_t1_b_4  == debit_t1_b_3); 
    assert(debit_t0_b_4  == debit_t0_b_3 + 3);

    // B's debit after repay: 28
    assert(reserve_t0_5 == reserve_t0_4 + 5);
    assert(debit_t0_b_5  == debit_t0_b_5 - 5); 
}
