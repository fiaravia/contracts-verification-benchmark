--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/SiloVaultsFactory.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";

import {SiloVault} from "./SiloVault.sol";
import {VaultIncentivesModule} from "./incentives/VaultIncentivesModule.sol";

/// @title SiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create SiloVault vaults, and to index them easily.
contract SiloVaultsFactory is ISiloVaultsFactory {
    /* STORAGE */
    address public immutable VAULT_INCENTIVES_MODULE_IMPLEMENTATION;

    /// @inheritdoc ISiloVaultsFactory
    mapping(address => bool) public isSiloVault;

    /* CONSTRUCTOR */

    constructor() {
        VAULT_INCENTIVES_MODULE_IMPLEMENTATION = address(new VaultIncentivesModule(msg.sender));
    }

    /* EXTERNAL */

    /// @inheritdoc ISiloVaultsFactory
    function createSiloVault(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol
    ) external virtual returns (ISiloVault siloVault) {
        VaultIncentivesModule vaultIncentivesModule = VaultIncentivesModule(
            Clones.clone(VAULT_INCENTIVES_MODULE_IMPLEMENTATION)
        );

        siloVault = ISiloVault(address(
            new SiloVault(initialOwner, initialTimelock, vaultIncentivesModule, asset, name, symbol))
        );

        isSiloVault[address(siloVault)] = true;

        emit EventsLib.CreateSiloVault(
            address(siloVault), msg.sender, initialOwner, initialTimelock, asset, name, symbol
        );
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/SiloVaultsFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/IdleVault.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ERC20, ERC4626} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

contract IdleVault is ERC4626 {
    /// @dev this is the only user that is allowed to deposit
    address public immutable ONLY_DEPOSITOR;

    /// @dev Initializes the contract.
    /// @param onlyDepositor The only user allowed to use vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address onlyDepositor,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) {
        if (onlyDepositor == address(0)) revert ErrorsLib.ZeroAddress();

        ONLY_DEPOSITOR = onlyDepositor;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address _depositor) public view virtual override returns (uint256) {
        return _depositor != ONLY_DEPOSITOR ? 0 : super.maxDeposit(_depositor);
    }

    /// @inheritdoc IERC4626
    function maxMint(address _depositor) public view virtual override returns (uint256) {
        return _depositor != ONLY_DEPOSITOR ? 0 : super.maxMint(_depositor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        if (_receiver != ONLY_DEPOSITOR) revert();

        return super.deposit(_assets, _receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public virtual override returns (uint256 assets) {
        if (_receiver != ONLY_DEPOSITOR) revert();

        return super.mint(_shares, _receiver);
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/IdleVault.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/SiloVault.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {ERC4626, Math} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {IERC4626, IERC20, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {Multicall} from "openzeppelin5/utils/Multicall.sol";
import {ERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {
    MarketConfig,
    PendingUint192,
    PendingAddress,
    MarketAllocation,
    ISiloVaultBase,
    ISiloVaultStaticTyping
} from "./interfaces/ISiloVault.sol";

import {INotificationReceiver} from "./interfaces/INotificationReceiver.sol";
import {IVaultIncentivesModule} from "./interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "./interfaces/IIncentivesClaimingLogic.sol";


import {PendingUint192, PendingAddress, PendingLib} from "./libraries/PendingLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title SiloVault
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice ERC4626 compliant vault allowing users to deposit assets to any ERC4626 vault.
contract SiloVault is ERC4626, ERC20Permit, Ownable2Step, Multicall, ISiloVaultStaticTyping {
    uint256 constant WAD = 1e18;

    using Math for uint256;
    using SafeERC20 for IERC20;
    using PendingLib for PendingUint192;
    using PendingLib for PendingAddress;

    /* IMMUTABLES */
    
    /// @notice OpenZeppelin decimals offset used by the ERC4626 implementation.
    /// @dev Calculated to be max(0, 18 - underlyingDecimals) at construction, so the initial conversion rate maximizes
    /// precision between shares and assets.
    uint8 public immutable DECIMALS_OFFSET;

    IVaultIncentivesModule public immutable INCENTIVES_MODULE;

    /* STORAGE */

    /// @inheritdoc ISiloVaultBase
    address public curator;

    /// @inheritdoc ISiloVaultBase
    mapping(address => bool) public isAllocator;

    /// @inheritdoc ISiloVaultBase
    address public guardian;

    /// @inheritdoc ISiloVaultStaticTyping
    mapping(IERC4626 => MarketConfig) public config;

    /// @inheritdoc ISiloVaultBase
    uint256 public timelock;

    /// @inheritdoc ISiloVaultStaticTyping
    PendingAddress public pendingGuardian;

    /// @inheritdoc ISiloVaultStaticTyping
    mapping(IERC4626 => PendingUint192) public pendingCap;

    /// @inheritdoc ISiloVaultStaticTyping
    PendingUint192 public pendingTimelock;

    /// @inheritdoc ISiloVaultBase
    uint96 public fee;

    /// @inheritdoc ISiloVaultBase
    address public feeRecipient;

    /// @inheritdoc ISiloVaultBase
    address public skimRecipient;

    /// @inheritdoc ISiloVaultBase
    IERC4626[] public supplyQueue;

    /// @inheritdoc ISiloVaultBase
    IERC4626[] public withdrawQueue;

    /// @inheritdoc ISiloVaultBase
    uint256 public lastTotalAssets;

    bool transient _lock;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param _owner The owner of the contract.
    /// @param _initialTimelock The initial timelock.
    /// @param _vaultIncentivesModule The vault incentives module.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address _owner,
        uint256 _initialTimelock,
        IVaultIncentivesModule _vaultIncentivesModule,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20Permit(_name) ERC20(_name, _symbol) Ownable(_owner) {
        require(_asset != address(0), ErrorsLib.ZeroAddress());
        require(address(_vaultIncentivesModule) != address(0), ErrorsLib.ZeroAddress());

        DECIMALS_OFFSET = uint8(UtilsLib.zeroFloorSub(18, IERC20Metadata(_asset).decimals()));

        _checkTimelockBounds(_initialTimelock);
        _setTimelock(_initialTimelock);
        INCENTIVES_MODULE = _vaultIncentivesModule;
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller doesn't have the curator role.
    modifier onlyCuratorRole() {
        address sender = _msgSender();
        if (sender != curator && sender != owner()) revert ErrorsLib.NotCuratorRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the allocator role.
    modifier onlyAllocatorRole() {
        address sender = _msgSender();
        if (!isAllocator[sender] && sender != curator && sender != owner()) {
            revert ErrorsLib.NotAllocatorRole();
        }

        _;
    }

    /// @dev Reverts if the caller doesn't have the guardian role.
    modifier onlyGuardianRole() {
        if (_msgSender() != owner() && _msgSender() != guardian) revert ErrorsLib.NotGuardianRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the curator nor the guardian role.
    modifier onlyCuratorOrGuardianRole() {
        if (_msgSender() != guardian && _msgSender() != curator && _msgSender() != owner()) {
            revert ErrorsLib.NotCuratorNorGuardianRole();
        }

        _;
    }

    /// @dev Makes sure conditions are met to accept a pending value.
    /// @dev Reverts if:
    /// - there's no pending value;
    /// - the timelock has not elapsed since the pending value has been submitted.
    modifier afterTimelock(uint256 _validAt) {
        if (_validAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < _validAt) revert ErrorsLib.TimelockNotElapsed();

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc ISiloVaultBase
    function setCurator(address _newCurator) external virtual onlyOwner {
        if (_newCurator == curator) revert ErrorsLib.AlreadySet();

        curator = _newCurator;

        emit EventsLib.SetCurator(_newCurator);
    }

    /// @inheritdoc ISiloVaultBase
    function setIsAllocator(address _newAllocator, bool _newIsAllocator) external virtual onlyOwner {
        if (isAllocator[_newAllocator] == _newIsAllocator) revert ErrorsLib.AlreadySet();

        isAllocator[_newAllocator] = _newIsAllocator;

        emit EventsLib.SetIsAllocator(_newAllocator, _newIsAllocator);
    }

    /// @inheritdoc ISiloVaultBase
    function setSkimRecipient(address _newSkimRecipient) external virtual onlyOwner {
        if (_newSkimRecipient == skimRecipient) revert ErrorsLib.AlreadySet();

        skimRecipient = _newSkimRecipient;

        emit EventsLib.SetSkimRecipient(_newSkimRecipient);
    }

    /// @inheritdoc ISiloVaultBase
    function submitTimelock(uint256 _newTimelock) external virtual onlyOwner {
        if (_newTimelock == timelock) revert ErrorsLib.AlreadySet();
        if (pendingTimelock.validAt != 0) revert ErrorsLib.AlreadyPending();
        _checkTimelockBounds(_newTimelock);

        if (_newTimelock > timelock) {
            _setTimelock(_newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock.update(uint184(_newTimelock), timelock);

            emit EventsLib.SubmitTimelock(_newTimelock);
        }
    }

    /// @inheritdoc ISiloVaultBase
    function setFee(uint256 _newFee) external virtual onlyOwner {
        if (_newFee == fee) revert ErrorsLib.AlreadySet();
        if (_newFee > ConstantsLib.MAX_FEE) revert ErrorsLib.MaxFeeExceeded();
        if (_newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(_newFee);

        emit EventsLib.SetFee(_msgSender(), fee);
    }

    /// @inheritdoc ISiloVaultBase
    function setFeeRecipient(address _newFeeRecipient) external virtual onlyOwner {
        if (_newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();
        if (_newFeeRecipient == address(0) && fee != 0) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = _newFeeRecipient;

        emit EventsLib.SetFeeRecipient(_newFeeRecipient);
    }

    /// @inheritdoc ISiloVaultBase
    function submitGuardian(address _newGuardian) external virtual onlyOwner {
        if (_newGuardian == guardian) revert ErrorsLib.AlreadySet();
        if (pendingGuardian.validAt != 0) revert ErrorsLib.AlreadyPending();

        if (guardian == address(0)) {
            _setGuardian(_newGuardian);
        } else {
            pendingGuardian.update(_newGuardian, timelock);

            emit EventsLib.SubmitGuardian(_newGuardian);
        }
    }

    /* ONLY CURATOR FUNCTIONS */

    /// @inheritdoc ISiloVaultBase
    function submitCap(IERC4626 _market, uint256 _newSupplyCap) external virtual onlyCuratorRole {
        if (_market.asset() != asset()) revert ErrorsLib.InconsistentAsset(_market);
        if (pendingCap[_market].validAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[_market].removableAt != 0) revert ErrorsLib.PendingRemoval();
        uint256 supplyCap = config[_market].cap;
        if (_newSupplyCap == supplyCap) revert ErrorsLib.AlreadySet();

        if (_newSupplyCap < supplyCap) {
            _setCap(_market, SafeCast.toUint184(_newSupplyCap));
        } else {
            pendingCap[_market].update(SafeCast.toUint184(_newSupplyCap), timelock);

            emit EventsLib.SubmitCap(_msgSender(), _market, _newSupplyCap);
        }
    }

    /// @inheritdoc ISiloVaultBase
    function submitMarketRemoval(IERC4626 _market) external virtual onlyCuratorRole {
        if (config[_market].removableAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[_market].cap != 0) revert ErrorsLib.NonZeroCap();
        if (!config[_market].enabled) revert ErrorsLib.MarketNotEnabled(_market);
        if (pendingCap[_market].validAt != 0) revert ErrorsLib.PendingCap(_market);

        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        config[_market].removableAt = uint64(block.timestamp + timelock);

        emit EventsLib.SubmitMarketRemoval(_msgSender(), _market);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @inheritdoc ISiloVaultBase
    function setSupplyQueue(IERC4626[] calldata _newSupplyQueue) external virtual onlyAllocatorRole {
        _nonReentrantOn();

        uint256 length = _newSupplyQueue.length;

        if (length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

        for (uint256 i; i < length; ++i) {
            IERC4626 market = _newSupplyQueue[i];
            if (config[market].cap == 0) revert ErrorsLib.UnauthorizedMarket(market);
        }

        supplyQueue = _newSupplyQueue;

        emit EventsLib.SetSupplyQueue(_msgSender(), _newSupplyQueue);

        _nonReentrantOff();
    }

    /// @inheritdoc ISiloVaultBase
    function updateWithdrawQueue(uint256[] calldata _indexes) external virtual onlyAllocatorRole {
        _nonReentrantOn();

        uint256 newLength = _indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        IERC4626[] memory newWithdrawQueue = new IERC4626[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = _indexes[i];

            // If prevIndex >= currLength, it will revert with native "Index out of bounds".
            IERC4626 market = withdrawQueue[prevIndex];
            if (seen[prevIndex]) revert ErrorsLib.DuplicateMarket(market);
            seen[prevIndex] = true;

            newWithdrawQueue[i] = market;
        }

        for (uint256 i; i < currLength; ++i) {
            if (!seen[i]) {
                IERC4626 market = withdrawQueue[i];

                if (config[market].cap != 0) revert ErrorsLib.InvalidMarketRemovalNonZeroCap(market);
                if (pendingCap[market].validAt != 0) revert ErrorsLib.PendingCap(market);

                if (_ERC20BalanceOf(address(market), address(this)) != 0) {
                    if (config[market].removableAt == 0) revert ErrorsLib.InvalidMarketRemovalNonZeroSupply(market);

                    if (block.timestamp < config[market].removableAt) {
                        revert ErrorsLib.InvalidMarketRemovalTimelockNotElapsed(market);
                    }
                }

                delete config[market];
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(_msgSender(), newWithdrawQueue);

        _nonReentrantOff();
    }

    /// @inheritdoc ISiloVaultBase
    function reallocate(MarketAllocation[] calldata _allocations) external virtual onlyAllocatorRole {
        _nonReentrantOn();

        uint256 totalSupplied;
        uint256 totalWithdrawn;
        for (uint256 i; i < _allocations.length; ++i) {
            MarketAllocation memory allocation = _allocations[i];

            // in original SiloVault, we are not checking liquidity, so this reallocation will fail if not enough assets
            (uint256 supplyAssets, uint256 supplyShares) = _supplyBalance(allocation.market);
            uint256 withdrawn = UtilsLib.zeroFloorSub(supplyAssets, allocation.assets);

            if (withdrawn > 0) {
                if (!config[allocation.market].enabled) revert ErrorsLib.MarketNotEnabled(allocation.market);

                // Guarantees that unknown frontrunning donations can be withdrawn, in order to disable a market.
                uint256 shares;
                if (allocation.assets == 0) {
                    shares = supplyShares;
                    withdrawn = 0;
                }

                uint256 withdrawnAssets;
                uint256 withdrawnShares;

                if (shares != 0) {
                    withdrawnAssets = allocation.market.redeem(shares, address(this), address(this));
                    withdrawnShares = shares;
                } else {
                    withdrawnAssets = withdrawn;
                    withdrawnShares = allocation.market.withdraw(withdrawn, address(this), address(this));
                }

                emit EventsLib.ReallocateWithdraw(_msgSender(), allocation.market, withdrawnAssets, withdrawnShares);

                totalWithdrawn += withdrawnAssets;
            } else {
                uint256 suppliedAssets = allocation.assets == type(uint256).max
                    ? UtilsLib.zeroFloorSub(totalWithdrawn, totalSupplied)
                    : UtilsLib.zeroFloorSub(allocation.assets, supplyAssets);

                if (suppliedAssets == 0) continue;

                uint256 supplyCap = config[allocation.market].cap;
                if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(allocation.market);

                if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(allocation.market);

                // The market's loan asset is guaranteed to be the vault's asset because it has a non-zero supply cap.
                uint256 suppliedShares = allocation.market.deposit(suppliedAssets, address(this));

                emit EventsLib.ReallocateSupply(_msgSender(), allocation.market, suppliedAssets, suppliedShares);

                totalSupplied += suppliedAssets;
            }
        }

        if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();

        _nonReentrantOff();
    }

    /* REVOKE FUNCTIONS */

    /// @inheritdoc ISiloVaultBase
    function revokePendingTimelock() external virtual onlyGuardianRole {
        delete pendingTimelock;

        emit EventsLib.RevokePendingTimelock(_msgSender());
    }

    /// @inheritdoc ISiloVaultBase
    function revokePendingGuardian() external virtual onlyGuardianRole {
        delete pendingGuardian;

        emit EventsLib.RevokePendingGuardian(_msgSender());
    }

    /// @inheritdoc ISiloVaultBase
    function revokePendingCap(IERC4626 _market) external virtual onlyCuratorOrGuardianRole {
        delete pendingCap[_market];

        emit EventsLib.RevokePendingCap(_msgSender(), _market);
    }

    /// @inheritdoc ISiloVaultBase
    function revokePendingMarketRemoval(IERC4626 _market) external virtual onlyCuratorOrGuardianRole {
        delete config[_market].removableAt;

        emit EventsLib.RevokePendingMarketRemoval(_msgSender(), _market);
    }

    /* EXTERNAL */

    /// @inheritdoc ISiloVaultBase
    function supplyQueueLength() external view virtual returns (uint256) {
        return supplyQueue.length;
    }

    /// @inheritdoc ISiloVaultBase
    function withdrawQueueLength() external view virtual returns (uint256) {
        return withdrawQueue.length;
    }

    /// @inheritdoc ISiloVaultBase
    function acceptTimelock() external virtual afterTimelock(pendingTimelock.validAt) {
        _setTimelock(pendingTimelock.value);
    }

    /// @inheritdoc ISiloVaultBase
    function acceptGuardian() external virtual afterTimelock(pendingGuardian.validAt) {
        _setGuardian(pendingGuardian.value);
    }

    /// @inheritdoc ISiloVaultBase
    function acceptCap(IERC4626 _market)
        external
        virtual
        afterTimelock(pendingCap[_market].validAt)
    {
        _nonReentrantOn();

        // Safe "unchecked" cast because pendingCap <= type(uint184).max.
        _setCap(_market, uint184(pendingCap[_market].value));

        _nonReentrantOff();
    }

    /// @inheritdoc ISiloVaultBase
    function skim(address _token) external virtual {
        if (skimRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = _ERC20BalanceOf(_token, address(this));

        IERC20(_token).safeTransfer(skimRecipient, amount);

        emit EventsLib.Skim(_msgSender(), _token, amount);
    }

    /// @inheritdoc ISiloVaultBase
    function claimRewards() public virtual {
        _nonReentrantOn();

        _claimRewards();

        _nonReentrantOff();
    }

    /// @inheritdoc ISiloVaultBase
    function reentrancyGuardEntered() external view virtual returns (bool entered) {
        entered = _lock;
    }

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view virtual override(ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max deposit due to duplicate markets in the supplyQueue.
    function maxDeposit(address) public view virtual override returns (uint256) {
        return _maxDeposit();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max mint due to duplicate markets in the supplyQueue.
    function maxMint(address) public view virtual override returns (uint256) {
        uint256 suppliable = _maxDeposit();

        return _convertToShares(suppliable, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of assets that can be withdrawn by `owner` due to conversion
    /// roundings between shares and assets.
    function maxWithdraw(address _owner) public view virtual override returns (uint256 assets) {
        (assets,,) = _maxWithdraw(_owner);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of shares that can be redeemed by `owner` due to conversion
    /// roundings between shares and assets.
    function maxRedeem(address _owner) public view virtual override returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(_owner);

        return _convertToSharesWithTotals(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256 shares) {
        _nonReentrantOn();

        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(_assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        _deposit(_msgSender(), _receiver, _assets, shares);

        _nonReentrantOff();
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public virtual override returns (uint256 assets) {
        _nonReentrantOn();

        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(_shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        _deposit(_msgSender(), _receiver, assets, _shares);

        _nonReentrantOff();
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        _nonReentrantOn();

        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(_assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, _assets));

        _withdraw(_msgSender(), _receiver, _owner, _assets, shares);

        _nonReentrantOff();
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public virtual override returns (uint256 assets) {
        _nonReentrantOn();

        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(_shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(UtilsLib.zeroFloorSub(newTotalAssets, assets));

        _withdraw(_msgSender(), _receiver, _owner, assets, _shares);

        _nonReentrantOff();
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256 assets) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];
            assets += _expectedSupplyAssets(market, address(this));
        }
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    /// @dev Returns the maximum amount of asset (`assets`) that the `owner` can withdraw from the vault, as well as the
    /// new vault's total supply (`newTotalSupply`) and total assets (`newTotalAssets`).
    function _maxWithdraw(address _owner)
        internal
        view
        virtual
        returns (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
    {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        newTotalSupply = totalSupply() + feeShares;

        assets = _convertToAssetsWithTotals(balanceOf(_owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
        assets -= _simulateWithdrawERC4626(assets);
    }

    /// @dev Returns the maximum amount of assets that the vault can supply to ERC4626 vaults.
    function _maxDeposit() internal view virtual returns (uint256 totalSuppliable) {
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = supplyQueue[i];

            uint256 supplyCap = config[market].cap;
            if (supplyCap == 0) continue;

            (uint256 assets,) = _supplyBalance(market);
            uint256 depositMax = market.maxDeposit(address(this));

            totalSuppliable += Math.min(depositMax, UtilsLib.zeroFloorSub(supplyCap, assets));
        }
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToShares(uint256 _assets, Math.Rounding _rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithTotals(_assets, totalSupply() + feeShares, newTotalAssets, _rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToAssets(uint256 _shares, Math.Rounding _rounding) internal view virtual override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithTotals(_shares, totalSupply() + feeShares, newTotalAssets, _rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToSharesWithTotals(
        uint256 _assets,
        uint256 _newTotalSupply,
        uint256 _newTotalAssets,
        Math.Rounding _rounding
    ) internal view virtual returns (uint256) {
        return _assets.mulDiv(_newTotalSupply + 10 ** _decimalsOffset(), _newTotalAssets + 1, _rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 _shares,
        uint256 _newTotalSupply,
        uint256 _newTotalAssets,
        Math.Rounding _rounding
    ) internal view virtual returns (uint256) {
        return _shares.mulDiv(_newTotalAssets + 1, _newTotalSupply + 10 ** _decimalsOffset(), _rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to ERC4626 vaults.
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal virtual override {
        if (_shares == 0) revert ErrorsLib.InputZeroShares();

        super._deposit(_caller, _receiver, _assets, _shares);

        _supplyERC4626(_assets);

        // `lastTotalAssets + assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(lastTotalAssets + _assets);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from ERC4626 markets.
    /// @dev Depending on 3 cases, reverts when withdrawing "too much" with:
    /// 1. NotEnoughLiquidity when withdrawing more than available liquidity.
    /// 2. ERC20InsufficientAllowance when withdrawing more than `caller`'s allowance.
    /// 3. ERC20InsufficientBalance when withdrawing more than `owner`'s balance.
    function _withdraw(address _caller, address _receiver, address _owner, uint256 _assets, uint256 _shares)
        internal
        virtual
        override
    {
        _withdrawERC4626(_assets);

        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /* INTERNAL */


    /// @dev Returns the vault's assets & corresponding shares supplied on the
    /// market defined by `market`, as well as the market's state.
    function _supplyBalance(IERC4626 _market)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        shares = _ERC20BalanceOf(address(_market), address(this));
        // we assume here, that in case of any interest on IERC4626, convertToAssets returns assets with interest
        assets = _market.convertToAssets(shares);
    }

    /// @dev Reverts if `newTimelock` is not within the bounds.
    function _checkTimelockBounds(uint256 _newTimelock) internal pure virtual {
        if (_newTimelock > ConstantsLib.MAX_TIMELOCK) revert ErrorsLib.AboveMaxTimelock();
        if (_newTimelock < ConstantsLib.MIN_TIMELOCK) revert ErrorsLib.BelowMinTimelock();
    }

    /// @dev Sets `timelock` to `newTimelock`.
    function _setTimelock(uint256 _newTimelock) internal virtual {
        timelock = _newTimelock;

        emit EventsLib.SetTimelock(_msgSender(), _newTimelock);

        delete pendingTimelock;
    }

    /// @dev Sets `guardian` to `newGuardian`.
    function _setGuardian(address _newGuardian) internal virtual {
        guardian = _newGuardian;

        emit EventsLib.SetGuardian(_msgSender(), _newGuardian);

        delete pendingGuardian;
    }

    /// @dev Sets the cap of the market.
    function _setCap(IERC4626 _market, uint184 _supplyCap) internal virtual {
        MarketConfig storage marketConfig = config[_market];

        if (_supplyCap > 0) {
            if (!marketConfig.enabled) {
                withdrawQueue.push(_market);

                if (withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

                marketConfig.enabled = true;

                // Take into account assets of the new market without applying a fee.
                _updateLastTotalAssets(lastTotalAssets + _expectedSupplyAssets(_market, address(this)));

                emit EventsLib.SetWithdrawQueue(msg.sender, withdrawQueue);
            }

            marketConfig.removableAt = 0;
        }

        marketConfig.cap = _supplyCap;
        // one time approval, so market can pull any amount of tokens from SiloVault in a future
        IERC20(asset()).forceApprove(address(_market), type(uint256).max);
        emit EventsLib.SetCap(_msgSender(), _market, _supplyCap);

        delete pendingCap[_market];
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to ERC4626 vaults.
    function _supplyERC4626(uint256 _assets) internal virtual {
        for (uint256 i; i < supplyQueue.length; ++i) {
            IERC4626 market = supplyQueue[i];

            uint256 supplyCap = config[market].cap;
            if (supplyCap == 0) continue;

            // `supplyAssets` needs to be rounded up for `toSupply` to be rounded down.
            (uint256 supplyAssets,) = _supplyBalance(market);

            uint256 toSupply = UtilsLib.min(UtilsLib.zeroFloorSub(supplyCap, supplyAssets), _assets);

            if (toSupply > 0) {
                // Using try/catch to skip markets that revert.
                try market.deposit(toSupply, address(this)) {
                    _assets -= toSupply;
                } catch {
                }
            }

            if (_assets == 0) return;
        }

        if (_assets != 0) revert ErrorsLib.AllCapsReached();
    }

    /// @dev Withdraws `assets` from ERC4626 vaults.
    function _withdrawERC4626(uint256 _assets) internal virtual {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            // original implementation were using `_accruedSupplyBalance` which does not care about liquidity
            // now, liquidity is considered by using `maxWithdraw`
            uint256 toWithdraw = UtilsLib.min(market.maxWithdraw(address(this)), _assets);

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try market.withdraw(toWithdraw, address(this), address(this)) {
                    _assets -= toWithdraw;
                } catch {
                }
            }

            if (_assets == 0) return;
        }

        if (_assets != 0) revert ErrorsLib.NotEnoughLiquidity();
    }

    /// @dev Simulates a withdraw of `assets` from ERC4626 vault.
    /// @return The remaining assets to be withdrawn.
    function _simulateWithdrawERC4626(uint256 _assets) internal view virtual returns (uint256) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 market = withdrawQueue[i];

            _assets = UtilsLib.zeroFloorSub(_assets, market.maxWithdraw(address(this)));

            if (_assets == 0) break;
        }

        return _assets;
    }

    /* FEE MANAGEMENT */

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(uint256 _updatedTotalAssets) internal virtual {
        lastTotalAssets = _updatedTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(_updatedTotalAssets);
    }

    /// @dev Accrues the fee and mints the fee shares to the fee recipient.
    /// @return newTotalAssets The vaults total assets after accruing the interest.
    function _accrueFee() internal virtual returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();

        if (feeShares != 0) _mint(feeRecipient, feeShares);

        emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
    }

    /// @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
    /// (`newTotalAssets`).
    function _accruedFeeShares() internal view virtual returns (uint256 feeShares, uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = UtilsLib.zeroFloorSub(newTotalAssets, lastTotalAssets);
        if (totalInterest != 0 && fee != 0) {
            // It is acknowledged that `feeAssets` may be rounded down to 0 if `totalInterest * fee < WAD`.
            uint256 feeAssets = totalInterest.mulDiv(fee, WAD);
            // The fee assets is subtracted from the total assets in this calculation to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            feeShares =
                _convertToSharesWithTotals(feeAssets, totalSupply(), newTotalAssets - feeAssets, Math.Rounding.Floor);
        }
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    function _expectedSupplyAssets(IERC4626 _market, address _user) internal view virtual returns (uint256 assets) {
        assets = _market.convertToAssets(_ERC20BalanceOf(address(_market), _user));
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        // on deposit, claim must be first action, new user should not get reward

        // on withdraw, claim must be first action, user that is leaving should get rewards
        // immediate deposit-withdraw operation will not abused it, because before deposit all rewards will be
        // claimed, so on withdraw on the same block no additional rewards will be generated.

        // transfer shares is basically withdraw->deposit, so claiming rewards should be done before any state changes

        _claimRewards();

        super._update(_from, _to, _value);

        if (_value == 0) return;
        
        _afterTokenTransfer(_from, _to, _value);
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _value) internal virtual {
        address[] memory receivers = INCENTIVES_MODULE.getNotificationReceivers();

        uint256 total = totalSupply();
        uint256 senderBalance = _from == address(0) ? 0 : balanceOf(_from);
        uint256 recipientBalance = _to == address(0) ? 0 : balanceOf(_to);

        for(uint256 i; i < receivers.length; i++) {
            INotificationReceiver(receivers[i]).afterTokenTransfer({
                _sender: _from,
                _senderBalance: senderBalance,
                _recipient: _to,
                _recipientBalance: recipientBalance,
                _totalSupply: total,
                 _amount: _value
            });
        }
    }

    function _claimRewards() internal virtual {
        address[] memory logics = INCENTIVES_MODULE.getAllIncentivesClaimingLogics();
        bytes memory data = abi.encodeWithSelector(IIncentivesClaimingLogic.claimRewardsAndDistribute.selector);

        for (uint256 i; i < logics.length; i++) {
            (bool success,) = logics[i].delegatecall(data);
            if (!success) revert ErrorsLib.ClaimRewardsFailed();
        }
    }

    function _nonReentrantOn() internal {
        require(!_lock, ErrorsLib.ReentrancyError());
        _lock = true;
    }

    function _nonReentrantOff() internal {
        _lock = false;
    }

    /// @dev to save code size ~500 B
    function _ERC20BalanceOf(address _token, address _account) internal view returns (uint256 balance) {
        balance = IERC20(_token).balanceOf(_account);
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/SiloVault.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/PublicAllocator.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "./interfaces/IPublicAllocator.sol";
import {ISiloVault, MarketAllocation} from "./interfaces/ISiloVault.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title PublicAllocator
/// @author Forked with gratitude from Morpho Labs.
/// @custom:contact security@morpho.org
/// @notice Publicly callable allocator for SiloVault vaults.
contract PublicAllocator is IPublicAllocatorStaticTyping {
    using UtilsLib for uint256;
    
    /* STORAGE */

    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => address) public admin;
    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => uint256) public fee;
    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => uint256) public accruedFee;
    /// @inheritdoc IPublicAllocatorStaticTyping
    mapping(ISiloVault => mapping(IERC4626 => FlowCaps)) public flowCaps;

    /* MODIFIER */

    /// @dev Reverts if the caller is not the admin nor the owner of this vault.
    modifier onlyAdminOrVaultOwner(ISiloVault vault) {
        if (msg.sender != admin[vault] && msg.sender != ISiloVault(vault).owner()) {
            revert ErrorsLib.NotAdminNorVaultOwner();
        }
        _;
    }

    /* ADMIN OR VAULT OWNER ONLY */

    /// @inheritdoc IPublicAllocatorBase
    function setAdmin(ISiloVault vault, address newAdmin) external virtual onlyAdminOrVaultOwner(vault) {
        if (admin[vault] == newAdmin) revert ErrorsLib.AlreadySet();
        admin[vault] = newAdmin;
        emit EventsLib.SetAdmin(msg.sender, vault, newAdmin);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFee(ISiloVault vault, uint256 newFee) external virtual onlyAdminOrVaultOwner(vault) {
        if (fee[vault] == newFee) revert ErrorsLib.AlreadySet();
        fee[vault] = newFee;
        emit EventsLib.SetFee(msg.sender, vault, newFee);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFlowCaps(ISiloVault vault, FlowCapsConfig[] calldata config)
        external
        virtual
        onlyAdminOrVaultOwner(vault)
    {
        for (uint256 i = 0; i < config.length; i++) {
            FlowCapsConfig memory cfg = config[i];
            IERC4626 market = cfg.market;
            
            if (!vault.config(market).enabled && (cfg.caps.maxIn > 0 || cfg.caps.maxOut > 0)) {
                revert ErrorsLib.MarketNotEnabled(market);
            }
            if (cfg.caps.maxIn > MAX_SETTABLE_FLOW_CAP || cfg.caps.maxOut > MAX_SETTABLE_FLOW_CAP) {
                revert ErrorsLib.MaxSettableFlowCapExceeded();
            }
            
            flowCaps[vault][market] = cfg.caps;
        }

        emit EventsLib.SetFlowCaps(msg.sender, vault, config);
    }

    /// @inheritdoc IPublicAllocatorBase
    function transferFee(ISiloVault vault, address payable feeRecipient) external virtual onlyAdminOrVaultOwner(vault) {
        uint256 claimed = accruedFee[vault];
        accruedFee[vault] = 0;
        feeRecipient.transfer(claimed);
        emit EventsLib.TransferFee(msg.sender, vault, claimed, feeRecipient);
    }

    /* PUBLIC */

    /// @inheritdoc IPublicAllocatorBase
    function reallocateTo(ISiloVault vault, Withdrawal[] calldata withdrawals, IERC4626 supplyMarket)
        external
        payable
        virtual
    {
        if (msg.value != fee[vault]) revert ErrorsLib.IncorrectFee();
        if (msg.value > 0) accruedFee[vault] += msg.value;

        if (withdrawals.length == 0) revert ErrorsLib.EmptyWithdrawals();

        if (!vault.config(supplyMarket).enabled) revert ErrorsLib.MarketNotEnabled(supplyMarket);

        MarketAllocation[] memory allocations = new MarketAllocation[](withdrawals.length + 1);
        uint128 totalWithdrawn;

        IERC4626 market;
        IERC4626 prevMarket;
        
        for (uint256 i = 0; i < withdrawals.length; i++) {
            prevMarket = market;
            Withdrawal memory withdrawal = withdrawals[i];
            market = withdrawal.market;

            if (!vault.config(market).enabled) revert ErrorsLib.MarketNotEnabled(market);
            if (withdrawal.amount == 0) revert ErrorsLib.WithdrawZero(market);

            if (address(market) <= address(prevMarket)) revert ErrorsLib.InconsistentWithdrawals();
            if (address(market) == address(supplyMarket)) revert ErrorsLib.DepositMarketInWithdrawals();

            uint256 assets = _expectedSupplyAssets(market, address(vault));

            if (flowCaps[vault][market].maxOut < withdrawal.amount) revert ErrorsLib.MaxOutflowExceeded(market);
            if (assets < withdrawal.amount) revert ErrorsLib.NotEnoughSupply(market);

            flowCaps[vault][market].maxIn += withdrawal.amount;
            flowCaps[vault][market].maxOut -= withdrawal.amount;
            allocations[i].market = market;
            allocations[i].assets = assets - withdrawal.amount;

            totalWithdrawn += withdrawal.amount;

            emit EventsLib.PublicWithdrawal(msg.sender, vault, market, withdrawal.amount);
        }

        if (flowCaps[vault][supplyMarket].maxIn < totalWithdrawn) revert ErrorsLib.MaxInflowExceeded(supplyMarket);

        flowCaps[vault][supplyMarket].maxIn -= totalWithdrawn;
        flowCaps[vault][supplyMarket].maxOut += totalWithdrawn;
        allocations[withdrawals.length].market = supplyMarket;
        allocations[withdrawals.length].assets = type(uint256).max;

        vault.reallocate(allocations);

        emit EventsLib.PublicReallocateTo(msg.sender, vault, supplyMarket, totalWithdrawn);
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    function _expectedSupplyAssets(IERC4626 _market, address _user) internal view virtual returns (uint256 assets) {
        assets = _market.convertToAssets(_market.balanceOf(_user));
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/PublicAllocator.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/README.md ---
# Silo Vault incentives

Silo vaults support two types of incentive distributions: immediate distributions (whatever was received should be immediately available to withdraw) and any other type like a time-based silo incentives controller or gauge, or both at the same time.

|<img src="../../docs/_images/vaults-incentives-fig-1.jpg" alt="">|
|:--:| 
| Fig. 1 - Vault incentives module solutions for incentives distribution |

### Claiming and distributing Vault market incentives
Each market that is available in the vault may (will) have different incentives programs. These programs will differ not only in the solutions that will be used for them but also in their start/end dates, which requires us to be able to claim incentives from new sources or stop trying to claim from the finished incentives programs.To be able to handle it, each market have configurable rewards claiming logics, which are implemented in a separate smart contracts. The vault executes these incentives claiming logic via delegate call. See Fig. 2, Fig. 3.

|<img src="../../docs/_images/vaults-incentives-fig-2.jpg" alt="">|
|:--:| 
| Fig. 2 - Incentives claiming and distribution logic |

The vault executes incentives claiming/distribution logic via delegate call so it can claim rewards as vault if needed.

|<img src="../../docs/_images/vaults-incentives-fig-3.jpg" alt="">|
|:--:| 
| Fig. 3 - Incentives claiming and distribution logic execution |

For the distribution, incentives claiming logic use a feature for immediate incentives distribution from the SiloIncentivesController. See immediateDistribution fn.
--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/README.md ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/VaultIncentivesModule.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "../interfaces/INotificationReceiver.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _markets;
    EnumerableSet.AddressSet internal _notificationReceivers;

    mapping(address market => EnumerableSet.AddressSet incentivesClaimingLogics) internal _claimingLogics;

    constructor(address _owner) Ownable(_owner) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external virtual onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(!_claimingLogics[_market].contains(address(_logic)), LogicAlreadyAdded());

        if (_claimingLogics[_market].length() == 0) {
            _markets.add(_market);
        }

        _claimingLogics[_market].add(address(_logic));

        emit IncentivesClaimingLogicAdded(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic)
        external
        virtual
        onlyOwner
    {
        require(_claimingLogics[_market].contains(address(_logic)), LogicNotFound());

        _claimingLogics[_market].remove(address(_logic));

        if (_claimingLogics[_market].length() == 0) {
            _markets.remove(_market);
        }

        emit IncentivesClaimingLogicRemoved(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external virtual onlyOwner {
        require(address(_notificationReceiver) != address(0), AddressZero());
        require(_notificationReceivers.add(address(_notificationReceiver)), NotificationReceiverAlreadyAdded());

        emit NotificationReceiverAdded(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeNotificationReceiver(INotificationReceiver _notificationReceiver) external virtual onlyOwner {
        require(_notificationReceivers.remove(address(_notificationReceiver)), NotificationReceiverNotFound());

        emit NotificationReceiverRemoved(address(_notificationReceiver));
    }

    /// @inheritdoc IVaultIncentivesModule
    function getAllIncentivesClaimingLogics() external view virtual returns (address[] memory logics) {
        address[] memory markets = _markets.values();

        logics = _getAllIncentivesClaimingLogics(markets);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getMarketsIncentivesClaimingLogics(address[] calldata _marketsInput)
        external
        view
        virtual
        returns (address[] memory logics)
    {
        logics = _getAllIncentivesClaimingLogics(_marketsInput);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getNotificationReceivers() external view virtual returns (address[] memory receivers) {
        receivers = _notificationReceivers.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function getConfiguredMarkets() external view virtual returns (address[] memory markets) {
        markets = _markets.values();
    }

    /// @inheritdoc IVaultIncentivesModule
    function getMarketIncentivesClaimingLogics(address market) external view virtual returns (address[] memory logics) {
        logics = _claimingLogics[market].values();
    }

    /// @dev Internal function to get the incentives claiming logics for a given market.
    /// @param _marketsInput The markets to get the incentives claiming logics for.
    /// @return logics The incentives claiming logics.
    function _getAllIncentivesClaimingLogics(address[] memory _marketsInput)
        internal
        view
        virtual
        returns (address[] memory logics)
    {
        uint256 totalLogics;

        for (uint256 i = 0; i < _marketsInput.length; i++) {
            unchecked {
                // safe to uncheck as we will never have more than 2^256 logics
                totalLogics += _claimingLogics[_marketsInput[i]].length();
            }
        }

        logics = new address[](totalLogics);

        uint256 index;
        for (uint256 i = 0; i < _marketsInput.length; i++) {
            address[] memory marketLogics = _claimingLogics[_marketsInput[i]].values();

            for (uint256 j = 0; j < marketLogics.length; j++) {
                unchecked {
                    // safe to uncheck as we will never have more than 2^256 logics
                    logics[index++] = marketLogics[j];
                }
            }
        }
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/VaultIncentivesModule.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol ---
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISiloIncentivesControllerCLFactory} from "../../interfaces/ISiloIncentivesControllerCLFactory.sol";
import {SiloIncentivesControllerCL} from "./SiloIncentivesControllerCL.sol";

/// @dev Factory for creating SiloIncentivesControllerCL instances
contract SiloIncentivesControllerCLFactory is ISiloIncentivesControllerCLFactory {
    mapping(address => bool) public createdInFactory;

    /// @inheritdoc ISiloIncentivesControllerCLFactory
    function createIncentivesControllerCL(
        address _vaultIncentivesController,
        address _siloIncentivesController
    ) external returns (SiloIncentivesControllerCL logic) {
        logic = new SiloIncentivesControllerCL(_vaultIncentivesController, _siloIncentivesController);

        createdInFactory[address(logic)] = true;

        emit IncentivesControllerCLCreated(address(logic));
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCLFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {
    ISiloIncentivesController,
    IDistributionManager
} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";

import {IIncentivesClaimingLogic} from "../../interfaces/IIncentivesClaimingLogic.sol";

/// @title Silo incentives controller claiming logic
contract SiloIncentivesControllerCL is IIncentivesClaimingLogic {
    /// @notice Distributes rewards to vault depositors
    ISiloIncentivesController public immutable VAULT_INCENTIVES_CONTROLLER;
    /// @notice Distributes rewards to silo depositors
    ISiloIncentivesController public immutable SILO_INCENTIVES_CONTROLLER;

    constructor(
        address _vaultIncentivesController,
        address _siloIncentivesController
    ) {
        VAULT_INCENTIVES_CONTROLLER = ISiloIncentivesController(_vaultIncentivesController);
        SILO_INCENTIVES_CONTROLLER = ISiloIncentivesController(_siloIncentivesController);
    }

    function claimRewardsAndDistribute() external virtual {
        IDistributionManager.AccruedRewards[] memory accruedRewards =
            SILO_INCENTIVES_CONTROLLER.claimRewards(address(VAULT_INCENTIVES_CONTROLLER));

        for (uint256 i = 0; i < accruedRewards.length; i++) {
            if (accruedRewards[i].amount == 0) continue;

            VAULT_INCENTIVES_CONTROLLER.immediateDistribution(
                accruedRewards[i].rewardToken,
                uint104(accruedRewards[i].amount)
            );
        }
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/incentives/claiming-logics/SiloIncentivesControllerCL.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/ErrorsLib.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

/// @title ErrorsLib
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when deposit generates zero shares
    error InputZeroShares();

    /// @notice Thrown on OutOfGas or revert() without any data
    error PossibleOutOfGas();

    /// @notice Thrown on reentering token transfer while notification are being dispatched
    error NotificationDispatchError();

    /// @notice Thrown on reentering
    error ReentrancyError();

    /// @notice Thrown when delegatecall on claiming rewards failed
    error ClaimRewardsFailed();

    /// @notice Thrown when the address passed is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the caller doesn't have the curator role.
    error NotCuratorRole();

    /// @notice Thrown when the caller doesn't have the allocator role.
    error NotAllocatorRole();

    /// @notice Thrown when the caller doesn't have the guardian role.
    error NotGuardianRole();

    /// @notice Thrown when the caller doesn't have the curator nor the guardian role.
    error NotCuratorNorGuardianRole();

    /// @notice Thrown when the `market` cannot be set in the supply queue.
    error UnauthorizedMarket(IERC4626 market);

    /// @notice Thrown when submitting a cap for a `market` whose loan token does not correspond to the underlying.
    /// asset.
    error InconsistentAsset(IERC4626 market);

    /// @notice Thrown when the supply cap has been exceeded on `market` during a reallocation of funds.
    error SupplyCapExceeded(IERC4626 market);

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    error MaxFeeExceeded();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when a value is already pending.
    error AlreadyPending();

    /// @notice Thrown when submitting the removal of a market when there is a cap already pending on that market.
    error PendingCap(IERC4626 market);

    /// @notice Thrown when submitting a cap for a market with a pending removal.
    error PendingRemoval();

    /// @notice Thrown when submitting a market removal for a market with a non zero cap.
    error NonZeroCap();

    /// @notice Thrown when `market` is a duplicate in the new withdraw queue to set.
    error DuplicateMarket(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market has a non-zero cap set.
    error InvalidMarketRemovalNonZeroCap(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market has a non-zero supply.
    error InvalidMarketRemovalNonZeroSupply(IERC4626 market);

    /// @notice Thrown when `market` is missing in the updated withdraw queue and the market is not yet disabled.
    error InvalidMarketRemovalTimelockNotElapsed(IERC4626 market);

    /// @notice Thrown when there's no pending value to set.
    error NoPendingValue();

    /// @notice Thrown when the requested liquidity cannot be withdrawn from Morpho.
    error NotEnoughLiquidity();

    /// @notice Thrown when interacting with a non previously enabled `market`.
    /// @notice Thrown when attempting to reallocate or set flows to non-zero values for a non-enabled market.
    error MarketNotEnabled(IERC4626 market);

    /// @notice Thrown when the submitted timelock is above the max timelock.
    error AboveMaxTimelock();

    /// @notice Thrown when the submitted timelock is below the min timelock.
    error BelowMinTimelock();

    /// @notice Thrown when the timelock is not elapsed.
    error TimelockNotElapsed();

    /// @notice Thrown when too many markets are in the withdraw queue.
    error MaxQueueLengthExceeded();

    /// @notice Thrown when setting the fee to a non zero value while the fee recipient is the zero address.
    error ZeroFeeRecipient();

    /// @notice Thrown when the amount withdrawn is not exactly the amount supplied.
    error InconsistentReallocation();

    /// @notice Thrown when all caps have been reached.
    error AllCapsReached();

    /// @notice Thrown when the `msg.sender` is not the admin nor the owner of the vault.
    error NotAdminNorVaultOwner();

    /// @notice Thrown when the reallocation fee given is wrong.
    error IncorrectFee();

    /// @notice Thrown when `withdrawals` is empty.
    error EmptyWithdrawals();

    /// @notice Thrown when `withdrawals` contains a duplicate or is not sorted.
    error InconsistentWithdrawals();

    /// @notice Thrown when the deposit market is in `withdrawals`.
    error DepositMarketInWithdrawals();

    /// @notice Thrown when attempting to withdraw zero of a market.
    error WithdrawZero(IERC4626 market);

    /// @notice Thrown when attempting to set max inflow/outflow above the MAX_SETTABLE_FLOW_CAP.
    error MaxSettableFlowCapExceeded();

    /// @notice Thrown when attempting to withdraw more than the available supply of a market.
    error NotEnoughSupply(IERC4626 market);

    /// @notice Thrown when attempting to withdraw more than the max outflow of a market.
    error MaxOutflowExceeded(IERC4626 market);

    /// @notice Thrown when attempting to supply more than the max inflow of a market.
    error MaxInflowExceeded(IERC4626 market);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/ErrorsLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/PendingLib.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

struct MarketConfig {
    /// @notice The maximum amount of assets that can be allocated to the market.
    uint184 cap;
    /// @notice Whether the market is in the withdraw queue.
    bool enabled;
    /// @notice The timestamp at which the market can be instantly removed from the withdraw queue.
    uint64 removableAt;
}

struct PendingUint192 {
    /// @notice The pending value to set.
    uint192 value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint64 validAt;
}

struct PendingAddress {
    /// @notice The pending value to set.
    address value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint64 validAt;
}

/// @title PendingLib
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Library to manage pending values and their validity timestamp.
library PendingLib {
    /// @dev Updates `_pending`'s value to `_newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingUint192 storage _pending, uint184 _newValue, uint256 _timelock) internal {
        _pending.value = _newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        _pending.validAt = uint64(block.timestamp + _timelock);
    }

    /// @dev Updates `_pending`'s value to `_newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingAddress storage _pending, address _newValue, uint256 _timelock) internal {
        _pending.value = _newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        _pending.validAt = uint64(block.timestamp + _timelock);
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/PendingLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/EventsLib.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {PendingAddress} from "./PendingLib.sol";
import {ISiloVault} from "../interfaces/ISiloVault.sol";
import {FlowCapsConfig} from "../interfaces/IPublicAllocator.sol";

/// @title EventsLib
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when a pending `newTimelock` is submitted.
    event SubmitTimelock(uint256 newTimelock);

    /// @notice Emitted when `timelock` is set to `newTimelock`.
    event SetTimelock(address indexed caller, uint256 newTimelock);

    /// @notice Emitted when `skimRecipient` is set to `newSkimRecipient`.
    event SetSkimRecipient(address indexed newSkimRecipient);

    /// @notice Emitted `fee` is set to `newFee`.
    event SetFee(address indexed caller, uint256 newFee);

    /// @notice Emitted when a new `newFeeRecipient` is set.
    event SetFeeRecipient(address indexed newFeeRecipient);

    /// @notice Emitted when a pending `newGuardian` is submitted.
    event SubmitGuardian(address indexed newGuardian);

    /// @notice Emitted when `guardian` is set to `newGuardian`.
    event SetGuardian(address indexed caller, address indexed guardian);

    /// @notice Emitted when a pending `cap` is submitted for `market`.
    event SubmitCap(address indexed caller, IERC4626 indexed market, uint256 cap);

    /// @notice Emitted when a new `cap` is set for `market`.
    event SetCap(address indexed caller, IERC4626 indexed market, uint256 cap);

    /// @notice Emitted when the market's last total assets is updated to `updatedTotalAssets`.
    event UpdateLastTotalAssets(uint256 updatedTotalAssets);

    /// @notice Emitted when the `market` is submitted for removal.
    event SubmitMarketRemoval(address indexed caller, IERC4626 indexed market);

    /// @notice Emitted when `curator` is set to `newCurator`.
    event SetCurator(address indexed newCurator);

    /// @notice Emitted when an `allocator` is set to `isAllocator`.
    event SetIsAllocator(address indexed allocator, bool isAllocator);

    /// @notice Emitted when a `pendingTimelock` is revoked.
    event RevokePendingTimelock(address indexed caller);

    /// @notice Emitted when a `pendingCap` for the `market` is revoked.
    event RevokePendingCap(address indexed caller, IERC4626 indexed market);

    /// @notice Emitted when a `pendingGuardian` is revoked.
    event RevokePendingGuardian(address indexed caller);

    /// @notice Emitted when a pending market removal is revoked.
    event RevokePendingMarketRemoval(address indexed caller, IERC4626 indexed market);

    /// @notice Emitted when the `supplyQueue` is set to `newSupplyQueue`.
    event SetSupplyQueue(address indexed caller, IERC4626[] newSupplyQueue);

    /// @notice Emitted when the `withdrawQueue` is set to `newWithdrawQueue`.
    event SetWithdrawQueue(address indexed caller, IERC4626[] newWithdrawQueue);

    /// @notice Emitted when a reallocation supplies assets to the `market`.
    /// @param market The market address.
    /// @param suppliedAssets The amount of assets supplied to the market.
    /// @param suppliedShares The amount of shares minted.
    event ReallocateSupply(
        address indexed caller, IERC4626 indexed market, uint256 suppliedAssets, uint256 suppliedShares
    );

    /// @notice Emitted when a reallocation withdraws assets from the `market`.
    /// @param market The market address.
    /// @param withdrawnAssets The amount of assets withdrawn from the market.
    /// @param withdrawnShares The amount of shares burned.
    event ReallocateWithdraw(
        address indexed caller, IERC4626 indexed market, uint256 withdrawnAssets, uint256 withdrawnShares
    );

    /// @notice Emitted when interest are accrued.
    /// @param newTotalAssets The assets of the market after accruing the interest but before the interaction.
    /// @param feeShares The shares minted to the fee recipient.
    event AccrueInterest(uint256 newTotalAssets, uint256 feeShares);

    /// @notice Emitted when an `amount` of `token` is transferred to the skim recipient by `caller`.
    event Skim(address indexed caller, address indexed token, uint256 amount);

    /// @notice Emitted when a new SiloVault market is created.
    /// @param SiloVault The address of the SiloVault market.
    /// @param caller The caller of the function.
    /// @param initialOwner The initial owner of the SiloVault market.
    /// @param initialTimelock The initial timelock of the SiloVault market.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the SiloVault market.
    /// @param symbol The symbol of the SiloVault market.
    event CreateSiloVault(
        address indexed SiloVault,
        address indexed caller,
        address initialOwner,
        uint256 initialTimelock,
        address indexed asset,
        string name,
        string symbol
    );

    /// @notice Emitted during a public reallocation for each withdrawn-from market.
    event PublicWithdrawal(
        address indexed sender, ISiloVault indexed vault, IERC4626 indexed market, uint256 withdrawnAssets
    );

    /// @notice Emitted at the end of a public reallocation.
    event PublicReallocateTo(
        address indexed sender, ISiloVault indexed vault, IERC4626 indexed supplyMarket, uint256 suppliedAssets
    );

    /// @notice Emitted when the admin is set for a vault.
    event SetAdmin(address indexed sender, ISiloVault indexed vault, address admin);

    /// @notice Emitted when the fee is set for a vault.
    event SetFee(address indexed sender, ISiloVault indexed vault, uint256 fee);

    /// @notice Emitted when the fee is transfered for a vault.
    event TransferFee(address indexed sender, ISiloVault indexed vault, uint256 amount, address indexed feeRecipient);

    /// @notice Emitted when the flow caps are set for a vault.
    event SetFlowCaps(address indexed sender, ISiloVault indexed vault, FlowCapsConfig[] config);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/EventsLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/ConstantsLib.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

/// @title ConstantsLib
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Library exposing constants.
library ConstantsLib {
    /// @dev The maximum delay of a timelock.
    uint256 internal constant MAX_TIMELOCK = 2 weeks;

    /// @dev The minimum delay of a timelock.
    uint256 internal constant MIN_TIMELOCK = 1 days;

    /// @dev The maximum number of markets in the supply/withdraw queue.
    uint256 internal constant MAX_QUEUE_LENGTH = 30;

    /// @dev The maximum fee the vault can have (50%).
    uint256 internal constant MAX_FEE = 0.5e18;
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/libraries/ConstantsLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/mocks/ERC1820Registry.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
/**
 * Submitted for verification at Etherscan.io on 2019-04-03
 */

/* ERC1820 Pseudo-introspection Registry Contract
 * This standard defines a universal registry smart contract where any address (contract or regular account) can
 * register which interface it supports and which smart contract is responsible for its implementation.
 *
 * Written in 2019 by Jordi Baylina and Jacques Dafflon
 *
 * To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to
 * this software to the public domain worldwide. This software is distributed without any warranty.
 *
 *    ███████╗██████╗  ██████╗ ██╗ █████╗ ██████╗  ██████╗
 *    ██╔════╝██╔══██╗██╔════╝███║██╔══██╗╚════██╗██╔═████╗
 *    █████╗  ██████╔╝██║     ╚██║╚█████╔╝ █████╔╝██║██╔██║
 *    ██╔══╝  ██╔══██╗██║      ██║██╔══██╗██╔═══╝ ████╔╝██║
 *    ███████╗██║  ██║╚██████╗ ██║╚█████╔╝███████╗╚██████╔╝
 *    ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝ ╚════╝ ╚══════╝ ╚═════╝
 *
 *    ██████╗ ███████╗ ██████╗ ██╗███████╗████████╗██████╗ ██╗   ██╗
 *    ██╔══██╗██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔══██╗╚██╗ ██╔╝
 *    ██████╔╝█████╗  ██║  ███╗██║███████╗   ██║   ██████╔╝ ╚████╔╝
 *    ██╔══██╗██╔══╝  ██║   ██║██║╚════██║   ██║   ██╔══██╗  ╚██╔╝
 *    ██║  ██║███████╗╚██████╔╝██║███████║   ██║   ██║  ██║   ██║
 *    ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝
 *
 */
pragma solidity ^0.8.28;
// IV is value needed to have a vanity address starting with '0x1820'.
// IV: 53759

/// @dev The interface a contract MUST implement if it is the implementer of
/// some (other) interface for any address other than itself.
interface ERC1820ImplementerInterface {
    /// @notice Indicates whether the contract implements the interface 'interfaceHash' for the address 'addr' or not.
    /// @param interfaceHash keccak256 hash of the name of the interface
    /// @param addr Address for which the contract will implement the interface
    /// @return ERC1820_ACCEPT_MAGIC only if the contract implements 'interfaceHash' for the address 'addr'.
    function canImplementInterfaceForAddress(bytes32 interfaceHash, address addr) external view returns (bytes32);
}

/// @title ERC1820 Pseudo-introspection Registry Contract
/// @author Jordi Baylina and Jacques Dafflon
/// @notice This contract is the official implementation of the ERC1820 Registry.
/// @notice For more details, see https://eips.ethereum.org/EIPS/eip-1820
contract ERC1820Registry {
    /// @notice ERC165 Invalid ID.
    bytes4 internal constant INVALID_ID = 0xffffffff;
    /// @notice Method ID for the ERC165 supportsInterface method (= `bytes4(keccak256('supportsInterface(bytes4)'))`).
    bytes4 internal constant ERC165ID = 0x01ffc9a7;
    /// @notice Magic value which is returned if a contract implements an interface on behalf of some other address.
    bytes32 internal constant ERC1820_ACCEPT_MAGIC = keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));

    /// @notice mapping from addresses and interface hashes to their implementers.
    mapping(address => mapping(bytes32 => address)) internal interfaces;
    /// @notice mapping from addresses to their manager.
    mapping(address => address) internal managers;
    /// @notice flag for each address and erc165 interface to indicate if it is cached.
    mapping(address => mapping(bytes4 => bool)) internal erc165Cached;

    /// @notice Indicates a contract is the 'implementer' of 'interfaceHash' for 'addr'.
    event InterfaceImplementerSet(address indexed addr, bytes32 indexed interfaceHash, address indexed implementer);
    /// @notice Indicates 'newManager' is the address of the new manager for 'addr'.
    event ManagerChanged(address indexed addr, address indexed newManager);

    /// @notice Query if an address implements an interface and through which contract.
    /// @param _addr Address being queried for the implementer of an interface.
    /// (If '_addr' is the zero address then 'msg.sender' is assumed.)
    /// @param _interfaceHash Keccak256 hash of the name of the interface as a string.
    /// E.g., 'web3.utils.keccak256("ERC777TokensRecipient")' for the 'ERC777TokensRecipient' interface.
    /// @return The address of the contract which implements the interface '_interfaceHash' for '_addr'
    /// or '0' if '_addr' did not register an implementer for this interface.
    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address) {
        address addr = _addr == address(0) ? msg.sender : _addr;
        if (isERC165Interface(_interfaceHash)) {
            bytes4 erc165InterfaceHash = bytes4(_interfaceHash);
            return implementsERC165Interface(addr, erc165InterfaceHash) ? addr : address(0);
        }
        return interfaces[addr][_interfaceHash];
    }

    /// @notice Sets the contract which implements a specific interface for an address.
    /// Only the manager defined for that address can set it.
    /// (Each address is the manager for itself until it sets a new manager.)
    /// @param _addr Address for which to set the interface.
    /// (If '_addr' is the zero address then 'msg.sender' is assumed.)
    /// @param _interfaceHash Keccak256 hash of the name of the interface as a string.
    /// E.g., 'web3.utils.keccak256("ERC777TokensRecipient")' for the 'ERC777TokensRecipient' interface.
    /// @param _implementer Contract address implementing '_interfaceHash' for '_addr'.
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external {
        address addr = _addr == address(0) ? msg.sender : _addr;
        require(getManager(addr) == msg.sender, "Not the manager");

        require(!isERC165Interface(_interfaceHash), "Must not be an ERC165 hash");
        if (_implementer != address(0) && _implementer != msg.sender) {
            require(
                ERC1820ImplementerInterface(_implementer).canImplementInterfaceForAddress(_interfaceHash, addr)
                    == ERC1820_ACCEPT_MAGIC,
                "Does not implement the interface"
            );
        }
        interfaces[addr][_interfaceHash] = _implementer;
        emit InterfaceImplementerSet(addr, _interfaceHash, _implementer);
    }

    /// @notice Sets '_newManager' as manager for '_addr'.
    /// The new manager will be able to call 'setInterfaceImplementer' for '_addr'.
    /// @param _addr Address for which to set the new manager.
    /// @param _newManager Address of the new manager for 'addr'. (Pass '0x0' to reset the manager to '_addr'.)
    function setManager(address _addr, address _newManager) external {
        require(getManager(_addr) == msg.sender, "Not the manager");
        managers[_addr] = _newManager == _addr ? address(0) : _newManager;
        emit ManagerChanged(_addr, _newManager);
    }

    /// @notice Get the manager of an address.
    /// @param _addr Address for which to return the manager.
    /// @return Address of the manager for a given address.
    function getManager(address _addr) public view returns (address) {
        // By default the manager of an address is the same address
        if (managers[_addr] == address(0)) {
            return _addr;
        } else {
            return managers[_addr];
        }
    }

    /// @notice Compute the keccak256 hash of an interface given its name.
    /// @param _interfaceName Name of the interface.
    /// @return The keccak256 hash of an interface name.
    function interfaceHash(string calldata _interfaceName) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_interfaceName));
    }

    /* --- ERC165 Related Functions --- */
    /* --- Developed in collaboration with William Entriken. --- */

    /// @notice Updates the cache with whether the contract implements an ERC165 interface or not.
    /// @param _contract Address of the contract for which to update the cache.
    /// @param _interfaceId ERC165 interface for which to update the cache.
    function updateERC165Cache(address _contract, bytes4 _interfaceId) external {
        interfaces[_contract][_interfaceId] =
            implementsERC165InterfaceNoCache(_contract, _interfaceId) ? _contract : address(0);
        erc165Cached[_contract][_interfaceId] = true;
    }

    /// @notice Checks whether a contract implements an ERC165 interface or not.
    //  If the result is not cached a direct lookup on the contract address is performed.
    //  If the result is not cached or the cached value is out-of-date, the cache MUST be updated manually by calling
    //  'updateERC165Cache' with the contract address.
    /// @param _contract Address of the contract to check.
    /// @param _interfaceId ERC165 interface to check.
    /// @return True if '_contract' implements '_interfaceId', false otherwise.
    function implementsERC165Interface(address _contract, bytes4 _interfaceId) public view returns (bool) {
        if (!erc165Cached[_contract][_interfaceId]) {
            return implementsERC165InterfaceNoCache(_contract, _interfaceId);
        }
        return interfaces[_contract][_interfaceId] == _contract;
    }

    /// @notice Checks whether a contract implements an ERC165 interface or not without using nor updating the cache.
    /// @param _contract Address of the contract to check.
    /// @param _interfaceId ERC165 interface to check.
    /// @return True if '_contract' implements '_interfaceId', false otherwise.
    function implementsERC165InterfaceNoCache(address _contract, bytes4 _interfaceId) public view returns (bool) {
        uint256 success;
        uint256 result;

        (success, result) = noThrowCall(_contract, ERC165ID);
        if (success == 0 || result == 0) {
            return false;
        }

        (success, result) = noThrowCall(_contract, INVALID_ID);
        if (success == 0 || result != 0) {
            return false;
        }

        (success, result) = noThrowCall(_contract, _interfaceId);
        if (success == 1 && result == 1) {
            return true;
        }
        return false;
    }

    /// @notice Checks whether the hash is a ERC165 interface (ending with 28 zeroes) or not.
    /// @param _interfaceHash The hash to check.
    /// @return True if '_interfaceHash' is an ERC165 interface (ending with 28 zeroes), false otherwise.
    function isERC165Interface(bytes32 _interfaceHash) internal pure returns (bool) {
        return _interfaceHash & 0x00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF == 0;
    }

    /// @dev Make a call on a contract without throwing if the function does not exist.
    function noThrowCall(address _contract, bytes4 _interfaceId)
        internal
        view
        returns (uint256 success, uint256 result)
    {
        bytes4 erc165ID = ERC165ID;

        assembly {
            let x := mload(0x40) // Find empty storage location using "free memory pointer"
            mstore(x, erc165ID) // Place signature at beginning of empty storage
            mstore(add(x, 0x04), _interfaceId) // Place first argument directly next to signature

            success :=
                staticcall(
                    30000, // 30k gas
                    _contract, // To addr
                    x, // Inputs are stored at location x
                    0x24, // Inputs are 36 (4 + 32) bytes long
                    x, // Store output over input (saves space)
                    0x20 // Outputs are 32 bytes long
                )

            result := mload(x) // Load the result
        }
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/mocks/ERC1820Registry.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/mocks/ERC777Mock.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import "openzeppelin5/interfaces/IERC777.sol";
import "openzeppelin5/interfaces/IERC777Recipient.sol";
import "openzeppelin5/interfaces/IERC777Sender.sol";
import "openzeppelin5/interfaces/IERC20.sol";
import "openzeppelin5/utils/Address.sol";
import "openzeppelin5/utils/Context.sol";
import "openzeppelin5/interfaces/IERC1820Registry.sol";

/**
 * @dev Implementation of the {IERC777} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * Support for ERC20 is included in this contract, as specified by the EIP: both
 * the ERC777 and ERC20 interfaces can be safely used when interacting with it.
 * Both {IERC777-Sent} and {IERC20-Transfer} events are emitted on token
 * movements.
 *
 * Additionally, the {IERC777-granularity} value is hard-coded to `1`, meaning that there
 * are no special restrictions in the amount of tokens that created, moved, or
 * destroyed. This makes integration with ERC20 applications seamless.
 *
 * CAUTION: This file is deprecated as of v4.9 and will be removed in the next major release.
 */
contract ERC777 is Context, IERC777, IERC20 {
    using Address for address;

    IERC1820Registry internal immutable _ERC1820_REGISTRY;

    mapping(address => uint256) private _balances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    // This isn't ever read from - it's only used to respond to the defaultOperators query.
    address[] private _defaultOperatorsArray;

    // Immutable, but accounts may revoke them (tracked in __revokedDefaultOperators).
    mapping(address => bool) private _defaultOperators;

    // For each account, a mapping of its operators and revoked default operators.
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => mapping(address => bool)) private _revokedDefaultOperators;

    // ERC20-allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @dev `defaultOperators` may be an empty array.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory defaultOperators_,
        IERC1820Registry registry
    ) {
        _name = name_;
        _symbol = symbol_;

        _defaultOperatorsArray = defaultOperators_;
        for (uint256 i = 0; i < defaultOperators_.length; i++) {
            _defaultOperators[defaultOperators_[i]] = true;
        }

        _ERC1820_REGISTRY = registry;

        // register interfaces
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
    }

    /**
     * @dev See {IERC777-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC777-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {ERC20-decimals}.
     *
     * Always returns 18, as per the
     * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
     */
    function decimals() public pure virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC777-granularity}.
     *
     * This implementation always returns `1`.
     */
    function granularity() public view virtual override returns (uint256) {
        return 1;
    }

    /**
     * @dev See {IERC777-totalSupply}.
     */
    function totalSupply() public view virtual override(IERC20, IERC777) returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
     */
    function balanceOf(address tokenHolder) public view virtual override(IERC20, IERC777) returns (uint256) {
        return _balances[tokenHolder];
    }

    /**
     * @dev See {IERC777-send}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function send(address recipient, uint256 amount, bytes memory data) public virtual override {
        _send(_msgSender(), recipient, amount, data, "", true);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Unlike `send`, `recipient` is _not_ required to implement the {IERC777Recipient}
     * interface if it is a contract.
     *
     * Also emits a {Sent} event.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _send(_msgSender(), recipient, amount, "", "", false);
        return true;
    }

    /**
     * @dev See {IERC777-burn}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function burn(uint256 amount, bytes memory data) public virtual override {
        _burn(_msgSender(), amount, data, "");
    }

    /**
     * @dev See {IERC777-isOperatorFor}.
     */
    function isOperatorFor(address operator, address tokenHolder) public view virtual override returns (bool) {
        return operator == tokenHolder
            || (_defaultOperators[operator] && !_revokedDefaultOperators[tokenHolder][operator])
            || _operators[tokenHolder][operator];
    }

    /**
     * @dev See {IERC777-authorizeOperator}.
     */
    function authorizeOperator(address operator) public virtual override {
        require(_msgSender() != operator, "ERC777: authorizing self as operator");

        if (_defaultOperators[operator]) {
            delete _revokedDefaultOperators[_msgSender()][operator];
        } else {
            _operators[_msgSender()][operator] = true;
        }

        emit AuthorizedOperator(operator, _msgSender());
    }

    /**
     * @dev See {IERC777-revokeOperator}.
     */
    function revokeOperator(address operator) public virtual override {
        require(operator != _msgSender(), "ERC777: revoking self as operator");

        if (_defaultOperators[operator]) {
            _revokedDefaultOperators[_msgSender()][operator] = true;
        } else {
            delete _operators[_msgSender()][operator];
        }

        emit RevokedOperator(operator, _msgSender());
    }

    /**
     * @dev See {IERC777-defaultOperators}.
     */
    function defaultOperators() public view virtual override returns (address[] memory) {
        return _defaultOperatorsArray;
    }

    /**
     * @dev See {IERC777-operatorSend}.
     *
     * Emits {Sent} and {IERC20-Transfer} events.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public virtual override {
        require(isOperatorFor(_msgSender(), sender), "ERC777: caller is not an operator for holder");
        _send(sender, recipient, amount, data, operatorData, true);
    }

    /**
     * @dev See {IERC777-operatorBurn}.
     *
     * Emits {Burned} and {IERC20-Transfer} events.
     */
    function operatorBurn(address account, uint256 amount, bytes memory data, bytes memory operatorData)
        public
        virtual
        override
    {
        require(isOperatorFor(_msgSender(), account), "ERC777: caller is not an operator for holder");
        _burn(account, amount, data, operatorData);
    }

    /**
     * @dev See {IERC20-allowance}.
     *
     * Note that operator and allowance concepts are orthogonal: operators may
     * not have allowance, and accounts with allowance may not be operators
     * themselves.
     */
    function allowance(address holder, address spender) public view virtual override returns (uint256) {
        return _allowances[holder][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Note that accounts cannot have allowance issued by their operators.
     */
    function approve(address spender, uint256 value) public virtual override returns (bool) {
        address holder = _msgSender();
        _approve(holder, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Note that operator and allowance concepts are orthogonal: operators cannot
     * call `transferFrom` (unless they have allowance), and accounts with
     * allowance cannot call `operatorSend` (unless they are operators).
     *
     * Emits {Sent}, {IERC20-Transfer} and {IERC20-Approval} events.
     */
    function transferFrom(address holder, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(holder, spender, amount);
        _send(holder, recipient, amount, "", "", false);
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with the caller address as the `operator` and with
     * `userData` and `operatorData`.
     *
     * See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits {Minted} and {IERC20-Transfer} events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function _mint(address account, uint256 amount, bytes memory userData, bytes memory operatorData)
        internal
        virtual
    {
        _mint(account, amount, userData, operatorData, true);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If `requireReceptionAck` is set to true, and if a send hook is
     * registered for `account`, the corresponding function will be called with
     * `operator`, `data` and `operatorData`.
     *
     * See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits {Minted} and {IERC20-Transfer} events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function _mint(
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(account != address(0), "ERC777: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, amount);

        // Update state variables
        _totalSupply += amount;
        _balances[account] += amount;

        _callTokensReceived(operator, address(0), account, amount, userData, operatorData, requireReceptionAck);

        emit Minted(operator, account, amount, userData, operatorData);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Send tokens
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _send(
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(from != address(0), "ERC777: transfer from the zero address");
        require(to != address(0), "ERC777: transfer to the zero address");

        address operator = _msgSender();

        _callTokensToSend(operator, from, to, amount, userData, operatorData);

        _move(operator, from, to, amount, userData, operatorData);

        _callTokensReceived(operator, from, to, amount, userData, operatorData, requireReceptionAck);
    }

    /**
     * @dev Burn tokens
     * @param from address token holder address
     * @param amount uint256 amount of tokens to burn
     * @param data bytes extra information provided by the token holder
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _burn(address from, uint256 amount, bytes memory data, bytes memory operatorData) internal virtual {
        require(from != address(0), "ERC777: burn from the zero address");

        address operator = _msgSender();

        _callTokensToSend(operator, from, address(0), amount, data, operatorData);

        _beforeTokenTransfer(operator, from, address(0), amount);

        // Update state variables
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: burn amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _totalSupply -= amount;

        emit Burned(operator, from, amount, data, operatorData);
        emit Transfer(from, address(0), amount);
    }

    function _move(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        _beforeTokenTransfer(operator, from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC777: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);
    }

    /**
     * @dev See {ERC20-_approve}.
     *
     * Note that accounts cannot have allowance issued by their operators.
     */
    function _approve(address holder, address spender, uint256 value) internal virtual {
        require(holder != address(0), "ERC777: approve from the zero address");
        require(spender != address(0), "ERC777: approve to the zero address");

        _allowances[holder][spender] = value;
        emit Approval(holder, spender, value);
    }

    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }

    /**
     * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
     * tokensReceived() was not registered for the recipient
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            // require(!to.isContract(), "ERC777: token recipient contract has no implementer for
            // ERC777TokensRecipient");
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {IERC20-Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC777: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes
     * calls to {send}, {transfer}, {operatorSend}, {transferFrom}, minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address operator, address from, address to, uint256 amount) internal virtual {}
}

contract ERC777Mock is ERC777 {
    constructor(uint256 initialSupply, address[] memory _defaultOperators, IERC1820Registry registry)
        ERC777("myToken", "MTK", _defaultOperators, registry)
    {}

    function setBalance(address account, uint256 amount) external {
        _burn(account, balanceOf(account), "", "");
        _mint(account, amount, "", "");
    }
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/mocks/ERC777Mock.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/INotificationReceiver.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Notification Receiver interface
interface INotificationReceiver {
    /// @notice Called after a token transfer.
    /// @dev Notifies the solution about the token transfer.
    /// @param _sender address empty on mint
    /// @param _senderBalance uint256 sender balance AFTER token transfer
    /// @param _recipient address empty on burn
    /// @param _recipientBalance uint256 recipient balance AFTER token transfer
    /// @param _totalSupply uint256 totalSupply AFTER token transfer
    /// @param _amount uint256 transfer amount
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/INotificationReceiver.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IIncentivesClaimingLogic} from "./IIncentivesClaimingLogic.sol";
import {INotificationReceiver} from "./INotificationReceiver.sol";

/// @title Vault Incentives Module interface
interface IVaultIncentivesModule {
    event IncentivesClaimingLogicAdded(address indexed market, address logic);
    event IncentivesClaimingLogicRemoved(address indexed market, address logic);
    event NotificationReceiverAdded(address notificationReceiver);
    event NotificationReceiverRemoved(address notificationReceiver);

    error AddressZero();
    error LogicAlreadyAdded();
    error LogicNotFound();
    error NotificationReceiverAlreadyAdded();
    error NotificationReceiverNotFound();
    error MarketAlreadySet();
    error MarketNotConfigured();

    /// @notice Add an incentives claiming logic for the vault.
    /// @param _market The market to add the logic for.
    /// @param _logic The logic to add.
    function addIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Remove an incentives claiming logic for the vault.
    /// @param _market The market to remove the logic for.
    /// @param _logic The logic to remove.
    function removeIncentivesClaimingLogic(address _market, IIncentivesClaimingLogic _logic) external;

    /// @notice Add an incentives distribution solution for the vault.
    /// @param _notificationReceiver The solution to add.
    function addNotificationReceiver(INotificationReceiver _notificationReceiver) external;

    /// @notice Remove an incentives distribution solution for the vault.
    /// @param _notificationReceiver The solution to remove.
    function removeNotificationReceiver(INotificationReceiver _notificationReceiver) external;

    /// @notice Get all incentives claiming logics for the vault.
    /// @return logics The logics.
    function getAllIncentivesClaimingLogics() external view returns (address[] memory logics);

    /// @notice Get all incentives claiming logics for the vault.
    /// @param _markets The markets to get the incentives claiming logics for.
    /// @return logics The logics.
    function getMarketsIncentivesClaimingLogics(address[] calldata _markets)
        external
        view
        returns (address[] memory logics);

    /// @notice Get all incentives distribution solutions for the vault.
    /// @return _notificationReceivers
    function getNotificationReceivers() external view returns (address[] memory _notificationReceivers);

    /// @notice Get incentives claiming logics for a market.
    /// @param _market The market to get the incentives claiming logics for.
    /// @return logics
    function getMarketIncentivesClaimingLogics(address _market) external view returns (address[] memory logics);

    /// @notice Get all configured markets for the vault.
    /// @return markets
    function getConfiguredMarkets() external view returns (address[] memory markets);
}


--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IVaultIncentivesModule.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IPublicAllocator.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloVault} from "./ISiloVault.sol";

    /// @dev Max settable flow cap, such that caps can always be stored on 128 bits.
    /// @dev The actual max possible flow cap is type(uint128).max-1.
    /// @dev Equals to 170141183460469231731687303715884105727;
    uint128 constant MAX_SETTABLE_FLOW_CAP = type(uint128).max / 2;

    struct FlowCaps {
        /// @notice The maximum allowed inflow in a market.
        uint128 maxIn;
        /// @notice The maximum allowed outflow in a market.
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        /// @notice Market for which to change flow caps.
        IERC4626 market;
        /// @notice New flow caps for this market.
        FlowCaps caps;
    }

    struct Withdrawal {
        /// @notice The market from which to withdraw.
        IERC4626 market;
        /// @notice The amount to withdraw.
        uint128 amount;
    }

/// @dev This interface is used for factorizing IPublicAllocatorStaticTyping and IPublicAllocator.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorBase {
    /// @notice The admin for a given vault.
    function admin(ISiloVault _vault) external view returns (address);

    /// @notice The current ETH fee for a given vault.
    function fee(ISiloVault _vault) external view returns (uint256);

    /// @notice The accrued ETH fee for a given vault.
    function accruedFee(ISiloVault _vault) external view returns (uint256);

    /// @notice Reallocates from a list of markets to one market.
    /// @param _vault The SiloVault vault to reallocate.
    /// @param _withdrawals The markets to withdraw from,and the amounts to withdraw.
    /// @param _supplyMarket The market receiving total withdrawn to.
    /// @dev Will call SiloVault's `reallocate`.
    /// @dev Checks that the flow caps are respected.
    /// @dev Will revert when `withdrawals` contains a duplicate or is not sorted.
    /// @dev Will revert if `withdrawals` contains the supply market.
    /// @dev Will revert if a withdrawal amount is larger than available liquidity.
    /// @dev flow is as follow:
    /// - iterating over withdrawals markets
    ///   - increase flowCaps.maxIn by withdrawal amount for market
    ///   - decrease flowCaps.maxOut by withdrawal amount for market
    ///   - put market into allocation list with amount equal `market deposit - withdrawal amount`
    ///   - increase total amount to withdraw
    /// - after iteration, with allocation list ready, final steps are:
    ///   - decrease flowCaps.maxIn by total withdrawal amount for `supplyMarket`
    ///   - increase flowCaps.maxOut by total withdrawal amount for `supplyMarket`
    ///   - add `supplyMarket` to allocation list with MAX assets
    ///   - run `reallocate` on SiloVault
    function reallocateTo(ISiloVault _vault, Withdrawal[] calldata _withdrawals, IERC4626 _supplyMarket)
        external
        payable;

    /// @notice Sets the admin for a given vault.
    function setAdmin(ISiloVault _vault, address _newAdmin) external;

    /// @notice Sets the fee for a given vault.
    function setFee(ISiloVault _vault, uint256 _newFee) external;

    /// @notice Transfers the current balance to `feeRecipient` for a given vault.
    function transferFee(ISiloVault _vault, address payable _feeRecipient) external;

    /// @notice Sets the maximum inflow and outflow through public allocation for some markets for a given vault.
    /// @dev Max allowed inflow/outflow is MAX_SETTABLE_FLOW_CAP.
    /// @dev Doesn't revert if it doesn't change the storage at all.
    function setFlowCaps(ISiloVault _vault, FlowCapsConfig[] calldata _config) external;
}

/// @dev This interface is inherited by PublicAllocator so that function signatures are checked by the compiler.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorStaticTyping is IPublicAllocatorBase {
    /// @notice Returns (maximum inflow, maximum outflow) through public allocation of a given market for a given vault.
    function flowCaps(ISiloVault _vault, IERC4626 _market) external view returns (uint128, uint128);
}

/// @title IPublicAllocator
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @dev Use this interface for PublicAllocator to have access to all the functions with the appropriate function
/// signatures.
interface IPublicAllocator is IPublicAllocatorBase {
    /// @notice Returns the maximum inflow and maximum outflow through public allocation of a given market for a given
    /// vault.
    function flowCaps(ISiloVault _vault, IERC4626 _market) external view returns (FlowCaps memory);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IPublicAllocator.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloVault.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {MarketConfig, PendingUint192, PendingAddress} from "../libraries/PendingLib.sol";
import {IVaultIncentivesModule} from "./IVaultIncentivesModule.sol";

struct MarketAllocation {
    /// @notice The market to allocate.
    IERC4626 market;
    /// @notice The amount of assets to allocate.
    uint256 assets;
}

interface IMulticall {
    function multicall(bytes[] calldata) external returns (bytes[] memory);
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address) external;
    function renounceOwnership() external;
    function acceptOwnership() external;
    function pendingOwner() external view returns (address);
}

/// @dev This interface is used for factorizing ISiloVaultStaticTyping and ISiloVault.
/// @dev Consider using the ISiloVault interface instead of this one.
interface ISiloVaultBase {
    function DECIMALS_OFFSET() external view returns (uint8);

    function INCENTIVES_MODULE() external view returns (IVaultIncentivesModule);

    /// @notice method for claiming and distributing incentives rewards for all vault users
    function claimRewards() external;

    /// @notice Returns whether the reentrancy guard is entered.
    function reentrancyGuardEntered() external view returns (bool);

    /// @notice The address of the curator.
    function curator() external view returns (address);

    /// @notice Stores whether an address is an allocator or not.
    function isAllocator(address _target) external view returns (bool);

    /// @notice The current guardian. Can be set even without the timelock set.
    function guardian() external view returns (address);

    /// @notice The current fee.
    function fee() external view returns (uint96);

    /// @notice The fee recipient.
    function feeRecipient() external view returns (address);

    /// @notice The skim recipient.
    function skimRecipient() external view returns (address);

    /// @notice The current timelock.
    function timelock() external view returns (uint256);

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    function supplyQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the supply queue.
    function supplyQueueLength() external view returns (uint256);

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap markets as well as all markets on which the vault supplies liquidity,
    /// without duplicate.
    function withdrawQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the withdraw queue.
    function withdrawQueueLength() external view returns (uint256);

    /// @notice Stores the total assets managed by this vault when the fee was last accrued.
    /// @dev May be greater than `totalAssets()` due to removal of markets with non-zero supply or socialized bad debt.
    /// This difference will decrease the fee accrued until one of the functions updating `lastTotalAssets` is
    /// triggered (deposit/mint/withdraw/redeem/setFee/setFeeRecipient).
    function lastTotalAssets() external view returns (uint256);

    /// @notice Submits a `newTimelock`.
    /// @dev Warning: Reverts if a timelock is already pending. Revoke the pending timelock to overwrite it.
    /// @dev In case the new timelock is higher than the current one, the timelock is set immediately.
    function submitTimelock(uint256 _newTimelock) external;

    /// @notice Accepts the pending timelock.
    function acceptTimelock() external;

    /// @notice Revokes the pending timelock.
    /// @dev Does not revert if there is no pending timelock.
    function revokePendingTimelock() external;

    /// @notice Submits a `newSupplyCap` for the market defined by `marketParams`.
    /// @dev Warning: Reverts if a cap is already pending. Revoke the pending cap to overwrite it.
    /// @dev Warning: Reverts if a market removal is pending.
    /// @dev In case the new cap is lower than the current one, the cap is set immediately.
    function submitCap(IERC4626 _market, uint256 _newSupplyCap) external;

    /// @notice Accepts the pending cap of the market defined by `marketParams`.
    function acceptCap(IERC4626 _market) external;

    /// @notice Revokes the pending cap of the market defined by `market`.
    /// @dev Does not revert if there is no pending cap.
    function revokePendingCap(IERC4626 _market) external;

    /// @notice Submits a forced market removal from the vault, eventually losing all funds supplied to the market.
    /// @notice Funds can be recovered by enabling this market again and withdrawing from it (using `reallocate`),
    /// but funds will be distributed pro-rata to the shares at the time of withdrawal, not at the time of removal.
    /// @notice This forced removal is expected to be used as an emergency process in case a market constantly reverts.
    /// To softly remove a sane market, the curator role is expected to bundle a reallocation that empties the market
    /// first (using `reallocate`), followed by the removal of the market (using `updateWithdrawQueue`).
    /// @dev Warning: Removing a market with non-zero supply will instantly impact the vault's price per share.
    /// @dev Warning: Reverts for non-zero cap or if there is a pending cap. Successfully submitting a zero cap will
    /// prevent such reverts.
    function submitMarketRemoval(IERC4626 _market) external;

    /// @notice Revokes the pending removal of the market defined by `market`.
    /// @dev Does not revert if there is no pending market removal.
    function revokePendingMarketRemoval(IERC4626 _market) external;

    /// @notice Submits a `newGuardian`.
    /// @notice Warning: a malicious guardian could disrupt the vault's operation, and would have the power to revoke
    /// any pending guardian.
    /// @dev In case there is no guardian, the gardian is set immediately.
    /// @dev Warning: Submitting a gardian will overwrite the current pending gardian.
    function submitGuardian(address _newGuardian) external;

    /// @notice Accepts the pending guardian.
    function acceptGuardian() external;

    /// @notice Revokes the pending guardian.
    function revokePendingGuardian() external;

    /// @notice Skims the vault `token` balance to `skimRecipient`.
    function skim(address) external;

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address _newAllocator, bool _newIsAllocator) external;

    /// @notice Sets `curator` to `newCurator`.
    function setCurator(address _newCurator) external;

    /// @notice Sets the `fee` to `newFee`.
    function setFee(uint256 _newFee) external;

    /// @notice Sets `feeRecipient` to `newFeeRecipient`.
    function setFeeRecipient(address _newFeeRecipient) external;

    /// @notice Sets `skimRecipient` to `newSkimRecipient`.
    function setSkimRecipient(address _newSkimRecipient) external;

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @param _newSupplyQueue is an array of enabled markets, and can contain duplicate markets, but it would only
    /// increase the cost of depositing to the vault.
    function setSupplyQueue(IERC4626[] calldata _newSupplyQueue) external;

    /// @notice Updates the withdraw queue. Some markets can be removed, but no market can be added.
    /// @notice Removing a market requires the vault to have 0 supply on it, or to have previously submitted a removal
    /// for this market (with the function `submitMarketRemoval`).
    /// @notice Warning: Anyone can supply on behalf of the vault so the call to `updateWithdrawQueue` that expects a
    /// market to be empty can be griefed by a front-run. To circumvent this, the allocator can simply bundle a
    /// reallocation that withdraws max from this market with a call to `updateWithdrawQueue`.
    /// @dev Warning: Removing a market with supply will decrease the fee accrued until one of the functions updating
    /// `lastTotalAssets` is triggered (deposit/mint/withdraw/redeem/setFee/setFeeRecipient).
    /// @dev Warning: `updateWithdrawQueue` is not idempotent. Submitting twice the same tx will change the queue twice.
    /// @param _indexes The indexes of each market in the previous withdraw queue, in the new withdraw queue's order.
    function updateWithdrawQueue(uint256[] calldata _indexes) external;

    /// @notice Reallocates the vault's liquidity so as to reach a given allocation of assets on each given market.
    /// @dev The behavior of the reallocation can be altered by state changes, including:
    /// - Deposits on the vault that supplies to markets that are expected to be supplied to during reallocation.
    /// - Withdrawals from the vault that withdraws from markets that are expected to be withdrawn from during
    /// reallocation.
    /// - Donations to the vault on markets that are expected to be supplied to during reallocation.
    /// - Withdrawals from markets that are expected to be withdrawn from during reallocation.
    /// @dev Sender is expected to pass `assets = type(uint256).max` with the last MarketAllocation of `allocations` to
    /// supply all the remaining withdrawn liquidity, which would ensure that `totalWithdrawn` = `totalSupplied`.
    /// @dev A supply in a reallocation step will make the reallocation revert if the amount is greater than the net
    /// amount from previous steps (i.e. total withdrawn minus total supplied).
    function reallocate(MarketAllocation[] calldata _allocations) external;
}

/// @dev This interface is inherited by SiloVault so that function signatures are checked by the compiler.
/// @dev Consider using the ISiloVault interface instead of this one.
interface ISiloVaultStaticTyping is ISiloVaultBase {
    /// @notice Returns the current configuration of each market.
    function config(IERC4626) external view returns (uint184 cap, bool enabled, uint64 removableAt);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (address guardian, uint64 validAt);

    /// @notice Returns the pending cap for each market.
    function pendingCap(IERC4626) external view returns (uint192 value, uint64 validAt);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (uint192 value, uint64 validAt);
}

/// @title IMetaMorpho
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @dev Use this interface for SiloVault to have access to all the functions with the appropriate function signatures.
interface ISiloVault is ISiloVaultBase, IERC4626, IERC20Permit, IOwnable, IMulticall {
    /// @notice Returns the current configuration of each market.
    function config(IERC4626) external view returns (MarketConfig memory);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (PendingAddress memory);

    /// @notice Returns the pending cap for each market.
    function pendingCap(IERC4626) external view returns (PendingUint192 memory);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (PendingUint192 memory);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloVault.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloVaultsFactory.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ISiloVault} from "./ISiloVault.sol";

/// @title ISiloVaultsFactory
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice Interface of SiloVault's factory.
interface ISiloVaultsFactory {
    /// @notice Whether a SiloVault vault was created with the factory.
    function isSiloVault(address _target) external view returns (bool);

    /// @notice Creates a new SiloVault vault.
    /// @param _initialOwner The owner of the vault.
    /// @param _initialTimelock The initial timelock of the vault.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    function createSiloVault(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external returns (ISiloVault SiloVault);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloVaultsFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol ---
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SiloIncentivesControllerCL} from "../incentives/claiming-logics/SiloIncentivesControllerCL.sol";

/// @title ISiloIncentivesControllerCLFactory
interface ISiloIncentivesControllerCLFactory {
    /// @notice Emitted when a new SiloIncentivesControllerCL instance is created
    event IncentivesControllerCLCreated(address logic);

    /// @notice Creates a new SiloIncentivesControllerCL instance
    /// @param _vaultIncentivesController The address of the vault incentives controller
    /// @param _siloIncentivesController The address of the silo incentives controller
    /// @return logic The address of the created SiloIncentivesControllerCL instance
    function createIncentivesControllerCL(
        address _vaultIncentivesController,
        address _siloIncentivesController
    ) external returns (SiloIncentivesControllerCL logic);

    /// @notice Checks if a SiloIncentivesControllerCL instance is created in the factory
    /// @param _logic The address of the SiloIncentivesControllerCL instance
    /// @return createdInFactory Whether the SiloIncentivesControllerCL instance is created in the factory
    function createdInFactory(address _logic) external view returns (bool createdInFactory);
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/ISiloIncentivesControllerCLFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol ---
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Incentives Claiming Logic interface
interface IIncentivesClaimingLogic {
    /// @notice Claim and distribute rewards to the vault.
    /// @dev Can claim rewards from multiple sources and distribute them to the vault users.
    function claimRewardsAndDistribute() external;
}

--- END FILE: ../silo-contracts-v2/silo-vaults/contracts/interfaces/IIncentivesClaimingLogic.sol ---
