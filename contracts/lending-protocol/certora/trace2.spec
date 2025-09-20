// SPDX-License-Identifier: GPL-3.0-only

// import "erc20.spec";
rule trace2 {
    // inizializzazioni
    
    // A:deposit(50:T0)
    deposit(e1, 50, t0); 

    // B:deposit(50:T1)
    deposit(e2, 50, t1);

    // B:borrow(30:T0)
    borrow(e3, 30, t0);

    // accrueInt()
    accrueInt(e4);
    
    // B:repay(5:T0)
    repay(e5, 5, t0);

    // Assert sullo stato finale
}
