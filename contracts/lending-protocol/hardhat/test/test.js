const { loadFixture } =
    require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LP", function () {

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

        const lp = await ethers.deployContract("LP_v1",
            [
                await tok0.getAddress(),
                await tok1.getAddress(),
            ]
        );

        await tok0.transfer(actor_a, 50);
        await tok1.transfer(actor_b, 50);

        return { lp, tok0, tok1, actor_a , actor_b , owner};
    }

    it("trace1", async function () {
        const { lp, tok0, tok1, actor_a, actor_b, owner } = await loadFixture(deployContract);

        /* deployment checks */

        const tok0_addr = await tok0.getAddress();
        const tok1_addr = await tok1.getAddress();

        
        expect(await lp.tok0()).to.equal(tok0_addr);
        expect(await lp.tok1()).to.equal(tok1_addr);

        expect(await lp.reserves(tok0_addr)).to.equal(0);
        expect(await lp.reserves(tok1_addr)).to.equal(0);

        expect(await lp.sum_credits(tok0_addr)).to.equal(0);
        expect(await lp.sum_credits(tok1_addr)).to.equal(0);

        expect(await lp.sum_debits(tok0_addr)).to.equal(0);
        expect(await lp.sum_debits(tok1_addr)).to.equal(0);


        /* step 1; A:deposit(50:T0) */
        const amount1 = 50;
       
        const reserve_t0_0 = await lp.reserves(tok0_addr);
        const reserve_t1_0 = await lp.reserves(tok1_addr);
        const credit_t0_a_0 = await lp.credit(tok0_addr, actor_a);

        await tok0.connect(actor_a).approve(await lp.getAddress(), amount1);

        await lp.connect(actor_a).deposit(amount1, tok0_addr);

        const reserve_t0_1 = await lp.reserves(tok0_addr);
        const reserve_t1_1 = await lp.reserves(tok1_addr);
        const credit_t0_a_1 = await lp.credit(tok0_addr, actor_a);
        const credit_t1_b_1 = await lp.credit(tok1_addr, actor_b);

        expect(reserve_t0_1).to.equal(reserve_t0_0 + BigInt(50));
        expect(reserve_t1_1).to.equal(reserve_t1_0);
        expect(credit_t0_a_1).to.equal(credit_t0_a_0 + BigInt(50));

        /* step 2; B:deposit(50:T1) */
 
        await tok1.connect(actor_b).approve(await lp.getAddress(), amount1);
        await lp.connect(actor_b).deposit(amount1, tok1_addr);

        const reserve_t0_2 = await lp.reserves(tok0_addr);
        const reserve_t1_2 = await lp.reserves(tok1_addr);
        const credit_t1_b_2 = await lp.credit(tok1_addr, actor_b);

        expect(reserve_t0_2).to.equal(reserve_t0_1);
        expect(reserve_t1_2).to.equal(reserve_t1_1 + BigInt(50));
        expect(credit_t1_b_2).to.equal(credit_t1_b_1 + BigInt(50));
        
        /* step 3; B:borrow(30:T0) */
        
        const amount2 = 30;
        
        await lp.connect(actor_b).borrow(amount2, tok0_addr); 

        const reserve_t0_3 = await lp.reserves(tok0_addr);
        const reserve_t1_3 = await lp.reserves(tok1_addr);

        expect(reserve_t0_3).to.equal(reserve_t0_2 - BigInt(30))
        expect(reserve_t1_3).to.equal(reserve_t1_2);
    });

    it("dep-xr-eq", async function() {

        const { lp, tok0, tok1, actor_a, actor_b, owner } = await loadFixture(deployContract);

        await tok0.connect(actor_a).approve(await lp.getAddress(), 11);

        const actor_a_conn = lp.connect(actor_a);
        const tok0_addr = await tok0.getAddress();

        await actor_a_conn.deposit(10,tok0_addr); // res=10,tot_cred=10,tot_deb=0,xr=1e6
        await actor_a_conn.borrow(10, tok0_addr); // res=0,tot_cred=10,tot_deb=10,xr=1e6 

        const old_xr_t0 = await lp.XR(tok0); //1e6

        await lp.connect(owner).accrueInt(); //res=0,tot_cred=10,tot_deb=11,xr=1.1e6

        await actor_a_conn.deposit(1, tok0_addr); // rounding error
            //res=1,tot_cred=floor(1*1e6/1.1e6)= floor(0.9) = 0, tot_deb=11, xr=1.2e6
            //wasted deposit, not enough to convert to an integer amount of credits
        const new_xr_t0 = await lp.XR(tok0);

        expect(new_xr_t0).not.to.equal(old_xr_t0);
    });

});

