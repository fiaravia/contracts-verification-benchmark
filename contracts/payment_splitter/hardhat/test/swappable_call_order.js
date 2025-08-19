const {
    loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const { expect } = require("chai");

describe("PaymentSplitter_v1", function () {

    async function deployContract() {

        const Returns7 = await(ethers.deployContract("ReturnsN", [7], {
            value: ethers.parseUnits("7", "wei")
        }));
        const Returns5 = await(ethers.deployContract("ReturnsN", [5], {
            value: ethers.parseUnits("5", "wei")
        }));

        const payees_swap_test = [
            Returns7.getAddress(),
            Returns5.getAddress()
        ];
        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter1", [
            payees_swap_test,
            [1,1]
        ], {
            value: ethers.parseUnits("8", "wei")
        }));

        return { PaymentSplitter, payees_swap_test };
    };

    it("Call order is not swappable", async function () {
        var balanceAfter1, balanceAfter2;

        // Run 1: first payee[0] calls release, then payee[1]

        {
            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);

            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);
            
            await PaymentSplitter.release(payees_swap_test[0]);
            await PaymentSplitter.release(payees_swap_test[1]);

            balanceAfter1 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }

        // Run 2: first payee[1] calls release, then payee[0]

        {

            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);
            
            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);

            await PaymentSplitter.release(payees_swap_test[1]);
            await PaymentSplitter.release(payees_swap_test[0]);

            balanceAfter2 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }


        // Confront the two runs
        expect(balanceAfter1).not.to.equal(balanceAfter2);
    });
});

describe("PaymentSplitter_v2", function () {

    async function deployContract() {

        const Returns7 = await(ethers.deployContract("ReturnsN", [7], {
            value: ethers.parseUnits("7", "wei")
        }));
        const Returns5 = await(ethers.deployContract("ReturnsN", [5], {
            value: ethers.parseUnits("5", "wei")
        }));

        const payees_swap_test = [
            Returns7.getAddress(),
            Returns5.getAddress()
        ];
        const [payee3] = await ethers.getSigners();

        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter2", [
            payees_swap_test[0], 1,
            payees_swap_test[1], 1,
            payee3.getAddress(), 1
        ], {
            value: ethers.parseUnits("8", "wei")
        }));

        return { PaymentSplitter, payees_swap_test };
    };

    it("Call order is not swappable", async function () {
        var balanceAfter1, balanceAfter2;

        // Run 1: first payee[0] calls release, then payee[1]

        {
            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);

            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);
            
            await PaymentSplitter.release(payees_swap_test[0]);
            await PaymentSplitter.release(payees_swap_test[1]);

            balanceAfter1 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }

        // Run 2: first payee[1] calls release, then payee[0]

        {

            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);
            
            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);

            await PaymentSplitter.release(payees_swap_test[1]);
            await PaymentSplitter.release(payees_swap_test[0]);

            balanceAfter2 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }


        // Confront the two runs
        expect(balanceAfter1).not.to.equal(balanceAfter2);
    });
});

describe("PaymentSplitter_v3", function () {

    async function deployContract() {

        const Returns7 = await(ethers.deployContract("ReturnsN", [7], {
            value: ethers.parseUnits("7", "wei")
        }));
        const Returns5 = await(ethers.deployContract("ReturnsN", [5], {
            value: ethers.parseUnits("5", "wei")
        }));

        const payees_swap_test = [
            Returns7.getAddress(),
            Returns5.getAddress()
        ];
        const [payee3] = await ethers.getSigners();
        const PaymentSplitter = await(ethers.deployContract("PaymentSplitter3", [
            payees_swap_test[0],
            payees_swap_test[1],
            payee3.getAddress(),
        ], {
            value: ethers.parseUnits("8", "wei")
        }));

        return { PaymentSplitter, payees_swap_test };
    };

    it("Call order is not swappable", async function () {
        var balanceAfter1, balanceAfter2;

        // Run 1: first payee[0] calls release, then payee[1]

        {
            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);

            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);
            
            await PaymentSplitter.release(payees_swap_test[0]);
            await PaymentSplitter.release(payees_swap_test[1]);

            balanceAfter1 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }

        // Run 2: first payee[1] calls release, then payee[0]

        {

            const { PaymentSplitter, payees_swap_test } = await loadFixture(deployContract);
            
            expect (payees_swap_test[0]).not.to.equal(payees_swap_test[1]);

            await PaymentSplitter.release(payees_swap_test[1]);
            await PaymentSplitter.release(payees_swap_test[0]);

            balanceAfter2 = await ethers.provider.getBalance(PaymentSplitter.getAddress());
        }


        // Confront the two runs
        expect(balanceAfter1).not.to.equal(balanceAfter2);
    });
});