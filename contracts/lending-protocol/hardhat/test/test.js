const { loadFixture } =
    require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LP", function () {

    async function deployContract() {
        const [tok_creator, actor_a, actor_b] = await ethers.getSigners();

        const amount = 1000000000;
        
        const tok0 = await ethers.deployContract("ERC20", [
            amount
        ], {
            signer: tok_creator 
        });

        const tok1 = await ethers.deployContract("ERC20b", [
            amount
        ], {
            signer: tok_creator 
        });

        const lp = await ethers.deployContract("LP",
            [
                await tok0.getAddress(),
                await tok1.getAddress(),
            ]
        );

        await tok0.transfer(actor_a, 50);
        await tok1.transfer(actor_b, 50);

        return { lp, tok0, tok1, actor_a , actor_b };
    }

    it("trace1", async function () {
        const { lp, tok0, tok1, actor_a, actor_b } = await loadFixture(deployContract);

        /* deployment checks */

        const tok0_addr = await tok0.getAddress();
        const tok1_addr = await tok1.getAddress();

        
        expect(await lp.tok0()).to.equal(tok0_addr);
        expect(await lp.tok1()).to.equal(tok1_addr);

        expect(await lp.reserves(tok0_addr)).to.equal(0);
        expect(await lp.reserves(tok1_addr)).to.equal(0);

        expect(await lp.totCredit(tok0_addr)).to.equal(0);
        expect(await lp.totCredit(tok1_addr)).to.equal(0);

        expect(await lp.totDebit(tok0_addr)).to.equal(0);
        expect(await lp.totDebit(tok1_addr)).to.equal(0);


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

});

/*
describe("Crowdfund - reclaim reverts", function () {
    async function deployContract() {
        const [owner] = await ethers.getSigners();

        const nowBlock = await ethers.provider.getBlockNumber();
        const endDonate = nowBlock + 5;

        const goal = ethers.parseEther("1000");

        const crowdfund = await ethers.deployContract("Crowdfund", [
            await owner.getAddress(),
            endDonate,
            goal,
        ]);

        const donor = await ethers.deployContract("RevertOnReceive");

        await donor.setCrowdfund(await crowdfund.getAddress());

        await donor.donate({ value: ethers.parseEther("1") });

        const current = await ethers.provider.getBlockNumber();
        const toMine = Math.max(1, endDonate - current + 1);
        await mine(toMine);

        return { crowdfund, donor, owner};
    }

    it("reclaim() reverts if the donor's receive() reverts", async function () {
        const { donor } = await loadFixture(deployContract);

        await expect(donor.reclaim()).to.be.reverted;
    });
});
*/