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

    it ("Releasable sum balance", async function() {
        const { PaymentSplitter} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter.getAddress());    
        const totalReleasable = await PaymentSplitter.getTotalReleasable();
        
        expect(totalReleasable).not.to.equal(balance);
    })
});

describe("PaymentSplitter_v2", function () {

    async function deployContract() {
        const [filler1, filler2, filler3] = await ethers.getSigners();


        const PaymentSplitter2 = await(ethers.deployContract("PaymentSplitter2", [
            filler1.getAddress(),
            1,
            filler2.getAddress(),
            1, 
            filler3.getAddress(),
            1
        ],
        {
            value: ethers.parseUnits("4", "wei")
        }));

        return { PaymentSplitter2 };
    };

    it ("Releasable sum balance", async function() {
        const { PaymentSplitter2} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter2.getAddress());    
        const totalReleasable = await PaymentSplitter2.getTotalReleasable();
        
        expect(totalReleasable).not.to.equal(balance);
    })
});

describe("PaymentSplitter_v3", function () {

    async function deployContract() {
        const [filler1, filler2, filler3] = await ethers.getSigners();

        const PaymentSplitter3 = await(ethers.deployContract("PaymentSplitter3", [
            filler1.getAddress(),
            filler2.getAddress(),
            filler3.getAddress()
        ],
        {
            value: ethers.parseUnits("4", "wei")
        }));

        return { PaymentSplitter3 };
    };

    it ("Releasable sum balance", async function() {
        const { PaymentSplitter3} = await loadFixture(deployContract);
        const balance = await ethers.provider.getBalance(PaymentSplitter3.getAddress());    
        const totalReleasable = await PaymentSplitter3.getTotalReleasable();
        
        expect(totalReleasable).not.to.equal(balance);
    })
});