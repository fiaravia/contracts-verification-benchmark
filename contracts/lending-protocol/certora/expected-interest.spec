// SPDX-License-Identifie: GPL-3.0-only

rule expected_interest {
    env e;                 // all calls use the same env (same sender)
    address a;
    address t1;
    address t0;
    uint amt; 
    // basic sanity
    require t0 != t1 && t0 !=currentContract && t1 != currentContract;
    require a != 0 && a != currentContract && a != t1 ;
    require isValidToken(e, t1);
    require isValidToken(e, t0);
    require getBorrowersLength(e) == 0;
    require(XR(e, t1) == 1000000);
    require(currentContract.ratePerPeriod == 100000); // 10% interest per period
    require amt > 0;
    require getAccruedDebt(e, t1, a) == 0;

    // 1) borrow on t1 -> a should be recorded once
    borrow(e, amt, t1);
    
    // 2) full repay on t1
    repay(e, amt, t1);

    // 3) borrow again on t1
    borrow(e, amt, t1);

    uint debt_before = getAccruedDebt(e, t1, a);
    //require debt_before == amt;

    env e2;
    require e2.block.number == e.block.number + 1000000; // move forward in time
    accrueInt(e2);
    
    uint debt_after = getAccruedDebt(e2, t1, a);
    require debt_after > debt_before;

    assert debt_after <= debt_before + ((debt_before * currentContract.ratePerPeriod )/ 1000000); 
}

/* RULE with one env, sme results, but its not clear how it passes in v2 since there should not be any interest accrued without time passing
rule expected_interest {
    env e;                 // all calls use the same env (same sender)
    address a;
    address t1;
    address t0;
    uint amt; 
    // basic sanity
    require t0 != t1 && t0 !=currentContract && t1 != currentContract;
    require a != 0 && a != currentContract && a != t1 ;
    require isValidToken(e, t1);
    require isValidToken(e, t0);
    require getBorrowersLength(e) == 0;
    require(getUpdatedXR(e, t1) == 1000000);
    require(currentContract.ratePerPeriod == 100000); // 10% interest per period
    require amt > 0;
    require getAccruedDebt(e, t1, a) == 0;

    // 1) borrow on t1 -> a should be recorded once
    borrow(e, amt, t1);
    
    // 2) full repay on t1
    repay(e, amt, t1);

    // 3) borrow again on t1
    borrow(e, amt, t1);

    uint debt_before = getAccruedDebt(e, t1, a);
    //require debt_before == amt;
    accrueInt(e);
    
    uint debt_after = getAccruedDebt(e, t1, a);
    require debt_after > debt_before;

    assert debt_after <= debt_before + ((debt_before * currentContract.ratePerPeriod )/ 1000000); 
}
*/

/* for some obscure reason even the v3 passes on this, bad rule

rule expected_interest {
    env e;                 // all calls use the same env (same sender)
    address a;
    address t1;
    address t0;
    uint amt; 
    uint initial_block;

    uint time_step = 1000000;
    // basic sanity
    require t0 != t1 && t0 !=currentContract && t1 != currentContract;
    require a != 0 && a != currentContract && a != t1 ;
    require isValidToken(e, t1);
    require isValidToken(e, t0);
    require getBorrowersLength(e) == 0;
    require(getUpdatedXR(e, t1) == 1000000);
    require(currentContract.ratePerPeriod == 100000); // 10% interest per period
    require amt > 0;
    require getAccruedDebt(e, t1, a) == 0;
    
    require e.block.number == initial_block;
    uint block_before = e.block.number;

    // 1) borrow on t1 -> a should be recorded once
    borrow(e, amt, t1);
    
    // 2) full repay on t1
    repay(e, amt, t1);

    // 3) borrow again on t1
    borrow(e, amt, t1);

    uint debt_before = getAccruedDebt(e, t1, a);
    //require debt_before == amt;

    require e.block.number == initial_block + 1000000; // move forward in time
    uint block_after = e.block.number;
    accrueInt(e);

    uint debt_after = getAccruedDebt(e, t1, a);
    require debt_after > debt_before;

    assert debt_after <= debt_before + ((debt_before * currentContract.ratePerPeriod )/ 1000000); 
}

*/