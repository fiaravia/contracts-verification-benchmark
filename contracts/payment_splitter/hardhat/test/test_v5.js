const {
    loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

const PANIC_OVERFLOW = 0x11;

describe("PaymentSplitter_v5", function () {


    //     fair-split-eq
    { 
        async function deployContract(){

            const [payee] = await ethers.getSigners();

            const PaymentSplitter = await (ethers.deployContract("PaymentSplitter_v1", [
                [payee.address],
                [ethers.MaxUint256]
            ],
                {
                    value: ethers.parseUnits("2", "wei")
                }
            ));

            return {PaymentSplitter, payee};
        }

        it("fair-split-eq case 1", async function () {
            const {PaymentSplitter, payee} = await loadFixture(deployContract);

            await expect(PaymentSplitter.release(payee.address))
            .to.be.revertedWithPanic(PANIC_OVERFLOW);
        });
    }
    {
        async function deployContract() {
            const signers = await ethers.getSigners();

            const payees = [
                signers[0].address,
                signers[1].address];

            const PaymentSplitter = await (ethers.deployContract("PaymentSplitter_v5", [
                payees,
                [5, 2]
            ],
                {
                    value: ethers.parseUnits("3", "wei")
                }));

            return { PaymentSplitter, payees };
        };

        it("fair-split-eq case 2", async function () {
            const { PaymentSplitter, payees } = await loadFixture(deployContract);

            const released = BigInt(await PaymentSplitter.getReleased(payees[0]));
            const releasable = BigInt(await PaymentSplitter.releasable(payees[0]));

            const bal = BigInt(await PaymentSplitter.getBalance());
            const totalReleased = BigInt(await PaymentSplitter.getTotalReleased());
            const shares_payee_0 = BigInt(await PaymentSplitter.getShares(payees[0]));

            const totalShares = BigInt(await PaymentSplitter.getTotalShares());

            expect(released + releasable).not.to.equal(((bal + totalReleased) * shares_payee_0) / totalShares);
        })
    };

    //     releasable-sum-balance
    {
        async function deployContract() {
            const signers = await ethers.getSigners();

            const payees = [
                signers[0].address,
                signers[1].address,
                signers[2].address];

            const PaymentSplitter = await (ethers.deployContract("PaymentSplitter_v5", [
                payees,
                [1, 1, 1]
            ],
                {
                    value: ethers.parseUnits("4", "wei")
                }));

            return { PaymentSplitter };
        };

        it("releasable-sum-balance", async function () {
            const { PaymentSplitter } = await loadFixture(deployContract);
            const balance = await ethers.provider.getBalance(PaymentSplitter.getAddress());
            const totalReleasable = await PaymentSplitter.getTotalReleasable();

            expect(totalReleasable).not.to.equal(balance);
        })
    };

    //     release-not-revert
    {
        async function deployContract() {
            const RevertOnReceive = await (ethers.deployContract("RevertOnReceive"))

            const PaymentSplitter = await (ethers.deployContract("PaymentSplitter_v5", [
                [RevertOnReceive.getAddress()],
                [1]
            ],
                {
                    value: ethers.parseUnits("100", "wei")
                }));

            return { PaymentSplitter, RevertOnReceive };
        };

        it("release-not-revert", async function () {
            const { PaymentSplitter, RevertOnReceive } = await loadFixture(deployContract);

            const balanceBefore = await ethers.provider.getBalance(PaymentSplitter.getAddress());

            await expect(
                PaymentSplitter.release(RevertOnReceive.getAddress())
            ).to.be.reverted;

            const balanceAfter = await ethers.provider.getBalance(PaymentSplitter.getAddress());

            expect(balanceAfter).to.equal(balanceBefore);
        });
    }
})