const { loadFixture, mine } =
    require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LendingProtocol_v3", function () {

    async function deployContract() {
        const [owner, actor_a, actor_b] = await ethers.getSigners();

        const amount = 1000000000;

        const tok0 = await ethers.deployContract("ERC20", [
            amount
        ], {
            signer: owner 
        });

        const tok1 = await ethers.deployContract("ERC20b", [
            amount
        ], {
            signer: owner 
        });

        const lp = await ethers.deployContract("LendingProtocol_v3",
            [
                await tok0.getAddress(),
                await tok1.getAddress(),
            ]
        );

        await tok0.transfer(actor_a, 5000);
        await tok1.transfer(actor_b, 5000);

        return { lp, tok0, tok1, actor_a , actor_b , owner};
    }
    
    it("expected-interest POC", async function () {
        const { lp, tok0, tok1, actor_a, actor_b, owner } = await loadFixture(deployContract);

        const lpAddr = await lp.getAddress();
        
        const a_lp_conn = lp.connect(actor_a);
        const a_t0_conn = tok0.connect(actor_a);


        // B deposits 30 t1
        await tok1.connect(actor_b).approve(lpAddr, 30);
        await lp.connect(actor_b).deposit(30, tok1);

        // A deposits 50 t0
        await a_t0_conn.approve(lpAddr, 50);
        await a_lp_conn.deposit(50, tok0)

        // A borrows and instantly repays 10 t1
        await a_lp_conn.borrow(10, tok1);
        await tok1.connect(actor_a).approve(lpAddr, 10);
        await a_lp_conn.repay(10, tok1);


        // A borrows 10 t1 and lets interest accrue
        await a_lp_conn.borrow(10,tok1)

        const debt_t1_a_before_accrual = await lp.debit(tok1, actor_a);

        await lp.connect(owner).accrueInt();

        const debt_t1_a_after_accrual = await lp.debit(tok1, actor_a);

        expect(debt_t1_a_after_accrual).to.not.equal(debt_t1_a_before_accrual + debt_t1_a_before_accrual / 10n);
    });

});

