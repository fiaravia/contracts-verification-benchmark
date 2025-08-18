const {
    loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("PaymentSplitter v1", function () {
    async function deployContract() {
        const RevertOnReceive = await(ethers.deployContract("RevertOnReceive"))

        const PaymentSplitter1 = await(ethers.deployContract("PaymentSplitter1", [
            [RevertOnReceive.getAddress()],
            [1]
        ],
        {
            value: ethers.parseUnits("100", "wei")
        }));

        return { PaymentSplitter1, RevertOnReceive };
    };

    it("Transfer Reverts", async function () {
        const { PaymentSplitter1, RevertOnReceive } = await loadFixture(deployContract);
        
        const balanceBefore = await ethers.provider.getBalance(PaymentSplitter1.getAddress());

        await expect(
            PaymentSplitter1.release(RevertOnReceive.getAddress())
            ).to.be.reverted;

        const balanceAfter = await ethers.provider.getBalance(PaymentSplitter1.getAddress());

        expect(balanceAfter).to.equal(balanceBefore);
    });
})

describe("PaymentSplitter v2", function () {
    async function deployContract() {
        const RevertOnReceive = await(ethers.deployContract("RevertOnReceive"))
        const [filler1, filler2] = await ethers.getSigners();

        const PaymentSplitter2 = await(ethers.deployContract("PaymentSplitter2", [
            RevertOnReceive.getAddress(),
            1, 
            filler1.getAddress(),
            1,
            filler2.getAddress(),
            1

        ],
        {
            value: ethers.parseUnits("100", "wei")
        }));

        return { PaymentSplitter2, RevertOnReceive };
    };

    it("Transfer Reverts", async function () {
        const { PaymentSplitter2, RevertOnReceive } = await loadFixture(deployContract);
        
        const balanceBefore = await ethers.provider.getBalance(PaymentSplitter2.getAddress());

        await expect(
            PaymentSplitter2.release(RevertOnReceive.getAddress())
            ).to.be.reverted;

        const balanceAfter = await ethers.provider.getBalance(PaymentSplitter2.getAddress());

        expect(balanceAfter).to.equal(balanceBefore);
    });
})

describe("PaymentSplitter v3", function () {
    async function deployContract() {
        const RevertOnReceive = await(ethers.deployContract("RevertOnReceive"))
        const [filler1, filler2] = await ethers.getSigners();

        const PaymentSplitter3 = await(ethers.deployContract("PaymentSplitter3", [
            RevertOnReceive.getAddress(),
            filler1.getAddress(),
            filler2.getAddress(),
        ],
        {
            value: ethers.parseUnits("100", "wei")
        }));

        return { PaymentSplitter3, RevertOnReceive };
    };

    it("Transfer Reverts", async function () {
        const { PaymentSplitter3, RevertOnReceive } = await loadFixture(deployContract);
        
        const balanceBefore = await ethers.provider.getBalance(PaymentSplitter3.getAddress());

        await expect(
            PaymentSplitter3.release(RevertOnReceive.getAddress())
            ).to.be.reverted;

        const balanceAfter = await ethers.provider.getBalance(PaymentSplitter3.getAddress());

        expect(balanceAfter).to.equal(balanceBefore);
    });
})
