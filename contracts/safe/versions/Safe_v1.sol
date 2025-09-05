--- START FILE: ../safe-smart-account/contracts/Safe.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {FallbackManager} from "./base/FallbackManager.sol";
import {ITransactionGuard, GuardManager} from "./base/GuardManager.sol";
import {ModuleManager} from "./base/ModuleManager.sol";
import {OwnerManager} from "./base/OwnerManager.sol";
import {NativeCurrencyPaymentFallback} from "./common/NativeCurrencyPaymentFallback.sol";
import {SecuredTokenTransfer} from "./common/SecuredTokenTransfer.sol";
import {SignatureDecoder} from "./common/SignatureDecoder.sol";
import {Singleton} from "./common/Singleton.sol";
import {StorageAccessible} from "./common/StorageAccessible.sol";
import {SafeMath} from "./external/SafeMath.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {ISignatureValidator, ISignatureValidatorConstants} from "./interfaces/ISignatureValidator.sol";
import {Enum} from "./libraries/Enum.sol";
contract Safe is
    Singleton,
    NativeCurrencyPaymentFallback,
    ModuleManager,
    GuardManager,
    OwnerManager,
    SignatureDecoder,
    SecuredTokenTransfer,
    ISignatureValidatorConstants,
    FallbackManager,
    StorageAccessible,
    ISafe
{
    using SafeMath for uint256;
    string public constant override VERSION = "1.5.0";
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;
    uint256 public override nonce;
    bytes32 private _deprecatedDomainSeparator;
    mapping(bytes32 => uint256) public override signedMessages;
    mapping(address => mapping(bytes32 => uint256)) public override approvedHashes;
    constructor() {
        threshold = 1;
    }
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external override {
        emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
        setupOwners(_owners, _threshold);
        if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
        setupModules(to, data);
        if (payment > 0) {
            handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
        }
    }
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable override returns (bool success) {
        onBeforeExecTransaction(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signatures);
        bytes32 txHash;
        {
            txHash = getTransactionHash(
                to,
                value,
                data,
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                nonce++
            );
            checkSignatures(msg.sender, txHash, signatures);
        }
        address guard = getGuard();
        {
            if (guard != address(0)) {
                ITransactionGuard(guard).checkTransaction(
                    to,
                    value,
                    data,
                    operation,
                    safeTxGas,
                    baseGas,
                    gasPrice,
                    gasToken,
                    refundReceiver,
                    signatures,
                    msg.sender
                );
            }
        }
        if (gasleft() < ((safeTxGas << 6) / 63).max(safeTxGas + 2500) + 500) revertWithError("GS010");
        {
            uint256 gasUsed = gasleft();
            success = execute(to, value, data, operation, gasPrice == 0 ? (gasleft() - 2500) : safeTxGas);
            gasUsed = gasUsed.sub(gasleft());
            if (!success && safeTxGas == 0 && gasPrice == 0) {
                assembly {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
            uint256 payment = 0;
            if (gasPrice > 0) {
                payment = handlePayment(gasUsed, baseGas, gasPrice, gasToken, refundReceiver);
            }
            if (success) emit ExecutionSuccess(txHash, payment);
            else emit ExecutionFailure(txHash, payment);
        }
        {
            if (guard != address(0)) {
                ITransactionGuard(guard).checkAfterExecution(txHash, success);
            }
        }
    }
    function handlePayment(
        uint256 gasUsed,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver
    ) private returns (uint256 payment) {
        address payable receiver = refundReceiver == address(0) ? payable(tx.origin) : refundReceiver;
        if (gasToken == address(0)) {
            payment = gasUsed.add(baseGas).mul(gasPrice < tx.gasprice ? gasPrice : tx.gasprice);
            (bool refundSuccess, ) = receiver.call{value: payment}("");
            if (!refundSuccess) revertWithError("GS011");
        } else {
            payment = gasUsed.add(baseGas).mul(gasPrice);
            if (!transferToken(gasToken, receiver, payment)) revertWithError("GS012");
        }
    }
    function checkContractSignature(address owner, bytes32 dataHash, bytes memory signatures, uint256 offset) internal view {
        if (offset.add(32) > signatures.length) revertWithError("GS022");
        uint256 contractSignatureLen;
        assembly {
            contractSignatureLen := mload(add(add(signatures, offset), 0x20))
        }
        if (offset.add(32).add(contractSignatureLen) > signatures.length) revertWithError("GS023");
        bytes memory contractSignature;
        assembly {
            contractSignature := add(add(signatures, offset), 0x20)
        }
        if (ISignatureValidator(owner).isValidSignature(dataHash, contractSignature) != EIP1271_MAGIC_VALUE) revertWithError("GS024");
    }
    function checkSignatures(address executor, bytes32 dataHash, bytes memory signatures) public view override {
        uint256 _threshold = threshold;
        if (_threshold == 0) revertWithError("GS001");
        checkNSignatures(executor, dataHash, signatures, _threshold);
    }
    function checkNSignatures(
        address executor,
        bytes32 dataHash,
        bytes memory signatures,
        uint256 requiredSignatures
    ) public view override {
        if (signatures.length < requiredSignatures.mul(65)) revertWithError("GS020");
        address lastOwner = address(0);
        address currentOwner;
        uint256 v; 
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < requiredSignatures; ++i) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                currentOwner = address(uint160(uint256(r)));
                if (uint256(s) < requiredSignatures.mul(65)) revertWithError("GS021");
                checkContractSignature(currentOwner, dataHash, signatures, uint256(s));
            } else if (v == 1) {
                currentOwner = address(uint160(uint256(r)));
                if (executor != currentOwner && approvedHashes[currentOwner][dataHash] == 0) revertWithError("GS025");
            } else if (v > 30) {
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), uint8(v - 4), r, s);
            } else {
                currentOwner = ecrecover(dataHash, uint8(v), r, s);
            }
            if (currentOwner <= lastOwner || owners[currentOwner] == address(0) || currentOwner == SENTINEL_OWNERS)
                revertWithError("GS026");
            lastOwner = currentOwner;
        }
    }
    function checkSignatures(bytes32 dataHash, bytes calldata data, bytes memory signatures) external view {
        data;
        checkSignatures(msg.sender, dataHash, signatures);
    }
    function checkNSignatures(bytes32 dataHash, bytes calldata data, bytes memory signatures, uint256 requiredSignatures) external view {
        data;
        checkNSignatures(msg.sender, dataHash, signatures, requiredSignatures);
    }
    function approveHash(bytes32 hashToApprove) external override {
        if (owners[msg.sender] == address(0)) revertWithError("GS030");
        approvedHashes[msg.sender][hashToApprove] = 1;
        emit ApproveHash(hashToApprove, msg.sender);
    }
    function domainSeparator() public view override returns (bytes32 domainHash) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, DOMAIN_SEPARATOR_TYPEHASH)
            mstore(add(ptr, 32), chainid())
            mstore(add(ptr, 64), address())
            domainHash := keccak256(ptr, 96)
        }
    }
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) public view override returns (bytes32 txHash) {
        bytes32 domainHash = domainSeparator();
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
            let calldataHash := keccak256(ptr, data.length)
            mstore(ptr, SAFE_TX_TYPEHASH)
            mstore(add(ptr, 32), to)
            mstore(add(ptr, 64), value)
            mstore(add(ptr, 96), calldataHash)
            mstore(add(ptr, 128), operation)
            mstore(add(ptr, 160), safeTxGas)
            mstore(add(ptr, 192), baseGas)
            mstore(add(ptr, 224), gasPrice)
            mstore(add(ptr, 256), gasToken)
            mstore(add(ptr, 288), refundReceiver)
            mstore(add(ptr, 320), _nonce)
            mstore(add(ptr, 64), keccak256(ptr, 352))
            mstore(ptr, 0x1901)
            mstore(add(ptr, 32), domainHash)
            txHash := keccak256(add(ptr, 30), 66)
        }
    }
    function onBeforeExecTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) internal virtual {}
}
--- END FILE: ../safe-smart-account/contracts/Safe.sol ---
--- START FILE: ../safe-smart-account/contracts/SafeL2.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ModuleManager} from "./base/ModuleManager.sol";
import {Safe, Enum} from "./Safe.sol";
contract SafeL2 is Safe {
    event SafeMultiSigTransaction(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes signatures,
        bytes additionalInfo
    );
    event SafeModuleTransaction(address module, address to, uint256 value, bytes data, Enum.Operation operation);
    function onBeforeExecTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) internal override {
        bytes memory additionalInfo;
        {
            additionalInfo = abi.encode(nonce, msg.sender, threshold);
        }
        emit SafeMultiSigTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures,
            additionalInfo
        );
    }
    function onBeforeExecTransactionFromModule(address to, uint256 value, bytes memory data, Enum.Operation operation) internal override {
        emit SafeModuleTransaction(msg.sender, to, value, data, operation);
    }
}
--- END FILE: ../safe-smart-account/contracts/SafeL2.sol ---
--- START FILE: ../safe-smart-account/contracts/proxies/SafeProxy.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IProxy {
    function masterCopy() external view returns (address);
}
contract SafeProxy {
    address internal singleton;
    constructor(address _singleton) {
        require(_singleton != address(0), "Invalid singleton address provided");
        singleton = _singleton;
    }
    fallback() external payable {
        assembly {
            let _singleton := sload(0)
            if eq(shr(224, calldataload(0)), 0xa619486e) {
                mstore(0x6c, shl(96, _singleton))
                return(0x60, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if iszero(success) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/proxies/SafeProxy.sol ---
--- START FILE: ../safe-smart-account/contracts/proxies/SafeProxyFactory.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SafeProxy} from "./SafeProxy.sol";
contract SafeProxyFactory {
    event ProxyCreation(SafeProxy indexed proxy, address singleton);
    event ProxyCreationL2(SafeProxy indexed proxy, address singleton, bytes initializer, uint256 saltNonce);
    event ChainSpecificProxyCreationL2(SafeProxy indexed proxy, address singleton, bytes initializer, uint256 saltNonce, uint256 chainId);
    function proxyCreationCode() public pure returns (bytes memory) {
        return type(SafeProxy).creationCode;
    }
    function proxyCreationCodehash(address singleton) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(singleton))));
    }
    function deployProxy(address _singleton, bytes memory initializer, bytes32 salt) internal returns (SafeProxy proxy) {
        require(isContract(_singleton), "Singleton contract not deployed");
        bytes memory deploymentData = abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(_singleton)));
        assembly {
            proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(address(proxy) != address(0), "Create2 call failed");
        if (initializer.length > 0) {
            assembly {
                if iszero(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0)) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0x00, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }
    function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce) public returns (SafeProxy proxy) {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        proxy = deployProxy(_singleton, initializer, salt);
        emit ProxyCreation(proxy, _singleton);
    }
    function createProxyWithNonceL2(address _singleton, bytes memory initializer, uint256 saltNonce) public returns (SafeProxy proxy) {
        proxy = createProxyWithNonce(_singleton, initializer, saltNonce);
        emit ProxyCreationL2(proxy, _singleton, initializer, saltNonce);
    }
    function createChainSpecificProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (SafeProxy proxy) {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce, getChainId()));
        proxy = deployProxy(_singleton, initializer, salt);
        emit ProxyCreation(proxy, _singleton);
    }
    function createChainSpecificProxyWithNonceL2(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) public returns (SafeProxy proxy) {
        proxy = createChainSpecificProxyWithNonce(_singleton, initializer, saltNonce);
        emit ChainSpecificProxyCreationL2(proxy, _singleton, initializer, saltNonce, getChainId());
    }
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
--- END FILE: ../safe-smart-account/contracts/proxies/SafeProxyFactory.sol ---
--- START FILE: ../safe-smart-account/contracts/base/OwnerManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SelfAuthorized} from "../common/SelfAuthorized.sol";
import {IOwnerManager} from "../interfaces/IOwnerManager.sol";
abstract contract OwnerManager is SelfAuthorized, IOwnerManager {
    address internal constant SENTINEL_OWNERS = address(0x1);
    mapping(address => address) internal owners;
    uint256 internal ownerCount;
    uint256 internal threshold;
    function setupOwners(address[] memory _owners, uint256 _threshold) internal {
        if (threshold > 0) revertWithError("GS200");
        if (_threshold > _owners.length) revertWithError("GS201");
        if (_threshold == 0) revertWithError("GS202");
        address currentOwner = SENTINEL_OWNERS;
        uint256 ownersLength = _owners.length;
        for (uint256 i = 0; i < ownersLength; ++i) {
            address owner = _owners[i];
            if (owner == address(0) || owner == SENTINEL_OWNERS) revertWithError("GS203");
            if (owner == currentOwner || owners[owner] != address(0)) revertWithError("GS204");
            owners[currentOwner] = owner;
            currentOwner = owner;
        }
        owners[currentOwner] = SENTINEL_OWNERS;
        ownerCount = ownersLength;
        threshold = _threshold;
    }
    function addOwnerWithThreshold(address owner, uint256 _threshold) public override authorized {
        if (owner == address(0) || owner == SENTINEL_OWNERS) revertWithError("GS203");
        if (owners[owner] != address(0)) revertWithError("GS204");
        owners[owner] = owners[SENTINEL_OWNERS];
        owners[SENTINEL_OWNERS] = owner;
        ++ownerCount;
        emit AddedOwner(owner);
        if (threshold != _threshold) changeThreshold(_threshold);
    }
    function removeOwner(address prevOwner, address owner, uint256 _threshold) public override authorized {
        if (--ownerCount < _threshold) revertWithError("GS201");
        if (owner == address(0) || owner == SENTINEL_OWNERS) revertWithError("GS203");
        if (owners[prevOwner] != owner) revertWithError("GS205");
        owners[prevOwner] = owners[owner];
        owners[owner] = address(0);
        emit RemovedOwner(owner);
        if (threshold != _threshold) changeThreshold(_threshold);
    }
    function swapOwner(address prevOwner, address oldOwner, address newOwner) public override authorized {
        if (newOwner == address(0) || newOwner == SENTINEL_OWNERS || newOwner == address(this)) revertWithError("GS203");
        if (owners[newOwner] != address(0)) revertWithError("GS204");
        if (oldOwner == address(0) || oldOwner == SENTINEL_OWNERS) revertWithError("GS203");
        if (owners[prevOwner] != oldOwner) revertWithError("GS205");
        owners[newOwner] = owners[oldOwner];
        owners[prevOwner] = newOwner;
        owners[oldOwner] = address(0);
        emit RemovedOwner(oldOwner);
        emit AddedOwner(newOwner);
    }
    function changeThreshold(uint256 _threshold) public override authorized {
        if (_threshold > ownerCount) revertWithError("GS201");
        if (_threshold == 0) revertWithError("GS202");
        threshold = _threshold;
        emit ChangedThreshold(_threshold);
    }
    function getThreshold() public view override returns (uint256) {
        return threshold;
    }
    function isOwner(address owner) public view override returns (bool) {
        return !(owner == SENTINEL_OWNERS || owners[owner] == address(0));
    }
    function getOwners() public view override returns (address[] memory) {
        address[] memory array = new address[](ownerCount);
        uint256 index = 0;
        address currentOwner = owners[SENTINEL_OWNERS];
        while (currentOwner != SENTINEL_OWNERS) {
            array[index] = currentOwner;
            currentOwner = owners[currentOwner];
            ++index;
        }
        return array;
    }
}
--- END FILE: ../safe-smart-account/contracts/base/OwnerManager.sol ---
--- START FILE: ../safe-smart-account/contracts/base/Executor.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Enum} from "../libraries/Enum.sol";
abstract contract Executor {
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 txGas
    ) internal returns (bool success) {
        if (operation == Enum.Operation.DelegateCall) {
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
        } else {
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/base/Executor.sol ---
--- START FILE: ../safe-smart-account/contracts/base/GuardManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SelfAuthorized} from "./../common/SelfAuthorized.sol";
import {IERC165} from "./../interfaces/IERC165.sol";
import {IGuardManager} from "./../interfaces/IGuardManager.sol";
import {Enum} from "./../libraries/Enum.sol";
import {GUARD_STORAGE_SLOT} from "../libraries/SafeStorage.sol";
interface ITransactionGuard is IERC165 {
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external;
    function checkAfterExecution(bytes32 hash, bool success) external;
}
abstract contract BaseTransactionGuard is ITransactionGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(ITransactionGuard).interfaceId || 
            interfaceId == type(IERC165).interfaceId; 
    }
}
abstract contract GuardManager is SelfAuthorized, IGuardManager {
    function setGuard(address guard) external override authorized {
        if (guard != address(0) && !ITransactionGuard(guard).supportsInterface(type(ITransactionGuard).interfaceId))
            revertWithError("GS300");
        assembly {
            sstore(GUARD_STORAGE_SLOT, guard)
        }
        emit ChangedGuard(guard);
    }
    function getGuard() internal view returns (address guard) {
        assembly {
            guard := sload(GUARD_STORAGE_SLOT)
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/base/GuardManager.sol ---
--- START FILE: ../safe-smart-account/contracts/base/ModuleManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SelfAuthorized} from "./../common/SelfAuthorized.sol";
import {IERC165} from "./../interfaces/IERC165.sol";
import {IModuleManager} from "./../interfaces/IModuleManager.sol";
import {Enum} from "./../libraries/Enum.sol";
import {MODULE_GUARD_STORAGE_SLOT} from "./../libraries/SafeStorage.sol";
import {Executor} from "./Executor.sol";
interface IModuleGuard is IERC165 {
    function checkModuleTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        address module
    ) external returns (bytes32 moduleTxHash);
    function checkAfterModuleExecution(bytes32 txHash, bool success) external;
}
abstract contract BaseModuleGuard is IModuleGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(IModuleGuard).interfaceId || 
            interfaceId == type(IERC165).interfaceId; 
    }
}
abstract contract ModuleManager is SelfAuthorized, Executor, IModuleManager {
    address internal constant SENTINEL_MODULES = address(0x1);
    mapping(address => address) internal modules;
    function setupModules(address to, bytes memory data) internal {
        if (modules[SENTINEL_MODULES] != address(0)) revertWithError("GS100");
        modules[SENTINEL_MODULES] = SENTINEL_MODULES;
        if (to != address(0)) {
            if (!isContract(to)) revertWithError("GS002");
            if (!execute(to, 0, data, Enum.Operation.DelegateCall, type(uint256).max)) revertWithError("GS000");
        }
    }
    function preModuleExecution(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) internal returns (address guard, bytes32 guardHash) {
        onBeforeExecTransactionFromModule(to, value, data, operation);
        guard = getModuleGuard();
        if (msg.sender == SENTINEL_MODULES || modules[msg.sender] == address(0)) revertWithError("GS104");
        if (guard != address(0)) {
            guardHash = IModuleGuard(guard).checkModuleTransaction(to, value, data, operation, msg.sender);
        }
    }
    function postModuleExecution(address guard, bytes32 guardHash, bool success) internal {
        if (guard != address(0)) {
            IModuleGuard(guard).checkAfterModuleExecution(guardHash, success);
        }
        if (success) emit ExecutionFromModuleSuccess(msg.sender);
        else emit ExecutionFromModuleFailure(msg.sender);
    }
    function enableModule(address module) public override authorized {
        if (module == address(0) || module == SENTINEL_MODULES) revertWithError("GS101");
        if (modules[module] != address(0)) revertWithError("GS102");
        modules[module] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = module;
        emit EnabledModule(module);
    }
    function disableModule(address prevModule, address module) public override authorized {
        if (module == address(0) || module == SENTINEL_MODULES) revertWithError("GS101");
        if (modules[prevModule] != module) revertWithError("GS103");
        modules[prevModule] = modules[module];
        modules[module] = address(0);
        emit DisabledModule(module);
    }
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external override returns (bool success) {
        (address guard, bytes32 guardHash) = preModuleExecution(to, value, data, operation);
        success = execute(to, value, data, operation, type(uint256).max);
        postModuleExecution(guard, guardHash, success);
    }
    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external override returns (bool success, bytes memory returnData) {
        (address guard, bytes32 guardHash) = preModuleExecution(to, value, data, operation);
        success = execute(to, value, data, operation, type(uint256).max);
        assembly {
            returnData := mload(0x40)
            mstore(0x40, add(returnData, add(returndatasize(), 0x20)))
            mstore(returnData, returndatasize())
            returndatacopy(add(returnData, 0x20), 0, returndatasize())
        }
        postModuleExecution(guard, guardHash, success);
    }
    function isModuleEnabled(address module) public view override returns (bool) {
        return SENTINEL_MODULES != module && modules[module] != address(0);
    }
    function getModulesPaginated(address start, uint256 pageSize) external view override returns (address[] memory array, address next) {
        if (start != SENTINEL_MODULES && !isModuleEnabled(start)) revertWithError("GS105");
        if (pageSize == 0) revertWithError("GS106");
        array = new address[](pageSize);
        uint256 moduleCount = 0;
        next = modules[start];
        while (next != address(0) && next != SENTINEL_MODULES && moduleCount < pageSize) {
            array[moduleCount] = next;
            next = modules[next];
            ++moduleCount;
        }
        if (next != SENTINEL_MODULES) {
            next = array[moduleCount - 1];
        }
        assembly {
            mstore(array, moduleCount)
        }
    }
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function setModuleGuard(address moduleGuard) external override authorized {
        if (moduleGuard != address(0) && !IModuleGuard(moduleGuard).supportsInterface(type(IModuleGuard).interfaceId))
            revertWithError("GS301");
        assembly {
            sstore(MODULE_GUARD_STORAGE_SLOT, moduleGuard)
        }
        emit ChangedModuleGuard(moduleGuard);
    }
    function getModuleGuard() internal view returns (address moduleGuard) {
        assembly {
            moduleGuard := sload(MODULE_GUARD_STORAGE_SLOT)
        }
    }
    function onBeforeExecTransactionFromModule(address to, uint256 value, bytes memory data, Enum.Operation operation) internal virtual {}
}
--- END FILE: ../safe-smart-account/contracts/base/ModuleManager.sol ---
--- START FILE: ../safe-smart-account/contracts/base/FallbackManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SelfAuthorized} from "../common/SelfAuthorized.sol";
import {IFallbackManager} from "../interfaces/IFallbackManager.sol";
import {FALLBACK_HANDLER_STORAGE_SLOT} from "../libraries/SafeStorage.sol";
abstract contract FallbackManager is SelfAuthorized, IFallbackManager {
    function internalSetFallbackHandler(address handler) internal {
        if (handler == address(this)) revertWithError("GS400");
        assembly {
            sstore(FALLBACK_HANDLER_STORAGE_SLOT, handler)
        }
    }
    function setFallbackHandler(address handler) public override authorized {
        internalSetFallbackHandler(handler);
        emit ChangedFallbackHandler(handler);
    }
    fallback() external override {
        assembly {
            let handler := sload(FALLBACK_HANDLER_STORAGE_SLOT)
            if iszero(handler) {
                return(0, 0)
            }
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            mstore(add(ptr, calldatasize()), shl(96, caller()))
            let success := call(gas(), handler, 0, ptr, add(calldatasize(), 20), 0, 0)
            returndatacopy(ptr, 0, returndatasize())
            if iszero(success) {
                revert(ptr, returndatasize())
            }
            return(ptr, returndatasize())
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/base/FallbackManager.sol ---
--- START FILE: ../safe-smart-account/contracts/external/SafeMath.sol ---
pragma solidity >=0.7.0 <0.9.0;
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}
--- END FILE: ../safe-smart-account/contracts/external/SafeMath.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/SafeStorage.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract SafeStorage {
    address internal singleton;
    mapping(address => address) internal modules;
    mapping(address => address) internal owners;
    uint256 internal ownerCount;
    uint256 internal threshold;
    uint256 internal nonce;
    bytes32 internal _deprecatedDomainSeparator;
    mapping(bytes32 => uint256) internal signedMessages;
    mapping(address => mapping(bytes32 => uint256)) internal approvedHashes;
}
bytes32 constant FALLBACK_HANDLER_STORAGE_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
bytes32 constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
bytes32 constant MODULE_GUARD_STORAGE_SLOT = 0xb104e0b93118902c651344349b610029d694cfdec91c589c91ebafbcd0289947;
--- END FILE: ../safe-smart-account/contracts/libraries/SafeStorage.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/SafeToL2Setup.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SafeStorage} from "../libraries/SafeStorage.sol";
contract SafeToL2Setup is SafeStorage {
    address private immutable SELF;
    event ChangedMasterCopy(address singleton);
    constructor() {
        SELF = address(this);
    }
    modifier onlyDelegateCall() {
        require(address(this) != SELF, "SafeToL2Setup should only be called via delegatecall");
        _;
    }
    modifier onlyNonceZero() {
        require(nonce == 0, "Safe must have not executed any tx");
        _;
    }
    modifier onlyContract(address account) {
        require(codeSize(account) != 0, "Account doesn't contain code");
        _;
    }
    function setupToL2(address l2Singleton) external onlyDelegateCall onlyNonceZero onlyContract(l2Singleton) {
        if (chainId() != 1) {
            singleton = l2Singleton;
            emit ChangedMasterCopy(l2Singleton);
        }
    }
    function chainId() private view returns (uint256 result) {
        assembly {
            result := chainid()
        }
    }
    function codeSize(address account) internal view returns (uint256 result) {
        assembly {
            result := extcodesize(account)
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/SafeToL2Setup.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/ErrorMessage.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract ErrorMessage {
    function revertWithError(bytes5 error) internal pure {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) 
            mstore(add(ptr, 0x04), 0x20) 
            mstore(add(ptr, 0x24), 0x05) 
            mstore(add(ptr, 0x44), error) 
            revert(ptr, 0x64) 
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/ErrorMessage.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/Enum.sol ---
pragma solidity >=0.7.0 <0.9.0;
library Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/Enum.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/MultiSend.sol ---
pragma solidity >=0.7.0 <0.9.0;
contract MultiSend {
    address private immutable MULTISEND_SINGLETON;
    constructor() {
        MULTISEND_SINGLETON = address(this);
    }
    function multiSend(bytes memory transactions) public payable {
        require(address(this) != MULTISEND_SINGLETON, "MultiSend should only be called via delegatecall");
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                let operation := shr(0xf8, mload(add(transactions, i)))
                let to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                to := or(to, mul(iszero(to), address()))
                let value := mload(add(transactions, add(i, 0x15)))
                let dataLength := mload(add(transactions, add(i, 0x35)))
                let data := add(transactions, add(i, 0x55))
                let success := 0
                switch operation
                case 0 {
                    success := call(gas(), to, value, data, dataLength, 0, 0)
                }
                case 1 {
                    success := delegatecall(gas(), to, data, dataLength, 0, 0)
                }
                if iszero(success) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/MultiSend.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/CreateCall.sol ---
pragma solidity >=0.7.0 <0.9.0;
contract CreateCall {
    event ContractCreation(address indexed newContract);
    function performCreate2(uint256 value, bytes memory deploymentData, bytes32 salt) public returns (address newContract) {
        assembly {
            newContract := create2(value, add(deploymentData, 0x20), mload(deploymentData), salt)
        }
        require(newContract != address(0), "Could not deploy contract");
        emit ContractCreation(newContract);
    }
    function performCreate(uint256 value, bytes memory deploymentData) public returns (address newContract) {
        assembly {
            newContract := create(value, add(deploymentData, 0x20), mload(deploymentData))
        }
        require(newContract != address(0), "Could not deploy contract");
        emit ContractCreation(newContract);
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/CreateCall.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/MultiSendCallOnly.sol ---
pragma solidity >=0.7.0 <0.9.0;
contract MultiSendCallOnly {
    function multiSend(bytes memory transactions) public payable {
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
            } lt(i, length) {
            } {
                let operation := shr(0xf8, mload(add(transactions, i)))
                let to := shr(0x60, mload(add(transactions, add(i, 0x01))))
                to := or(to, mul(iszero(to), address()))
                let value := mload(add(transactions, add(i, 0x15)))
                let dataLength := mload(add(transactions, add(i, 0x35)))
                let data := add(transactions, add(i, 0x55))
                let success := 0
                switch operation
                case 0 {
                    success := call(gas(), to, value, data, dataLength, 0, 0)
                }
                case 1 {
                    revert(0, 0)
                }
                if iszero(success) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
                i := add(i, add(0x55, dataLength))
            }
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/MultiSendCallOnly.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/SafeMigration.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "./../interfaces/ISafe.sol";
import {SafeStorage} from "./../libraries/SafeStorage.sol";
contract SafeMigration is SafeStorage {
    address public immutable MIGRATION_SINGLETON;
    address public immutable SAFE_SINGLETON;
    address public immutable SAFE_L2_SINGLETON;
    address public immutable SAFE_FALLBACK_HANDLER;
    event ChangedMasterCopy(address singleton);
    modifier onlyDelegateCall() {
        require(address(this) != MIGRATION_SINGLETON, "Migration should only be called via delegatecall");
        _;
    }
    constructor(address safeSingleton, address safeL2Singleton, address fallbackHandler) {
        MIGRATION_SINGLETON = address(this);
        require(hasCode(safeSingleton), "Safe Singleton is not deployed");
        require(hasCode(safeL2Singleton), "Safe Singleton (L2) is not deployed");
        require(hasCode(fallbackHandler), "fallback handler is not deployed");
        SAFE_SINGLETON = safeSingleton;
        SAFE_L2_SINGLETON = safeL2Singleton;
        SAFE_FALLBACK_HANDLER = fallbackHandler;
    }
    function migrateSingleton() public onlyDelegateCall {
        singleton = SAFE_SINGLETON;
        emit ChangedMasterCopy(SAFE_SINGLETON);
    }
    function migrateWithFallbackHandler() external onlyDelegateCall {
        migrateSingleton();
        ISafe(payable(address(this))).setFallbackHandler(SAFE_FALLBACK_HANDLER);
    }
    function migrateL2Singleton() public onlyDelegateCall {
        singleton = SAFE_L2_SINGLETON;
        emit ChangedMasterCopy(SAFE_L2_SINGLETON);
    }
    function migrateL2WithFallbackHandler() external onlyDelegateCall {
        migrateL2Singleton();
        ISafe(payable(address(this))).setFallbackHandler(SAFE_FALLBACK_HANDLER);
    }
    function hasCode(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/SafeMigration.sol ---
--- START FILE: ../safe-smart-account/contracts/libraries/SignMessageLib.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "./../interfaces/ISafe.sol";
import {SafeStorage} from "./SafeStorage.sol";
contract SignMessageLib is SafeStorage {
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
    event SignMsg(bytes32 indexed msgHash);
    function signMessage(bytes calldata _data) external {
        bytes32 msgHash = getMessageHash(_data);
        signedMessages[msgHash] = 1;
        emit SignMsg(msgHash);
    }
    function getMessageHash(bytes memory message) public view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), ISafe(payable(address(this))).domainSeparator(), safeMessageHash));
    }
}
--- END FILE: ../safe-smart-account/contracts/libraries/SignMessageLib.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/README.md ---
# Examples
This subdirectory includes contracts that demonstrate features and modularity of the Safe smart account. They are intended for illustrative purposes only and **should not be considered production code**.
--- END FILE: ../safe-smart-account/contracts/examples/README.md ---
--- START FILE: ../safe-smart-account/contracts/examples/libraries/Migrate_1_3_0_to_1_2_0.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {SafeStorage} from "../../libraries/SafeStorage.sol";
contract Migration is SafeStorage {
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749;
    address public immutable MIGRATION_SINGLETON;
    address public immutable SAFE_120_SINGLETON;
    constructor(address targetSingleton) {
        require(targetSingleton != address(0), "Invalid singleton address provided");
        SAFE_120_SINGLETON = targetSingleton;
        MIGRATION_SINGLETON = address(this);
    }
    event ChangedMasterCopy(address singleton);
    function migrate() public {
        require(address(this) != MIGRATION_SINGLETON, "Migration should only be called via delegatecall");
        singleton = SAFE_120_SINGLETON;
        _deprecatedDomainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, this));
        emit ChangedMasterCopy(singleton);
    }
}
--- END FILE: ../safe-smart-account/contracts/examples/libraries/Migrate_1_3_0_to_1_2_0.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/guards/OnlyOwnersGuard.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {BaseTransactionGuard} from "./../../base/GuardManager.sol";
import {ISafe} from "./../../interfaces/ISafe.sol";
import {Enum} from "./../../libraries/Enum.sol";
contract OnlyOwnersGuard is BaseTransactionGuard {
    constructor() {}
    fallback() external {
    }
    function checkTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address msgSender
    ) external view override {
        require(ISafe(payable(msg.sender)).isOwner(msgSender), "msg sender is not allowed to exec");
    }
    function checkAfterExecution(bytes32, bool) external view override {}
}
--- END FILE: ../safe-smart-account/contracts/examples/guards/OnlyOwnersGuard.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/guards/DelegateCallTransactionGuard.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Enum} from "../../libraries/Enum.sol";
import {BaseGuard} from "./BaseGuard.sol";
contract DelegateCallTransactionGuard is BaseGuard {
    address public immutable ALLOWED_TARGET;
    constructor(address target) {
        ALLOWED_TARGET = target;
    }
    fallback() external {
    }
    function checkTransaction(
        address to,
        uint256,
        bytes memory,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external view override {
        require(operation != Enum.Operation.DelegateCall || to == ALLOWED_TARGET, "This call is restricted");
    }
    function checkAfterExecution(bytes32, bool) external view override {}
    function checkModuleTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        address module
    ) external view override returns (bytes32 moduleTxHash) {
        require(operation != Enum.Operation.DelegateCall || to == ALLOWED_TARGET, "This call is restricted");
        moduleTxHash = keccak256(abi.encodePacked(to, value, data, operation, module));
    }
    function checkAfterModuleExecution(bytes32, bool) external view override {}
}
--- END FILE: ../safe-smart-account/contracts/examples/guards/DelegateCallTransactionGuard.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/guards/BaseGuard.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {BaseTransactionGuard, ITransactionGuard} from "./../../base/GuardManager.sol";
import {BaseModuleGuard, IModuleGuard} from "./../../base/ModuleManager.sol";
import {IERC165} from "./../../interfaces/IERC165.sol";
abstract contract BaseGuard is BaseTransactionGuard, BaseModuleGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual override(BaseTransactionGuard, BaseModuleGuard) returns (bool) {
        return
            interfaceId == type(ITransactionGuard).interfaceId || 
            interfaceId == type(IModuleGuard).interfaceId || 
            interfaceId == type(IERC165).interfaceId; 
    }
}
--- END FILE: ../safe-smart-account/contracts/examples/guards/BaseGuard.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/guards/ReentrancyTransactionGuard.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Enum} from "../../libraries/Enum.sol";
import {BaseGuard} from "./BaseGuard.sol";
contract ReentrancyTransactionGuard is BaseGuard {
    bytes32 internal constant GUARD_STORAGE_SLOT = keccak256("reentrancy_guard.guard.struct");
    struct GuardValue {
        bool active;
    }
    fallback() external {
    }
    function getGuard() internal pure returns (GuardValue storage guard) {
        bytes32 slot = GUARD_STORAGE_SLOT;
        assembly {
            guard.slot := slot
        }
    }
    function checkTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory,
        address
    ) external override {
        GuardValue storage guard = getGuard();
        require(!guard.active, "Reentrancy detected");
        guard.active = true;
    }
    function checkAfterExecution(bytes32, bool) external override {
        getGuard().active = false;
    }
    function checkModuleTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        address module
    ) external override returns (bytes32 moduleTxHash) {
        moduleTxHash = keccak256(abi.encodePacked(to, value, data, operation, module));
        GuardValue storage guard = getGuard();
        require(!guard.active, "Reentrancy detected");
        guard.active = true;
    }
    function checkAfterModuleExecution(bytes32, bool) external override {
        getGuard().active = false;
    }
}
--- END FILE: ../safe-smart-account/contracts/examples/guards/ReentrancyTransactionGuard.sol ---
--- START FILE: ../safe-smart-account/contracts/examples/guards/DebugTransactionGuard.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "./../../interfaces/ISafe.sol";
import {Enum} from "./../../libraries/Enum.sol";
import {BaseGuard} from "./BaseGuard.sol";
contract DebugTransactionGuard is BaseGuard {
    fallback() external {
    }
    event TransactionDetails(
        address indexed safe,
        bytes32 indexed txHash,
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        bool usesRefund,
        uint256 nonce,
        bytes signatures,
        address executor
    );
    event ModuleTransactionDetails(bytes32 indexed txHash, address to, uint256 value, bytes data, Enum.Operation operation, address module);
    event GasUsage(address indexed safe, bytes32 indexed txHash, uint256 indexed nonce, bool success);
    mapping(bytes32 => uint256) public txNonces;
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address executor
    ) external override {
        uint256 nonce;
        bytes32 txHash;
        {
            ISafe safe = ISafe(payable(msg.sender));
            nonce = safe.nonce() - 1;
            txHash = safe.getTransactionHash(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce);
        }
        emit TransactionDetails(msg.sender, txHash, to, value, data, operation, safeTxGas, gasPrice > 0, nonce, signatures, executor);
        txNonces[txHash] = nonce;
    }
    function checkAfterExecution(bytes32 txHash, bool success) external override {
        uint256 nonce = txNonces[txHash];
        require(nonce != 0, "Could not get nonce");
        txNonces[txHash] = 0;
        emit GasUsage(msg.sender, txHash, nonce, success);
    }
    function checkModuleTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        address module
    ) external override returns (bytes32 moduleTxHash) {
        moduleTxHash = keccak256(abi.encodePacked(to, value, data, operation, module));
        emit ModuleTransactionDetails(moduleTxHash, to, value, data, operation, module);
    }
    function checkAfterModuleExecution(bytes32 txHash, bool success) external override {}
}
--- END FILE: ../safe-smart-account/contracts/examples/guards/DebugTransactionGuard.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "./../interfaces/ISafe.sol";
import {ISignatureValidator} from "./../interfaces/ISignatureValidator.sol";
import {Enum} from "./../libraries/Enum.sol";
import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
contract CompatibilityFallbackHandler is TokenCallbackHandler, ISignatureValidator {
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;
    address internal constant SENTINEL_MODULES = address(0x1);
    function getMessageHash(bytes memory message) public view returns (bytes32) {
        return getMessageHashForSafe(ISafe(payable(msg.sender)), message);
    }
    function encodeMessageDataForSafe(ISafe safe, bytes memory message) public view returns (bytes memory) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), safe.domainSeparator(), safeMessageHash);
    }
    function getMessageHashForSafe(ISafe safe, bytes memory message) public view returns (bytes32) {
        return keccak256(encodeMessageDataForSafe(safe, message));
    }
    function isValidSignature(bytes32 _dataHash, bytes calldata _signature) public view override returns (bytes4) {
        ISafe safe = ISafe(payable(msg.sender));
        bytes memory messageData = encodeMessageDataForSafe(safe, abi.encode(_dataHash));
        bytes32 messageHash = keccak256(messageData);
        if (_signature.length == 0) {
            require(safe.signedMessages(messageHash) != 0, "Hash not approved");
        } else {
            safe.checkSignatures(address(0), messageHash, _signature);
        }
        return EIP1271_MAGIC_VALUE;
    }
    function getModules() external view returns (address[] memory) {
        ISafe safe = ISafe(payable(msg.sender));
        (address[] memory array, ) = safe.getModulesPaginated(SENTINEL_MODULES, 10);
        return array;
    }
    function simulate(address targetContract, bytes calldata calldataPayload) external returns (bytes memory response) {
        targetContract;
        calldataPayload;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\xb4\xfa\xba\x09")
            calldatacopy(add(ptr, 0x04), 0x04, sub(calldatasize(), 0x04))
            let success := call(
                gas(),
                caller(),
                0,
                ptr,
                calldatasize(),
                0x00,
                0x40
            )
            if or(success, lt(returndatasize(), 0x40)) {
                revert(0, 0)
            }
            let responseEncodedSize := add(mload(0x20), 0x20)
            response := mload(0x40)
            mstore(0x40, add(response, responseEncodedSize))
            returndatacopy(response, 0x20, responseEncodedSize)
            if iszero(mload(0x00)) {
                revert(add(response, 0x20), responseEncodedSize)
            }
        }
    }
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) public view returns (bytes memory) {
        ISafe safe = ISafe(payable(msg.sender));
        bytes32 domainSeparator = safe.domainSeparator();
        bytes32 safeTxHash = keccak256(
            abi.encode(
                SAFE_TX_TYPEHASH,
                to,
                value,
                keccak256(data),
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                nonce
            )
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, safeTxHash);
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/HandlerContext.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "../interfaces/ISafe.sol";
import {FALLBACK_HANDLER_STORAGE_SLOT} from "../libraries/SafeStorage.sol";
abstract contract HandlerContext {
    modifier onlyFallback() {
        _requireFallback();
        _;
    }
    function _requireFallback() internal view {
        bytes memory storageData = ISafe(payable(msg.sender)).getStorageAt(uint256(FALLBACK_HANDLER_STORAGE_SLOT), 1);
        address fallbackHandler = abi.decode(storageData, (address));
        require(fallbackHandler == address(this), "not a fallback call");
    }
    function _msgSender() internal pure returns (address sender) {
        require(msg.data.length >= 20, "Invalid calldata length");
        assembly {
            sender := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
    function _manager() internal view returns (address) {
        return msg.sender;
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/HandlerContext.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/ExtensibleFallbackHandler.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ERC165Handler} from "./extensible/ERC165Handler.sol";
import {IFallbackHandler, FallbackHandler} from "./extensible/FallbackHandler.sol";
import {ERC1271, ISignatureVerifierMuxer, SignatureVerifierMuxer} from "./extensible/SignatureVerifierMuxer.sol";
import {ERC721TokenReceiver, ERC1155TokenReceiver, TokenCallbacks} from "./extensible/TokenCallbacks.sol";
contract ExtensibleFallbackHandler is FallbackHandler, SignatureVerifierMuxer, TokenCallbacks, ERC165Handler {
    function _supportsInterface(bytes4 interfaceId) internal pure override returns (bool) {
        return
            interfaceId == type(ERC721TokenReceiver).interfaceId ||
            interfaceId == type(ERC1155TokenReceiver).interfaceId ||
            interfaceId == type(ERC1271).interfaceId ||
            interfaceId == type(ISignatureVerifierMuxer).interfaceId ||
            interfaceId == type(ERC165Handler).interfaceId ||
            interfaceId == type(IFallbackHandler).interfaceId;
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/ExtensibleFallbackHandler.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/TokenCallbackHandler.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ERC1155TokenReceiver} from "../interfaces/ERC1155TokenReceiver.sol";
import {ERC721TokenReceiver} from "../interfaces/ERC721TokenReceiver.sol";
import {ERC777TokensRecipient} from "../interfaces/ERC777TokensRecipient.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {HandlerContext} from "./HandlerContext.sol";
contract TokenCallbackHandler is HandlerContext, ERC1155TokenReceiver, ERC777TokensRecipient, ERC721TokenReceiver, IERC165 {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external view override onlyFallback returns (bytes4) {
        return 0xf23a6e61;
    }
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external view override onlyFallback returns (bytes4) {
        return 0xbc197c81;
    }
    function onERC721Received(address, address, uint256, bytes calldata) external view override onlyFallback returns (bytes4) {
        return 0x150b7a02;
    }
    function tokensReceived(address, address, address, uint256, bytes calldata, bytes calldata) external pure override {
    }
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(ERC1155TokenReceiver).interfaceId ||
            interfaceId == type(ERC721TokenReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/TokenCallbackHandler.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/ExtensibleBase.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe} from "../../interfaces/ISafe.sol";
import {HandlerContext} from "../HandlerContext.sol";
import {MarshalLib} from "./MarshalLib.sol";
interface IFallbackMethod {
    function handle(ISafe safe, address sender, uint256 value, bytes calldata data) external returns (bytes memory result);
}
interface IStaticFallbackMethod {
    function handle(ISafe safe, address sender, uint256 value, bytes calldata data) external view returns (bytes memory result);
}
abstract contract ExtensibleBase is HandlerContext {
    event ChangedSafeMethod(ISafe indexed safe, bytes4 selector, bytes32 oldMethod, bytes32 newMethod);
    mapping(ISafe => mapping(bytes4 => bytes32)) public safeMethods;
    modifier onlySelf() {
        require(_msgSender() == _manager(), "only safe can call this method");
        _;
    }
    function _setSafeMethod(ISafe safe, bytes4 selector, bytes32 newMethod) internal {
        mapping(bytes4 => bytes32) storage safeMethod = safeMethods[safe];
        bytes32 oldMethod = safeMethod[selector];
        (, address newHandler) = MarshalLib.decode(newMethod);
        if (address(newHandler) == address(0)) {
            newMethod = bytes32(0);
        }
        safeMethod[selector] = newMethod;
        emit ChangedSafeMethod(safe, selector, oldMethod, newMethod);
    }
    function _getContext() internal view returns (ISafe safe, address sender) {
        safe = ISafe(payable(_manager()));
        sender = _msgSender();
    }
    function _getContextAndHandler() internal view returns (ISafe safe, address sender, bool isStatic, address handler) {
        (safe, sender) = _getContext();
        (isStatic, handler) = MarshalLib.decode(safeMethods[safe][msg.sig]);
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/ExtensibleBase.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/MarshalLib.sol ---
pragma solidity >=0.7.0 <0.9.0;
library MarshalLib {
    function encode(bool isStatic, address handler) internal pure returns (bytes32 data) {
        data = bytes32(uint256(uint160(handler)) | (isStatic ? 0 : (1 << 248)));
    }
    function encodeWithSelector(bool isStatic, bytes4 selector, address handler) internal pure returns (bytes32 data) {
        data = bytes32(uint256(uint160(handler)) | (isStatic ? 0 : (1 << 248)) | (uint256(uint32(selector)) << 216));
    }
    function decode(bytes32 data) internal pure returns (bool isStatic, address handler) {
        assembly {
            isStatic := iszero(shr(248, data))
            handler := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }
    function decodeWithSelector(bytes32 data) internal pure returns (bool isStatic, bytes4 selector, address handler) {
        assembly {
            isStatic := iszero(shr(248, data))
            handler := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            selector := shl(168, shr(160, data))
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/MarshalLib.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/ERC165Handler.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {IERC165} from "../../interfaces/IERC165.sol";
import {ISafe, MarshalLib, ExtensibleBase} from "./ExtensibleBase.sol";
interface IERC165Handler {
    function safeInterfaces(ISafe safe, bytes4 interfaceId) external view returns (bool);
    function setSupportedInterface(bytes4 interfaceId, bool supported) external;
    function addSupportedInterfaceBatch(bytes4 interfaceId, bytes32[] calldata handlerWithSelectors) external;
    function removeSupportedInterfaceBatch(bytes4 interfaceId, bytes4[] calldata selectors) external;
}
abstract contract ERC165Handler is ExtensibleBase, IERC165Handler {
    event AddedInterface(ISafe indexed safe, bytes4 interfaceId);
    event RemovedInterface(ISafe indexed safe, bytes4 interfaceId);
    mapping(ISafe => mapping(bytes4 => bool)) public override safeInterfaces;
    function setSupportedInterface(bytes4 interfaceId, bool supported) public override onlySelf {
        ISafe safe = ISafe(payable(_manager()));
        require(interfaceId != 0xffffffff, "invalid interface id");
        mapping(bytes4 => bool) storage safeInterface = safeInterfaces[safe];
        bool current = safeInterface[interfaceId];
        if (supported != current) {
            safeInterface[interfaceId] = supported;
            if (supported) {
                emit AddedInterface(safe, interfaceId);
            } else {
                emit RemovedInterface(safe, interfaceId);
            }
        }
    }
    function addSupportedInterfaceBatch(bytes4 _interfaceId, bytes32[] calldata handlerWithSelectors) external override onlySelf {
        ISafe safe = ISafe(payable(_msgSender()));
        bytes4 interfaceId = bytes4(0);
        uint256 len = handlerWithSelectors.length;
        for (uint256 i = 0; i < len; ++i) {
            (bool isStatic, bytes4 selector, address handlerAddress) = MarshalLib.decodeWithSelector(handlerWithSelectors[i]);
            _setSafeMethod(safe, selector, MarshalLib.encode(isStatic, handlerAddress));
            interfaceId ^= selector;
        }
        require(interfaceId == _interfaceId, "interface id mismatch");
        setSupportedInterface(_interfaceId, true);
    }
    function removeSupportedInterfaceBatch(bytes4 _interfaceId, bytes4[] calldata selectors) external override onlySelf {
        ISafe safe = ISafe(payable(_msgSender()));
        bytes4 interfaceId = bytes4(0);
        uint256 len = selectors.length;
        for (uint256 i = 0; i < len; ++i) {
            _setSafeMethod(safe, selectors[i], bytes32(0));
            interfaceId ^= selectors[i];
        }
        require(interfaceId == _interfaceId, "interface id mismatch");
        setSupportedInterface(_interfaceId, false);
    }
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC165Handler).interfaceId ||
            _supportsInterface(interfaceId) ||
            safeInterfaces[ISafe(payable(_manager()))][interfaceId];
    }
    function _supportsInterface(bytes4 interfaceId) internal view virtual returns (bool);
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/ERC165Handler.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/SignatureVerifierMuxer.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe, ExtensibleBase} from "./ExtensibleBase.sol";
interface ERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}
interface ISafeSignatureVerifier {
    function isValidSafeSignature(
        ISafe safe,
        address sender,
        bytes32 _hash,
        bytes32 domainSeparator,
        bytes32 typeHash,
        bytes calldata encodeData,
        bytes calldata payload
    ) external view returns (bytes4 magic);
}
interface ISignatureVerifierMuxer {
    function domainVerifiers(ISafe safe, bytes32 domainSeparator) external view returns (ISafeSignatureVerifier);
    function setDomainVerifier(bytes32 domainSeparator, ISafeSignatureVerifier verifier) external;
}
abstract contract SignatureVerifierMuxer is ExtensibleBase, ERC1271, ISignatureVerifierMuxer {
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
    bytes4 private constant SAFE_SIGNATURE_MAGIC_VALUE = 0x5fd7e97d;
    mapping(ISafe => mapping(bytes32 => ISafeSignatureVerifier)) public override domainVerifiers;
    event ChangedDomainVerifier(
        ISafe indexed safe,
        bytes32 domainSeparator,
        ISafeSignatureVerifier oldVerifier,
        ISafeSignatureVerifier newVerifier
    );
    function setDomainVerifier(bytes32 domainSeparator, ISafeSignatureVerifier newVerifier) public override onlySelf {
        ISafe safe = ISafe(payable(_msgSender()));
        ISafeSignatureVerifier oldVerifier = domainVerifiers[safe][domainSeparator];
        domainVerifiers[safe][domainSeparator] = newVerifier;
        emit ChangedDomainVerifier(safe, domainSeparator, oldVerifier, newVerifier);
    }
    function isValidSignature(bytes32 _hash, bytes calldata signature) external view override returns (bytes4 magic) {
        (ISafe safe, address sender) = _getContext();
        if (signature.length >= 4) {
            bytes4 sigSelector;
            assembly {
                sigSelector := calldataload(signature.offset)
            }
            if (sigSelector == SAFE_SIGNATURE_MAGIC_VALUE && signature.length >= 68) {
                (bytes32 domainSeparator, bytes32 typeHash) = abi.decode(signature[4:68], (bytes32, bytes32));
                ISafeSignatureVerifier verifier = domainVerifiers[safe][domainSeparator];
                if (address(verifier) != address(0)) {
                    (, , bytes memory encodeData, bytes memory payload) = abi.decode(signature[4:], (bytes32, bytes32, bytes, bytes));
                    if (keccak256(EIP712.encodeMessageData(domainSeparator, typeHash, encodeData)) == _hash) {
                        return verifier.isValidSafeSignature(safe, sender, _hash, domainSeparator, typeHash, encodeData, payload);
                    }
                }
            }
        }
        return defaultIsValidSignature(safe, _hash, signature);
    }
    function defaultIsValidSignature(ISafe safe, bytes32 _hash, bytes memory signature) internal view returns (bytes4 magic) {
        bytes memory messageData = EIP712.encodeMessageData(
            safe.domainSeparator(),
            SAFE_MSG_TYPEHASH,
            abi.encode(keccak256(abi.encode(_hash)))
        );
        bytes32 messageHash = keccak256(messageData);
        if (signature.length == 0) {
            require(safe.signedMessages(messageHash) != 0, "Hash not approved");
        } else {
            safe.checkSignatures(address(0), messageHash, signature);
        }
        magic = ERC1271.isValidSignature.selector;
    }
}
library EIP712 {
    function encodeMessageData(bytes32 domainSeparator, bytes32 typeHash, bytes memory message) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, keccak256(abi.encodePacked(typeHash, message)));
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/SignatureVerifierMuxer.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/FallbackHandler.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ISafe, IStaticFallbackMethod, IFallbackMethod, ExtensibleBase} from "./ExtensibleBase.sol";
interface IFallbackHandler {
    function setSafeMethod(bytes4 selector, bytes32 newMethod) external;
}
abstract contract FallbackHandler is ExtensibleBase, IFallbackHandler {
    function setSafeMethod(bytes4 selector, bytes32 newMethod) public override onlySelf {
        _setSafeMethod(ISafe(payable(_msgSender())), selector, newMethod);
    }
    fallback(bytes calldata) external returns (bytes memory result) {
        require(msg.data.length >= 24, "invalid method selector");
        (ISafe safe, address sender, bool isStatic, address handler) = _getContextAndHandler();
        require(handler != address(0), "method handler not set");
        if (isStatic) {
            result = IStaticFallbackMethod(handler).handle(safe, sender, 0, msg.data[:msg.data.length - 20]);
        } else {
            result = IFallbackMethod(handler).handle(safe, sender, 0, msg.data[:msg.data.length - 20]);
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/FallbackHandler.sol ---
--- START FILE: ../safe-smart-account/contracts/handler/extensible/TokenCallbacks.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ERC1155TokenReceiver} from "../../interfaces/ERC1155TokenReceiver.sol";
import {ERC721TokenReceiver} from "../../interfaces/ERC721TokenReceiver.sol";
import {ExtensibleBase} from "./ExtensibleBase.sol";
abstract contract TokenCallbacks is ExtensibleBase, ERC1155TokenReceiver, ERC721TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external view override onlyFallback returns (bytes4) {
        return 0xf23a6e61;
    }
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external view override onlyFallback returns (bytes4) {
        return 0xbc197c81;
    }
    function onERC721Received(address, address, uint256, bytes calldata) external view override onlyFallback returns (bytes4) {
        return 0x150b7a02;
    }
}
--- END FILE: ../safe-smart-account/contracts/handler/extensible/TokenCallbacks.sol ---
--- START FILE: ../safe-smart-account/contracts/accessors/SimulateTxAccessor.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Executor, Enum} from "../base/Executor.sol";
contract SimulateTxAccessor is Executor {
    address private immutable ACCESSOR_SINGLETON;
    constructor() {
        ACCESSOR_SINGLETON = address(this);
    }
    modifier onlyDelegateCall() {
        require(address(this) != ACCESSOR_SINGLETON, "SimulateTxAccessor should only be called via delegatecall");
        _;
    }
    function simulate(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external onlyDelegateCall returns (uint256 estimate, bool success, bytes memory returnData) {
        uint256 startGas = gasleft();
        success = execute(to, value, data, operation, gasleft());
        estimate = startGas - gasleft();
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            mstore(ptr, returndatasize())
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            returnData := ptr
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/accessors/SimulateTxAccessor.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IStorageAccessible.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IStorageAccessible {
    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
    function simulateAndRevert(address targetContract, bytes memory calldataPayload) external;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IStorageAccessible.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ViewStorageAccessible.sol ---
pragma solidity >=0.5.0 <0.9.0;
interface ViewStorageAccessible {
    function simulate(address targetContract, bytes calldata calldataPayload) external view returns (bytes memory);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ViewStorageAccessible.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ERC1155TokenReceiver.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface ERC1155TokenReceiver {
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4);
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ERC1155TokenReceiver.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IFallbackManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IFallbackManager {
    event ChangedFallbackHandler(address indexed handler);
    function setFallbackHandler(address handler) external;
    fallback() external;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IFallbackManager.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ISafe.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Enum} from "./../libraries/Enum.sol";
import {IFallbackManager} from "./IFallbackManager.sol";
import {IGuardManager} from "./IGuardManager.sol";
import {IModuleManager} from "./IModuleManager.sol";
import {INativeCurrencyPaymentFallback} from "./INativeCurrencyPaymentFallback.sol";
import {IOwnerManager} from "./IOwnerManager.sol";
import {IStorageAccessible} from "./IStorageAccessible.sol";
interface ISafe is INativeCurrencyPaymentFallback, IModuleManager, IGuardManager, IOwnerManager, IFallbackManager, IStorageAccessible {
    event SafeSetup(address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler);
    event ApproveHash(bytes32 indexed approvedHash, address indexed owner);
    event SignMsg(bytes32 indexed msgHash);
    event ExecutionFailure(bytes32 indexed txHash, uint256 payment);
    event ExecutionSuccess(bytes32 indexed txHash, uint256 payment);
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
    function checkSignatures(address executor, bytes32 dataHash, bytes memory signatures) external view;
    function checkNSignatures(address executor, bytes32 dataHash, bytes memory signatures, uint256 requiredSignatures) external view;
    function approveHash(bytes32 hashToApprove) external;
    function domainSeparator() external view returns (bytes32);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
    function VERSION() external view returns (string memory);
    function nonce() external view returns (uint256);
    function signedMessages(bytes32 messageHash) external view returns (uint256);
    function approvedHashes(address owner, bytes32 messageHash) external view returns (uint256);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ISafe.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ERC721TokenReceiver.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns (bytes4);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ERC721TokenReceiver.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IERC165.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IERC165.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/INativeCurrencyPaymentFallback.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface INativeCurrencyPaymentFallback {
    event SafeReceived(address indexed sender, uint256 value);
    receive() external payable;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/INativeCurrencyPaymentFallback.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ISignatureValidator.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract ISignatureValidatorConstants {
    bytes4 internal constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
}
abstract contract ISignatureValidator is ISignatureValidatorConstants {
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view virtual returns (bytes4);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ISignatureValidator.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/ERC777TokensRecipient.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface ERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/ERC777TokensRecipient.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IModuleManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {Enum} from "../libraries/Enum.sol";
interface IModuleManager {
    event EnabledModule(address indexed module);
    event DisabledModule(address indexed module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);
    event ChangedModuleGuard(address indexed moduleGuard);
    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external returns (bool success);
    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external returns (bool success, bytes memory returnData);
    function isModuleEnabled(address module) external view returns (bool);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory array, address next);
    function setModuleGuard(address moduleGuard) external;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IModuleManager.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IGuardManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IGuardManager {
    event ChangedGuard(address indexed guard);
    function setGuard(address guard) external;
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IGuardManager.sol ---
--- START FILE: ../safe-smart-account/contracts/interfaces/IOwnerManager.sol ---
pragma solidity >=0.7.0 <0.9.0;
interface IOwnerManager {
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 _threshold) external;
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function changeThreshold(uint256 _threshold) external;
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}
--- END FILE: ../safe-smart-account/contracts/interfaces/IOwnerManager.sol ---
--- START FILE: ../safe-smart-account/contracts/common/SignatureDecoder.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract SignatureDecoder {
    function signatureSplit(bytes memory signatures, uint256 pos) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := byte(0, mload(add(signatures, add(signaturePos, 0x60))))
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/common/SignatureDecoder.sol ---
--- START FILE: ../safe-smart-account/contracts/common/NativeCurrencyPaymentFallback.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {INativeCurrencyPaymentFallback} from "./../interfaces/INativeCurrencyPaymentFallback.sol";
abstract contract NativeCurrencyPaymentFallback is INativeCurrencyPaymentFallback {
    receive() external payable override {
        emit SafeReceived(msg.sender, msg.value);
    }
}
--- END FILE: ../safe-smart-account/contracts/common/NativeCurrencyPaymentFallback.sol ---
--- START FILE: ../safe-smart-account/contracts/common/StorageAccessible.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {IStorageAccessible} from "../interfaces/IStorageAccessible.sol";
abstract contract StorageAccessible is IStorageAccessible {
    function getStorageAt(uint256 offset, uint256 length) public view override returns (bytes memory) {
        bytes memory result = new bytes(length << 5);
        for (uint256 index = 0; index < length; ++index) {
            assembly {
                let word := sload(add(offset, index))
                mstore(add(add(result, 0x20), mul(index, 0x20)), word)
            }
        }
        return result;
    }
    function simulateAndRevert(address targetContract, bytes memory calldataPayload) external override {
        assembly {
            let success := delegatecall(gas(), targetContract, add(calldataPayload, 0x20), mload(calldataPayload), 0, 0)
            let ptr := mload(0x40)
            mstore(ptr, success)
            mstore(add(ptr, 0x20), returndatasize())
            returndatacopy(add(ptr, 0x40), 0, returndatasize())
            revert(ptr, add(returndatasize(), 0x40))
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/common/StorageAccessible.sol ---
--- START FILE: ../safe-smart-account/contracts/common/SelfAuthorized.sol ---
pragma solidity >=0.7.0 <0.9.0;
import {ErrorMessage} from "../libraries/ErrorMessage.sol";
abstract contract SelfAuthorized is ErrorMessage {
    function requireSelfCall() private view {
        if (msg.sender != address(this)) revertWithError("GS031");
    }
    modifier authorized() {
        requireSelfCall();
        _;
    }
}
--- END FILE: ../safe-smart-account/contracts/common/SelfAuthorized.sol ---
--- START FILE: ../safe-smart-account/contracts/common/Singleton.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract Singleton {
    address private singleton;
}
--- END FILE: ../safe-smart-account/contracts/common/Singleton.sol ---
--- START FILE: ../safe-smart-account/contracts/common/SecuredTokenTransfer.sol ---
pragma solidity >=0.7.0 <0.9.0;
abstract contract SecuredTokenTransfer {
    function transferToken(address token, address receiver, uint256 amount) internal returns (bool transferred) {
        bytes memory data = abi.encodeWithSelector(0xa9059cbb, receiver, amount);
        assembly {
            let success := call(sub(gas(), 10000), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            switch returndatasize()
            case 0 {
                transferred := success
            }
            case 0x20 {
                transferred := iszero(or(iszero(success), iszero(mload(0))))
            }
            default {
                transferred := 0
            }
        }
    }
}
--- END FILE: ../safe-smart-account/contracts/common/SecuredTokenTransfer.sol ---