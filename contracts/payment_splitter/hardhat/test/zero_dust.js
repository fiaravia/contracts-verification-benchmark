
const {
    loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const { expect } = require("chai");

describe("PaymentSplitter_v1", function () {

    async function deployContract() {
        const signers = await ethers.getSigners();

        const payees = [
            signers[0].address,
            signers[1].address,
            signers[2].address];

        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter1", [
            payees,
            [1,1,1]
        ],
        {
            value: ethers.parseUnits("4", "wei")
        }));

        return { PaymentSplitter };
    };

    it ("Zero Dust", async function() {
        const { PaymentSplitter} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter.getAddress());    
        const totalReleasable = await PaymentSplitter.getTotalReleasable();
        
        expect(totalReleasable).to.be.lessThan(balance);
    })
});


describe("PaymentSplitter_v2", function () {

    async function deployContract() {
        const signers = await ethers.getSigners();

        const payees = [
            signers[0].address,
            signers[1].address,
            signers[2].address];

        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter2", [
            payees[0], 1,
            payees[1], 1,
            payees[2], 1 
        ],
        {
            value: ethers.parseUnits("4", "wei")
        }));

        return { PaymentSplitter };
    };

    it ("Zero Dust", async function() {
        const { PaymentSplitter} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter.getAddress());    
        const totalReleasable = await PaymentSplitter.getTotalReleasable();
        
        expect(totalReleasable).to.be.lessThan(balance);
    })
});

describe("PaymentSplitter_v3", function () {

    async function deployContract() {
        const signers = await ethers.getSigners();

        const payees = [
            signers[0].address,
            signers[1].address,
            signers[2].address];

        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter3", [
            payees[0],
            payees[1],
            payees[2]
        ],
        {
            value: ethers.parseUnits("4", "wei")
        }));

        return { PaymentSplitter };
    };

    it ("Zero Dust", async function() {
        const { PaymentSplitter} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter.getAddress());    
        const totalReleasable = await PaymentSplitter.getTotalReleasable();
        
        expect(totalReleasable).to.be.lessThan(balance);
    })
});