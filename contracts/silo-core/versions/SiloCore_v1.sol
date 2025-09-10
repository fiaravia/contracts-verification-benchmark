--- START FILE: ../silo-contracts-v2/silo-core/contracts/SiloConfig.sol ---
pragma solidity 0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {CrossReentrancyGuard} from "./utils/CrossReentrancyGuard.sol";
import {Hook} from "./lib/Hook.sol";
contract SiloConfig is ISiloConfig, CrossReentrancyGuard {
    using Hook for uint256;
    uint256 public immutable SILO_ID;
    uint256 internal immutable _DAO_FEE;
    uint256 internal immutable _DEPLOYER_FEE;
    address internal immutable _HOOK_RECEIVER;
    address internal immutable _SILO0;
    address internal immutable _TOKEN0;
    address internal immutable _PROTECTED_COLLATERAL_SHARE_TOKEN0;
    address internal immutable _COLLATERAL_SHARE_TOKEN0;
    address internal immutable _DEBT_SHARE_TOKEN0;
    address internal immutable _SOLVENCY_ORACLE0;
    address internal immutable _MAX_LTV_ORACLE0;
    address internal immutable _INTEREST_RATE_MODEL0;
    uint256 internal immutable _MAX_LTV0;
    uint256 internal immutable _LT0;
    uint256 internal immutable _LIQUIDATION_TARGET_LTV0;
    uint256 internal immutable _LIQUIDATION_FEE0;
    uint256 internal immutable _FLASHLOAN_FEE0;
    bool internal immutable _CALL_BEFORE_QUOTE0;
    address internal immutable _SILO1;
    address internal immutable _TOKEN1;
    address internal immutable _PROTECTED_COLLATERAL_SHARE_TOKEN1;
    address internal immutable _COLLATERAL_SHARE_TOKEN1;
    address internal immutable _DEBT_SHARE_TOKEN1;
    address internal immutable _SOLVENCY_ORACLE1;
    address internal immutable _MAX_LTV_ORACLE1;
    address internal immutable _INTEREST_RATE_MODEL1;
    uint256 internal immutable _MAX_LTV1;
    uint256 internal immutable _LT1;
    uint256 internal immutable _LIQUIDATION_TARGET_LTV1;
    uint256 internal immutable _LIQUIDATION_FEE1;
    uint256 internal immutable _FLASHLOAN_FEE1;
    bool internal immutable _CALL_BEFORE_QUOTE1;
    mapping (address borrower => address collateralSilo) public borrowerCollateralSilo;
    constructor( 
        uint256 _siloId,
        ConfigData memory _configData0,
        ConfigData memory _configData1
    ) CrossReentrancyGuard() {
        SILO_ID = _siloId;
        require(_configData0.daoFee + _configData0.deployerFee < 1e18, FeeTooHigh());
        _DAO_FEE = _configData0.daoFee;
        _DEPLOYER_FEE = _configData0.deployerFee;
        _HOOK_RECEIVER = _configData0.hookReceiver;
        _SILO0 = _configData0.silo;
        _TOKEN0 = _configData0.token;
        _PROTECTED_COLLATERAL_SHARE_TOKEN0 = _configData0.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN0 = _configData0.silo;
        _DEBT_SHARE_TOKEN0 = _configData0.debtShareToken;
        _SOLVENCY_ORACLE0 = _configData0.solvencyOracle;
        _MAX_LTV_ORACLE0 = _configData0.maxLtvOracle;
        _INTEREST_RATE_MODEL0 = _configData0.interestRateModel;
        _MAX_LTV0 = _configData0.maxLtv;
        _LT0 = _configData0.lt;
        _LIQUIDATION_TARGET_LTV0 = _configData0.liquidationTargetLtv;
        _LIQUIDATION_FEE0 = _configData0.liquidationFee;
        _FLASHLOAN_FEE0 = _configData0.flashloanFee;
        _CALL_BEFORE_QUOTE0 = _configData0.callBeforeQuote;
        _SILO1 = _configData1.silo;
        _TOKEN1 = _configData1.token;
        _PROTECTED_COLLATERAL_SHARE_TOKEN1 = _configData1.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN1 = _configData1.silo;
        _DEBT_SHARE_TOKEN1 = _configData1.debtShareToken;
        _SOLVENCY_ORACLE1 = _configData1.solvencyOracle;
        _MAX_LTV_ORACLE1 = _configData1.maxLtvOracle;
        _INTEREST_RATE_MODEL1 = _configData1.interestRateModel;
        _MAX_LTV1 = _configData1.maxLtv;
        _LT1 = _configData1.lt;
        _LIQUIDATION_TARGET_LTV1 = _configData1.liquidationTargetLtv;
        _LIQUIDATION_FEE1 = _configData1.liquidationFee;
        _FLASHLOAN_FEE1 = _configData1.flashloanFee;
        _CALL_BEFORE_QUOTE1 = _configData1.callBeforeQuote;
    }
    function setThisSiloAsCollateralSilo(address _borrower) external virtual {
        _onlySilo();
        borrowerCollateralSilo[_borrower] = msg.sender;
    }
    function setOtherSiloAsCollateralSilo(address _borrower) external virtual {
        _onlySilo();
        borrowerCollateralSilo[_borrower] = msg.sender == _SILO0 ? _SILO1 : _SILO0;
    }
    function onDebtTransfer(address _sender, address _recipient) external virtual {
        require(msg.sender == _DEBT_SHARE_TOKEN0 || msg.sender == _DEBT_SHARE_TOKEN1, OnlyDebtShareToken());
        address thisSilo = msg.sender == _DEBT_SHARE_TOKEN0 ? _SILO0 : _SILO1;
        require(!hasDebtInOtherSilo(thisSilo, _recipient), DebtExistInOtherSilo());
        if (borrowerCollateralSilo[_recipient] == address(0)) {
            borrowerCollateralSilo[_recipient] = borrowerCollateralSilo[_sender];
        }
    }
    function accrueInterestForSilo(address _silo) external virtual {
        address irm;
        if (_silo == _SILO0) {
            irm = _INTEREST_RATE_MODEL0;
        } else if (_silo == _SILO1) {
            irm = _INTEREST_RATE_MODEL1;
        } else {
            revert WrongSilo();
        }
        ISilo(_silo).accrueInterestForConfig(
            irm,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
    }
    function accrueInterestForBothSilos() external virtual {
        ISilo(_SILO0).accrueInterestForConfig(
            _INTEREST_RATE_MODEL0,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
        ISilo(_SILO1).accrueInterestForConfig(
            _INTEREST_RATE_MODEL1,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
    }
    function getConfigsForSolvency(address _borrower) public view virtual returns (
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    ) {
        address debtSilo = getDebtSilo(_borrower);
        if (debtSilo == address(0)) return (collateralConfig, debtConfig);
        address collateralSilo = borrowerCollateralSilo[_borrower];
        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(debtSilo);
    }
    function getConfigsForWithdraw(address _silo, address _depositOwner) external view virtual returns (
        DepositConfig memory depositConfig,
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    ) {
        depositConfig = _getDepositConfig(_silo);
        (collateralConfig, debtConfig) = getConfigsForSolvency(_depositOwner);
    }
    function getConfigsForBorrow(address _debtSilo)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        address collateralSilo; 
        if (_debtSilo == _SILO0) {
            collateralSilo = _SILO1;
        } else if (_debtSilo == _SILO1) {
            collateralSilo = _SILO0;
        } else {
            revert WrongSilo();
        }
        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(_debtSilo);
    }
    function getSilos() external view virtual returns (address silo0, address silo1) {
        return (_SILO0, _SILO1);
    }
    function getShareTokens(address _silo)
        external
        view
        virtual
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    {
        if (_silo == _SILO0) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN0, _COLLATERAL_SHARE_TOKEN0, _DEBT_SHARE_TOKEN0);
        } else if (_silo == _SILO1) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN1, _COLLATERAL_SHARE_TOKEN1, _DEBT_SHARE_TOKEN1);
        } else {
            revert WrongSilo();
        }
    }
    function getAssetForSilo(address _silo) external view virtual returns (address asset) {
        if (_silo == _SILO0) {
            return _TOKEN0;
        } else if (_silo == _SILO1) {
            return _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }
    function getFeesWithAsset(address _silo)
        external
        view
        virtual
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    {
        daoFee = _DAO_FEE;
        deployerFee = _DEPLOYER_FEE;
        if (_silo == _SILO0) {
            asset = _TOKEN0;
            flashloanFee = _FLASHLOAN_FEE0;
        } else if (_silo == _SILO1) {
            asset = _TOKEN1;
            flashloanFee = _FLASHLOAN_FEE1;
        } else {
            revert WrongSilo();
        }
    }
    function getCollateralShareTokenAndAsset(address _silo, ISilo.CollateralType _collateralType)
        external
        view
        virtual
        returns (address shareToken, address asset)
    {
        if (_silo == _SILO0) {
            return _collateralType == ISilo.CollateralType.Collateral
                ? (_COLLATERAL_SHARE_TOKEN0, _TOKEN0)
                : (_PROTECTED_COLLATERAL_SHARE_TOKEN0, _TOKEN0);
        } else if (_silo == _SILO1) {
            return _collateralType == ISilo.CollateralType.Collateral
                ? (_COLLATERAL_SHARE_TOKEN1, _TOKEN1)
                : (_PROTECTED_COLLATERAL_SHARE_TOKEN1, _TOKEN1);
        } else {
            revert WrongSilo();
        }
    }
    function getDebtShareTokenAndAsset(address _silo)
        external
        view
        virtual
        returns (address shareToken, address asset)
    {
        if (_silo == _SILO0) {
            return (_DEBT_SHARE_TOKEN0, _TOKEN0);
        } else if (_silo == _SILO1) {
            return (_DEBT_SHARE_TOKEN1, _TOKEN1);
        } else {
            revert WrongSilo();
        }
    }
    function getConfig(address _silo) public view virtual returns (ConfigData memory config) {
        if (_silo == _SILO0) {
            config = _silo0ConfigData();
        } else if (_silo == _SILO1) {
            config = _silo1ConfigData();
        } else {
            revert WrongSilo();
        }
    }
    function hasDebtInOtherSilo(address _thisSilo, address _borrower) public view virtual returns (bool hasDebt) {
        if (_thisSilo == _SILO0) {
            hasDebt = _balanceOf(_DEBT_SHARE_TOKEN1, _borrower) != 0;
        } else if (_thisSilo == _SILO1) {
            hasDebt = _balanceOf(_DEBT_SHARE_TOKEN0, _borrower) != 0;
        } else {
            revert WrongSilo();
        }
     }
    function getDebtSilo(address _borrower) public view virtual returns (address debtSilo) {
        uint256 debtBal0 = _balanceOf(_DEBT_SHARE_TOKEN0, _borrower);
        uint256 debtBal1 = _balanceOf(_DEBT_SHARE_TOKEN1, _borrower);
        require(debtBal0 == 0 || debtBal1 == 0, DebtExistInOtherSilo());
        if (debtBal0 == 0 && debtBal1 == 0) return address(0);
        debtSilo = debtBal0 != 0 ? _SILO0 : _SILO1;
    }
    function _silo0ConfigData() internal view virtual returns (ConfigData memory config) {
        config = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
            silo: _SILO0,
            token: _TOKEN0,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
            debtShareToken: _DEBT_SHARE_TOKEN0,
            solvencyOracle: _SOLVENCY_ORACLE0,
            maxLtvOracle: _MAX_LTV_ORACLE0,
            interestRateModel: _INTEREST_RATE_MODEL0,
            maxLtv: _MAX_LTV0,
            lt: _LT0,
            liquidationTargetLtv: _LIQUIDATION_TARGET_LTV0,
            liquidationFee: _LIQUIDATION_FEE0,
            flashloanFee: _FLASHLOAN_FEE0,
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE0
        });
    }
    function _silo1ConfigData() internal view virtual returns (ConfigData memory config) {
        config = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
            silo: _SILO1,
            token: _TOKEN1,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
            debtShareToken: _DEBT_SHARE_TOKEN1,
            solvencyOracle: _SOLVENCY_ORACLE1,
            maxLtvOracle: _MAX_LTV_ORACLE1,
            interestRateModel: _INTEREST_RATE_MODEL1,
            maxLtv: _MAX_LTV1,
            lt: _LT1,
            liquidationTargetLtv: _LIQUIDATION_TARGET_LTV1,
            liquidationFee: _LIQUIDATION_FEE1,
            flashloanFee: _FLASHLOAN_FEE1,
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });
    }
    function _getDepositConfig(address _silo) internal view virtual returns (DepositConfig memory config) {
        if (_silo == _SILO0) {
            config = DepositConfig({
                silo: _SILO0,
                token: _TOKEN0,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
                interestRateModel: _INTEREST_RATE_MODEL0
            });
        } else if (_silo == _SILO1) {
            config = DepositConfig({
                silo: _SILO1,
                token: _TOKEN1,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
                interestRateModel: _INTEREST_RATE_MODEL1
            });
        } else {
            revert WrongSilo();
        }
    }
    function _onlySiloOrTokenOrHookReceiver() internal view virtual override {
        if (msg.sender != _SILO0 &&
            msg.sender != _SILO1 &&
            msg.sender != _HOOK_RECEIVER &&
            msg.sender != _COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 &&
            msg.sender != _DEBT_SHARE_TOKEN1
        ) {
            revert OnlySiloOrTokenOrHookReceiver();
        }
    }
    function _onlySilo() internal view virtual {
        require(msg.sender == _SILO0 || msg.sender == _SILO1, OnlySilo());
    }
    function _balanceOf(address _token, address _user) internal view virtual returns (uint256 balance) {
        balance = IERC20(_token).balanceOf(_user);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/SiloConfig.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/Silo.sol ---
pragma solidity 0.8.28;
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ISilo, IERC4626, IERC3156FlashLender} from "./interfaces/ISilo.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ShareCollateralToken} from "./utils/ShareCollateralToken.sol";
import {Actions} from "./lib/Actions.sol";
import {Views} from "./lib/Views.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
import {SiloLendingLib} from "./lib/SiloLendingLib.sol";
import {SiloERC4626Lib} from "./lib/SiloERC4626Lib.sol";
import {SiloMathLib} from "./lib/SiloMathLib.sol";
import {Rounding} from "./lib/Rounding.sol";
import {Hook} from "./lib/Hook.sol";
import {ShareTokenLib} from "./lib/ShareTokenLib.sol";
import {SiloStorageLib} from "./lib/SiloStorageLib.sol";
contract Silo is ISilo, ShareCollateralToken {
    using SafeERC20 for IERC20;
    ISiloFactory public immutable factory;
    constructor(ISiloFactory _siloFactory) {
        factory = _siloFactory;
    }
    receive() external payable {}
    function silo() external view virtual override returns (ISilo) {
        return this;
    }
    function callOnBehalfOfSilo(address _target, uint256 _value, CallType _callType, bytes calldata _input)
        external
        virtual
        payable
        returns (bool success, bytes memory result)
    {
        (success, result) = Actions.callOnBehalfOfSilo(_target, _value, _callType, _input);
    }
    function initialize(ISiloConfig _config) external virtual {
        address hookReceiver = Actions.initialize(_config);
        _shareTokenInitialize(this, hookReceiver, uint24(Hook.COLLATERAL_TOKEN));
    }
    function updateHooks() external virtual {
        (uint24 hooksBefore, uint24 hooksAfter) = Actions.updateHooks();
        emit HooksUpdated(hooksBefore, hooksAfter);
    }
    function config() external view virtual returns (ISiloConfig siloConfig) {
        siloConfig = ShareTokenLib.siloConfig();
    }
    function utilizationData() external view virtual returns (UtilizationData memory) {
        return Views.utilizationData();
    }
    function getLiquidity() external view virtual returns (uint256 liquidity) {
        return SiloLendingLib.getLiquidity(ShareTokenLib.siloConfig());
    }
    function isSolvent(address _borrower) external view virtual returns (bool) {
        return Views.isSolvent(_borrower);
    }
    function getTotalAssetsStorage(AssetType _assetType)
        external
        view
        virtual
        returns (uint256 totalAssetsByType)
    {
        totalAssetsByType = SiloStorageLib.getSiloStorage().totalAssets[_assetType];
    }
    function getSiloStorage()
        external
        view
        virtual
        returns (
            uint192 daoAndDeployerRevenue,
            uint64 interestRateTimestamp,
            uint256 protectedAssets,
            uint256 collateralAssets,
            uint256 debtAssets
        )
    {
        return Views.getSiloStorage();
    }
    function getCollateralAssets() external view virtual returns (uint256 totalCollateralAssets) {
        totalCollateralAssets = _totalAssets();
    }
    function getDebtAssets() external view virtual returns (uint256 totalDebtAssets) {
        totalDebtAssets = Views.getDebtAssets();
    }
    function getCollateralAndProtectedTotalsStorage()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        (totalCollateralAssets, totalProtectedAssets) = Views.getCollateralAndProtectedAssets();
    }
    function getCollateralAndDebtTotalsStorage()
        external
        view
        virtual
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        (totalCollateralAssets, totalDebtAssets) = Views.getCollateralAndDebtAssets();
    }
    function asset() external view virtual returns (address assetTokenAddress) {
        return ShareTokenLib.siloConfig().getAssetForSilo(address(this));
    }
    function totalAssets() external view virtual returns (uint256 totalManagedAssets) {
        totalManagedAssets = _totalAssets();
    }
    function convertToShares(uint256 _assets) external view virtual returns (uint256 shares) {
        shares = _convertToShares(_assets, AssetType.Collateral);
    }
    function convertToAssets(uint256 _shares) external view virtual returns (uint256 assets) {
        assets = _convertToAssets(_shares, AssetType.Collateral);
    }
    function maxDeposit(address ) external pure virtual returns (uint256 maxAssets) {
        maxAssets = SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT;
    }
    function previewDeposit(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewDeposit(_assets, CollateralType.Collateral);
    }
    function deposit(uint256 _assets, address _receiver)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit(_assets, 0 , _receiver, CollateralType.Collateral);
    }
    function maxMint(address ) external view virtual returns (uint256 maxShares) {
        return SiloERC4626Lib._VIRTUAL_DEPOSIT_LIMIT;
    }
    function previewMint(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewMint(_shares, CollateralType.Collateral);
    }
    function mint(uint256 _shares, address _receiver) external virtual returns (uint256 assets) {
        (assets,) = _deposit({
            _assets: 0,
            _shares: _shares,
            _receiver: _receiver,
            _collateralType: CollateralType.Collateral
        });
    }
    function maxWithdraw(address _owner) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = _maxWithdraw(_owner, CollateralType.Collateral);
    }
    function previewWithdraw(uint256 _assets) external view virtual returns (uint256 shares) {
        return _previewWithdraw(_assets, CollateralType.Collateral);
    }
    function withdraw(uint256 _assets, address _receiver, address _owner)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw({
            _assets: _assets,
            _shares: 0,
            _receiver: _receiver,
            _owner: _owner,
            _spender: msg.sender,
            _collateralType: CollateralType.Collateral
        });
    }
    function maxRedeem(address _owner) external view virtual returns (uint256 maxShares) {
        (, maxShares) = _maxWithdraw(_owner, CollateralType.Collateral);
    }
    function previewRedeem(uint256 _shares) external view virtual returns (uint256 assets) {
        return _previewRedeem(_shares, CollateralType.Collateral);
    }
    function redeem(uint256 _shares, address _receiver, address _owner)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _withdraw({
            _assets: 0,
            _shares: _shares,
            _receiver: _receiver,
            _owner: _owner,
            _spender: msg.sender,
            _collateralType: CollateralType.Collateral
        });
    }
    function convertToShares(uint256 _assets, AssetType _assetType) external view virtual returns (uint256 shares) {
        shares = _convertToShares(_assets, _assetType);
    }
    function convertToAssets(uint256 _shares, AssetType _assetType) external view virtual returns (uint256 assets) {
        assets = _convertToAssets(_shares, _assetType);
    }
    function previewDeposit(uint256 _assets, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return _previewDeposit(_assets, _collateralType);
    }
    function deposit(uint256 _assets, address _receiver, CollateralType _collateralType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _deposit({
            _assets: _assets,
            _shares: 0,
            _receiver: _receiver,
            _collateralType: _collateralType
        });
    }
    function previewMint(uint256 _shares, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return _previewMint(_shares, _collateralType);
    }
    function mint(uint256 _shares, address _receiver, CollateralType _collateralType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _deposit({
            _assets: 0,
            _shares: _shares,
            _receiver: _receiver,
            _collateralType: _collateralType
        });
    }
    function maxWithdraw(address _owner, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxAssets)
    {
        (maxAssets,) = _maxWithdraw(_owner, _collateralType);
    }
    function previewWithdraw(uint256 _assets, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 shares)
    {
        return _previewWithdraw(_assets, _collateralType);
    }
    function withdraw(uint256 _assets, address _receiver, address _owner, CollateralType _collateralType)
        external
        virtual
        returns (uint256 shares)
    {
        (, shares) = _withdraw({
            _assets: _assets,
            _shares: 0,
            _receiver: _receiver,
            _owner: _owner,
            _spender: msg.sender,
            _collateralType: _collateralType
        });
    }
    function maxRedeem(address _owner, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 maxShares)
    {
        (, maxShares) = _maxWithdraw(_owner, _collateralType);
    }
    function previewRedeem(uint256 _shares, CollateralType _collateralType)
        external
        view
        virtual
        returns (uint256 assets)
    {
        return _previewRedeem(_shares, _collateralType);
    }
    function redeem(uint256 _shares, address _receiver, address _owner, CollateralType _collateralType)
        external
        virtual
        returns (uint256 assets)
    {
        (assets,) = _withdraw({
            _assets: 0,
            _shares: _shares,
            _receiver: _receiver,
            _owner: _owner,
            _spender: msg.sender,
            _collateralType: _collateralType
        });
    }
    function maxBorrow(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = Views.maxBorrow({_borrower: _borrower, _sameAsset: false});
    }
    function previewBorrow(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), AssetType.Debt);
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.BORROW_TO_SHARES, AssetType.Debt
        );
    }
    function borrow(uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;
        (assets, shares) = Actions.borrow(
            BorrowArgs({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                borrower: _borrower
            })
        );
        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }
    function maxBorrowShares(address _borrower) external view virtual returns (uint256 maxShares) {
        (,maxShares) = Views.maxBorrow({_borrower: _borrower, _sameAsset: false});
    }
    function previewBorrowShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), AssetType.Debt);
        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.BORROW_TO_ASSETS, AssetType.Debt
        );
    }
    function borrowShares(uint256 _shares, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 assets)
    {
        uint256 shares;
        (assets, shares) = Actions.borrow(
            BorrowArgs({
                assets: 0,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower
            })
        );
        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }
    function maxBorrowSameAsset(address _borrower) external view virtual returns (uint256 maxAssets) {
        (maxAssets,) = Views.maxBorrow({_borrower: _borrower, _sameAsset: true});
    }
    function borrowSameAsset(uint256 _assets, address _receiver, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;
        (assets, shares) = Actions.borrowSameAsset(
            BorrowArgs({
                assets: _assets,
                shares: 0,
                receiver: _receiver,
                borrower: _borrower
            })
        );
        emit Borrow(msg.sender, _receiver, _borrower, assets, shares);
    }
    function transitionCollateral(
        uint256 _shares,
        address _owner,
        CollateralType _transitionFrom
    )
        external
        virtual
        returns (uint256 assets)
    {
        uint256 toShares;
        (assets, toShares) = Actions.transitionCollateral(
            TransitionCollateralArgs({
                shares: _shares,
                owner: _owner,
                transitionFrom: _transitionFrom
            })
        );
        if (_transitionFrom == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _owner, _owner, assets, _shares);
            emit DepositProtected(msg.sender, _owner, assets, toShares);
        } else {
            emit WithdrawProtected(msg.sender, _owner, _owner, assets, _shares);
            emit Deposit(msg.sender, _owner, assets, toShares);
        }
    }
    function switchCollateralToThisSilo() external virtual {
        Actions.switchCollateralToThisSilo();
        emit CollateralTypeChanged(msg.sender);
    }
    function maxRepay(address _borrower) external view virtual returns (uint256 assets) {
        assets = Views.maxRepay(_borrower);
    }
    function previewRepay(uint256 _assets) external view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), AssetType.Debt);
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.REPAY_TO_SHARES, AssetType.Debt
        );
    }
    function repay(uint256 _assets, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;
        (assets, shares) = Actions.repay({
            _assets: _assets,
            _shares: 0,
            _borrower: _borrower,
            _repayer: msg.sender
        });
        emit Repay(msg.sender, _borrower, assets, shares);
    }
    function maxRepayShares(address _borrower) external view virtual returns (uint256 shares) {
        (address debtShareToken,) = _getSiloConfig().getDebtShareTokenAndAsset(address(this));
        shares = IShareToken(debtShareToken).balanceOf(_borrower);
    }
    function previewRepayShares(uint256 _shares) external view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), AssetType.Debt);
        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.REPAY_TO_ASSETS, AssetType.Debt
        );
    }
    function repayShares(uint256 _shares, address _borrower)
        external
        virtual
        returns (uint256 assets)
    {
        uint256 shares;
        (assets, shares) = Actions.repay({
            _assets: 0,
            _shares: _shares,
            _borrower: _borrower,
            _repayer: msg.sender
        });
        emit Repay(msg.sender, _borrower, assets, shares);
    }
    function maxFlashLoan(address _token) external view virtual returns (uint256 maxLoan) {
        maxLoan = Views.maxFlashLoan(_token);
    }
    function flashFee(address _token, uint256 _amount) external view virtual returns (uint256 fee) {
        fee = Views.flashFee(_token, _amount);
    }
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        virtual
        returns (bool success)
    {
        success = Actions.flashLoan(_receiver, _token, _amount, _data);
        if (success) emit FlashLoan(_amount);
    }
    function accrueInterest() external virtual returns (uint256 accruedInterest) {
        accruedInterest = _accrueInterest();
    }
    function accrueInterestForConfig(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        external
        virtual
    {
        require(msg.sender == address(ShareTokenLib.siloConfig()), OnlySiloConfig());
        _accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
    }
    function withdrawFees() external virtual {
        _accrueInterest();
        (uint256 daoFees, uint256 deployerFees) = Actions.withdrawFees(this);
        emit WithdrawnFeed(daoFees, deployerFees);
    }
    function _totalAssets() internal view virtual returns (uint256 totalManagedAssets) {
        (totalManagedAssets,) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(
            ShareTokenLib.getConfig(),
            AssetType.Collateral
        );
    }
    function _convertToAssets(uint256 _shares, AssetType _assetType) internal view virtual returns (uint256 assets) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), _assetType);
        assets = SiloMathLib.convertToAssets(
            _shares,
            totalSiloAssets,
            totalShares,
            _assetType == AssetType.Debt ? Rounding.BORROW_TO_ASSETS : Rounding.DEPOSIT_TO_ASSETS,
            _assetType
        );
    }
    function _convertToShares(uint256 _assets, AssetType _assetType) internal view virtual returns (uint256 shares) {
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), _assetType);
        shares = SiloMathLib.convertToShares(
            _assets,
            totalSiloAssets,
            totalShares,
            _assetType == AssetType.Debt ? Rounding.BORROW_TO_SHARES : Rounding.DEPOSIT_TO_SHARES,
            _assetType
        );
    }
    function _deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (
            assets, shares
        ) = Actions.deposit(_assets, _shares, _receiver, _collateralType);
        if (_collateralType == CollateralType.Collateral) {
            emit Deposit(msg.sender, _receiver, assets, shares);
        } else {
            emit DepositProtected(msg.sender, _receiver, assets, shares);
        }
    }
    function _withdraw(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        ISilo.CollateralType _collateralType
    )
        internal
        virtual
        returns (uint256 assets, uint256 shares)
    {
        (assets, shares) = Actions.withdraw(
            WithdrawArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                owner: _owner,
                spender: _spender,
                collateralType: _collateralType
            })
        );
        if (_collateralType == CollateralType.Collateral) {
            emit Withdraw(msg.sender, _receiver, _owner, assets, shares);
        } else {
            emit WithdrawProtected(msg.sender, _receiver, _owner, assets, shares);
        }
    }
    function _previewMint(uint256 _shares, CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 assets)
    {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));
        (
            uint256 totalSiloAssets, uint256 totalShares
        ) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(ShareTokenLib.getConfig(), assetType);
        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_ASSETS, assetType
        );
    }
    function _previewDeposit(uint256 _assets, CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 shares)
    {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));
        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(
            ShareTokenLib.getConfig(),
            assetType
        );
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.DEPOSIT_TO_SHARES, assetType
        );
    }
    function _previewRedeem(
        uint256 _shares,
        CollateralType _collateralType
    ) internal view virtual returns (uint256 assets) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));
        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(
            ShareTokenLib.getConfig(),
            assetType
        );
        return SiloMathLib.convertToAssets(
            _shares, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_ASSETS, assetType
        );
    }
    function _previewWithdraw(
        uint256 _assets,
        ISilo.CollateralType _collateralType
    ) internal view virtual returns (uint256 shares) {
        ISilo.AssetType assetType = AssetType(uint256(_collateralType));
        (uint256 totalSiloAssets, uint256 totalShares) = SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(
            ShareTokenLib.getConfig(),
            assetType
        );
        return SiloMathLib.convertToShares(
            _assets, totalSiloAssets, totalShares, Rounding.WITHDRAW_TO_SHARES, assetType
        );
    }
    function _maxWithdraw(address _owner, ISilo.CollateralType _collateralType)
        internal
        view
        virtual
        returns (uint256 assets, uint256 shares)
    {
        return Views.maxWithdraw(_owner, _collateralType);
    }
    function _accrueInterest() internal virtual returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory cfg = ShareTokenLib.getConfig();
        accruedInterest = _accrueInterestForAsset(cfg.interestRateModel, cfg.daoFee, cfg.deployerFee);
    }
    function _accrueInterestForAsset(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal virtual returns (uint256 accruedInterest) {
        accruedInterest = SiloLendingLib.accrueInterestForAsset(_interestRateModel, _daoFee, _deployerFee);
        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/Silo.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/SiloDeployer.sol ---
pragma solidity 0.8.28;
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {CloneDeterministic} from "silo-core/contracts/lib/CloneDeterministic.sol";
import {Views} from "silo-core/contracts/lib/Views.sol";
contract SiloDeployer is ISiloDeployer {
    IInterestRateModelV2Factory public immutable IRM_CONFIG_FACTORY;
    ISiloFactory public immutable SILO_FACTORY;
    address public immutable SILO_IMPL;
    address public immutable SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL;
    address public immutable SHARE_DEBT_TOKEN_IMPL;
    constructor(
        IInterestRateModelV2Factory _irmConfigFactory,
        ISiloFactory _siloFactory,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    ) {
        IRM_CONFIG_FACTORY = _irmConfigFactory;
        SILO_FACTORY = _siloFactory;
        SILO_IMPL = _siloImpl;
        SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL = _shareProtectedCollateralTokenImpl;
        SHARE_DEBT_TOKEN_IMPL = _shareDebtTokenImpl;
    }
    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ClonableHookReceiver calldata _clonableHookReceiver,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        returns (ISiloConfig siloConfig)
    {
        _setUpIRMs(_irmConfigData0, _irmConfigData1, _siloInitData);
        _createOracles(_siloInitData, _oracles);
        _cloneHookReceiver(_siloInitData, _clonableHookReceiver.implementation);
        siloConfig = _deploySiloConfig(_siloInitData);
        SILO_FACTORY.createSilo(
            _siloInitData,
            siloConfig,
            SILO_IMPL,
            SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            SHARE_DEBT_TOKEN_IMPL
        );
        _initializeHookReceiver(_siloInitData, siloConfig, _clonableHookReceiver);
        emit SiloCreated(siloConfig);
    }
    function _deploySiloConfig(ISiloConfig.InitData memory _siloInitData) internal returns (ISiloConfig siloConfig) {
        uint256 nextSiloId = SILO_FACTORY.getNextSiloId();
        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;
        (configData0, configData1) = Views.copySiloConfig(
            _siloInitData,
            SILO_FACTORY.daoFeeRange(),
            SILO_FACTORY.maxDeployerFee(),
            SILO_FACTORY.maxFlashloanFee(),
            SILO_FACTORY.maxLiquidationFee()
        );
        configData0.silo = CloneDeterministic.predictSilo0Addr(SILO_IMPL, nextSiloId, address(SILO_FACTORY));
        configData1.silo = CloneDeterministic.predictSilo1Addr(SILO_IMPL, nextSiloId, address(SILO_FACTORY));
        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;
        configData0.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken0Addr(
            SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            nextSiloId,
            address(SILO_FACTORY)
        );
        configData1.protectedShareToken = CloneDeterministic.predictShareProtectedCollateralToken1Addr(
            SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL,
            nextSiloId,
            address(SILO_FACTORY)
        );
        configData0.debtShareToken = CloneDeterministic.predictShareDebtToken0Addr(
            SHARE_DEBT_TOKEN_IMPL,
            nextSiloId,
            address(SILO_FACTORY)
        );
        configData1.debtShareToken = CloneDeterministic.predictShareDebtToken1Addr(
            SHARE_DEBT_TOKEN_IMPL,
            nextSiloId,
            address(SILO_FACTORY)
        );
        siloConfig = ISiloConfig(address(new SiloConfig(nextSiloId, configData0, configData1)));
    }
    function _setUpIRMs(
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ISiloConfig.InitData memory _siloInitData
    ) internal {
        (, IInterestRateModelV2 interestRateModel0) = IRM_CONFIG_FACTORY.create(_irmConfigData0);
        (, IInterestRateModelV2 interestRateModel1) = IRM_CONFIG_FACTORY.create(_irmConfigData1);
        _siloInitData.interestRateModel0 = address(interestRateModel0);
        _siloInitData.interestRateModel1 = address(interestRateModel1);
    }
    function _createOracles(ISiloConfig.InitData memory _siloInitData, Oracles memory _oracles) internal {
        _siloInitData.solvencyOracle0 = _siloInitData.solvencyOracle0 != address(0)
            ? _siloInitData.solvencyOracle0
            : _createOracle(_oracles.solvencyOracle0);
        _siloInitData.maxLtvOracle0 = _siloInitData.maxLtvOracle0 != address(0)
            ? _siloInitData.maxLtvOracle0
            : _createOracle(_oracles.maxLtvOracle0);
        _siloInitData.solvencyOracle1 = _siloInitData.solvencyOracle1 != address(0)
            ? _siloInitData.solvencyOracle1
            : _createOracle(_oracles.solvencyOracle1);
        _siloInitData.maxLtvOracle1 = _siloInitData.maxLtvOracle1 != address(0)
            ? _siloInitData.maxLtvOracle1
            : _createOracle(_oracles.maxLtvOracle1);
    }
    function _createOracle(OracleCreationTxData memory _txData) internal returns (address _oracle) {
        if (_txData.deployed != address(0)) return _txData.deployed;
        address factory = _txData.factory;
        if (factory == address(0)) return address(0);
        (bool success, bytes memory data) = factory.call(_txData.txInput);
        require(success && data.length == 32, FailedToCreateAnOracle(factory));
        _oracle = address(uint160(uint256(bytes32(data))));
    }
    function _cloneHookReceiver(
        ISiloConfig.InitData memory _siloInitData,
        address _hookReceiverImplementation
    ) internal {
        require(
            _hookReceiverImplementation == address(0) || _siloInitData.hookReceiver == address(0),
            HookReceiverMisconfigured()
        );
        if (_hookReceiverImplementation != address(0)) {
            _siloInitData.hookReceiver = Clones.clone(_hookReceiverImplementation);
        }
    }
    function _initializeHookReceiver(
        ISiloConfig.InitData memory _siloInitData,
        ISiloConfig _siloConfig,
        ClonableHookReceiver calldata _clonableHookReceiver
    ) internal {
        if (_clonableHookReceiver.implementation != address(0)) {
            IHookReceiver(_siloInitData.hookReceiver).initialize(
                _siloConfig,
                _clonableHookReceiver.initializationData
            );
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/SiloDeployer.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/SiloLens.sol ---
pragma solidity 0.8.28;
import {ISiloLens, ISilo} from "./interfaces/ISiloLens.sol";
import {IShareToken} from "./interfaces/IShareToken.sol";
import {SiloLensLib} from "./lib/SiloLensLib.sol";
import {SiloStdLib} from "./lib/SiloStdLib.sol";
contract SiloLens is ISiloLens {
    function getRawLiquidity(ISilo _silo) external view virtual returns (uint256 liquidity) {
        return SiloLensLib.getRawLiquidity(_silo);
    }
    function getInterestRateModel(ISilo _silo) external view virtual returns (address irm) {
        return SiloLensLib.getInterestRateModel(_silo);
    }
    function getBorrowAPR(ISilo _silo) external view virtual returns (uint256 borrowAPR) {
        return SiloLensLib.getBorrowAPR(_silo);
    }
    function getDepositAPR(ISilo _silo) external view virtual returns (uint256 depositAPR) {
        return SiloLensLib.getDepositAPR(_silo);
    }
    function getMaxLtv(ISilo _silo) external view virtual returns (uint256 maxLtv) {
        return SiloLensLib.getMaxLtv(_silo);
    }
    function getLt(ISilo _silo) external view virtual returns (uint256 lt) {
        return SiloLensLib.getLt(_silo);
    }
    function getLtv(ISilo _silo, address _borrower) external view virtual returns (uint256 ltv) {
        return SiloLensLib.getLtv(_silo, _borrower);
    }
    function getFeesAndFeeReceivers(ISilo _silo)
        external
        view
        virtual
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee)
    {
        (daoFeeReceiver, deployerFeeReceiver, daoFee, deployerFee,) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);
    }
    function collateralBalanceOfUnderlying(ISilo _silo, address, address _borrower)
        external
        view
        virtual
        returns (uint256 borrowerCollateral)
    {
        return SiloLensLib.collateralBalanceOfUnderlying(_silo, _borrower);
    }
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        external
        view
        virtual
        returns (uint256 borrowerCollateral)
    {
        return SiloLensLib.collateralBalanceOfUnderlying(_silo, _borrower);
    }
    function debtBalanceOfUnderlying(ISilo _silo, address, address _borrower) external view virtual returns (uint256) {
        return _silo.maxRepay(_borrower);
    }
    function debtBalanceOfUnderlying(ISilo _silo, address _borrower)
        public
        view
        virtual
        returns (uint256 borrowerDebt)
    {
        return _silo.maxRepay(_borrower);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/SiloLens.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/SiloFactory.sol ---
pragma solidity 0.8.28;
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC721} from "openzeppelin5/token/ERC721/ERC721.sol";
import {IShareTokenInitializable} from "./interfaces/IShareTokenInitializable.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {Hook} from "./lib/Hook.sol";
import {Views} from "./lib/Views.sol";
import {CloneDeterministic} from "./lib/CloneDeterministic.sol";
contract SiloFactory is ISiloFactory, ERC721, Ownable2Step {
    uint256 public constant MAX_FEE = 0.5e18;
    uint256 public constant MAX_PERCENT = 1e18;
    Range private _daoFeeRange;
    uint256 public maxDeployerFee;
    uint256 public maxFlashloanFee;
    uint256 public maxLiquidationFee;
    address public daoFeeReceiver;
    string public baseURI;
    mapping(uint256 id => address siloConfig) public idToSiloConfig;
    mapping(address silo => bool) public isSilo;
    uint256 internal _siloId;
    constructor(address _daoFeeReceiver)
        ERC721("Silo Finance Fee Receiver", "feeSILO")
        Ownable(msg.sender)
    {
        _siloId = 1;
        baseURI = "https:
        _setDaoFee({_minFee: 0.05e18, _maxFee: 0.5e18});
        _setDaoFeeReceiver(_daoFeeReceiver);
        _setMaxDeployerFee({_newMaxDeployerFee: 0.15e18}); 
        _setMaxFlashloanFee({_newMaxFlashloanFee: 0.15e18}); 
        _setMaxLiquidationFee({_newMaxLiquidationFee: 0.30e18}); 
    }
    function daoFeeRange() external view returns (Range memory) {
        return _daoFeeRange;
    }
    function createSilo( 
        ISiloConfig.InitData memory _initData,
        ISiloConfig _siloConfig,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    )
        external
        virtual
    {
        require(
            _siloImpl != address(0) &&
            _shareProtectedCollateralTokenImpl != address(0) &&
            _shareDebtTokenImpl != address(0) &&
            address(_siloConfig) != address(0),
            ZeroAddress()
        );
        ISiloConfig.ConfigData memory configData0;
        ISiloConfig.ConfigData memory configData1;
        (
            configData0, configData1
        ) = Views.copySiloConfig(_initData, _daoFeeRange, maxDeployerFee, maxFlashloanFee, maxLiquidationFee);
        uint256 nextSiloId = _siloId;
        unchecked { _siloId++; }
        configData0.silo = CloneDeterministic.silo0(_siloImpl, nextSiloId);
        configData1.silo = CloneDeterministic.silo1(_siloImpl, nextSiloId);
        _cloneShareTokens(
            configData0,
            configData1,
            _shareProtectedCollateralTokenImpl,
            _shareDebtTokenImpl,
            nextSiloId
        );
        ISilo(configData0.silo).initialize(_siloConfig);
        ISilo(configData1.silo).initialize(_siloConfig);
        _initializeShareTokens(configData0, configData1);
        ISilo(configData0.silo).updateHooks();
        ISilo(configData1.silo).updateHooks();
        idToSiloConfig[nextSiloId] = address(_siloConfig);
        isSilo[configData0.silo] = true;
        isSilo[configData1.silo] = true;
        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }
        emit NewSilo(
            _siloImpl,
            configData0.token,
            configData1.token,
            configData0.silo,
            configData1.silo,
            address(_siloConfig)
        );
    }
    function burn(uint256 _siloIdToBurn) external virtual {
        _burn(_siloIdToBurn);
    }
    function setDaoFee(uint128 _minFee, uint128 _maxFee) external virtual onlyOwner {
        _setDaoFee(_minFee, _maxFee);
    }
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external virtual onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFee);
    }
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external virtual onlyOwner {
        _setMaxFlashloanFee(_newMaxFlashloanFee);
    }
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external virtual onlyOwner {
        _setMaxLiquidationFee(_newMaxLiquidationFee);
    }
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external virtual onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }
    function setBaseURI(string calldata _newBaseURI) external virtual onlyOwner {
        baseURI = _newBaseURI;
        emit BaseURI(_newBaseURI);
    }
    function getNextSiloId() external view virtual returns (uint256) {
        return _siloId;
    }
    function getFeeReceivers(address _silo) external view virtual returns (address dao, address deployer) {
        uint256 siloID = ISilo(_silo).config().SILO_ID();
        return (daoFeeReceiver, _ownerOf(siloID));
    }
    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view virtual returns (bool) {
        return Views.validateSiloInitData(_initData, _daoFeeRange, maxDeployerFee, maxFlashloanFee, maxLiquidationFee);
    }
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(
            baseURI,
            Strings.toString(block.chainid),
            "/",
            Strings.toHexString(idToSiloConfig[tokenId])
        );
    }
    function _setDaoFee(uint128 _minFee, uint128 _maxFee) internal virtual {
        require(_maxFee <= MAX_FEE, MaxFeeExceeded());
        require(_minFee <= _maxFee, InvalidFeeRange());
        require(_daoFeeRange.min != _minFee || _daoFeeRange.max != _maxFee, SameRange());
        _daoFeeRange.min = _minFee;
        _daoFeeRange.max = _maxFee;
        emit DaoFeeChanged(_minFee, _maxFee);
    }
    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal virtual {
        require(_newMaxDeployerFee <= MAX_FEE, MaxFeeExceeded());
        maxDeployerFee = _newMaxDeployerFee;
        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }
    function _setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal virtual {
        require(_newMaxFlashloanFee <= MAX_FEE, MaxFeeExceeded());
        maxFlashloanFee = _newMaxFlashloanFee;
        emit MaxFlashloanFeeChanged(_newMaxFlashloanFee);
    }
    function _setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal virtual {
        require(_newMaxLiquidationFee <= MAX_FEE, MaxFeeExceeded());
        maxLiquidationFee = _newMaxLiquidationFee;
        emit MaxLiquidationFeeChanged(_newMaxLiquidationFee);
    }
    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal virtual {
        require(_newDaoFeeReceiver != address(0), DaoFeeReceiverZeroAddress());
        daoFeeReceiver = _newDaoFeeReceiver;
        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }
    function _cloneShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _nextSiloId
    ) internal virtual {
        configData0.collateralShareToken = configData0.silo;
        configData1.collateralShareToken = configData1.silo;
        configData0.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken0(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );
        configData1.protectedShareToken = CloneDeterministic.shareProtectedCollateralToken1(
            _shareProtectedCollateralTokenImpl, _nextSiloId
        );
        configData0.debtShareToken = CloneDeterministic.shareDebtToken0(_shareDebtTokenImpl, _nextSiloId);
        configData1.debtShareToken = CloneDeterministic.shareDebtToken1(_shareDebtTokenImpl, _nextSiloId);
    }
    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        uint24 protectedTokenType = uint24(Hook.PROTECTED_TOKEN);
        uint24 debtTokenType = uint24(Hook.DEBT_TOKEN);
        ISilo silo0 = ISilo(configData0.silo);
        address hookReceiver0 = configData0.hookReceiver;
        IShareTokenInitializable(configData0.protectedShareToken).initialize(silo0, hookReceiver0, protectedTokenType);
        IShareTokenInitializable(configData0.debtShareToken).initialize(silo0, hookReceiver0, debtTokenType);
        ISilo silo1 = ISilo(configData1.silo);
        address hookReceiver1 = configData1.hookReceiver;
        IShareTokenInitializable(configData1.protectedShareToken).initialize(silo1, hookReceiver1, protectedTokenType);
        IShareTokenInitializable(configData1.debtShareToken).initialize(silo1, hookReceiver1, debtTokenType);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/SiloFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/SiloRouter.sol ---
pragma solidity 0.8.28;
import {Address} from "openzeppelin5/utils/Address.sol";
contract SiloRouter {
    error EthTransferFailed();
    error InvalidInputLength();
    receive() external payable {
    }
    function multicall(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    ) external payable returns (bytes[] memory results) {
        require(targets.length == data.length && targets.length == values.length, InvalidInputLength());
        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = Address.functionCallWithValue(targets[i], data[i], values[i]);
        }
        if (msg.value != 0 && address(this).balance != 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, EthTransferFailed());
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/SiloRouter.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/CallBeforeQuoteLib.sol ---
pragma solidity ^0.8.28;
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
library CallBeforeQuoteLib {
    function callSolvencyOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.solvencyOracle != address(0)) {
            ISiloOracle(_config.solvencyOracle).beforeQuote(_config.token);
        }
    }
    function callMaxLtvOracleBeforeQuote(ISiloConfig.ConfigData memory _config) internal {
        if (_config.callBeforeQuote && _config.maxLtvOracle != address(0)) {
            ISiloOracle(_config.maxLtvOracle).beforeQuote(_config.token);
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/CallBeforeQuoteLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloStorageLib.sol ---
pragma solidity 0.8.28;
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
library SiloStorageLib {
    bytes32 private constant _STORAGE_LOCATION = 0xd7513ffe3a01a9f6606089d1b67011bca35bec018ac0faa914e1c529408f8300;
    function getSiloStorage() internal pure returns (ISilo.SiloStorage storage $) {
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloStorageLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloLendingLib.sol ---
pragma solidity ^0.8.28;
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Rounding} from "./Rounding.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";
library SiloLendingLib {
    using SafeERC20 for IERC20;
    using Math for uint256;
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    function repay(
        IShareToken _debtShareToken,
        address _debtAsset,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) internal returns (uint256 assets, uint256 shares) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint256 totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
        (uint256 debtSharesBalance, uint256 totalDebtShares) = _debtShareToken.balanceOfAndTotalSupply(_borrower);
        (assets, shares) = SiloMathLib.convertToAssetsOrToShares({
            _assets: _assets,
            _shares: _shares,
            _totalAssets: totalDebtAssets,
            _totalShares: totalDebtShares,
            _roundingToAssets: Rounding.REPAY_TO_ASSETS,
            _roundingToShares: Rounding.REPAY_TO_SHARES,
            _assetType: ISilo.AssetType.Debt
        });
        if (shares > debtSharesBalance) {
            shares = debtSharesBalance;
            (assets, shares) = SiloMathLib.convertToAssetsOrToShares({
                _assets: 0,
                _shares: shares,
                _totalAssets: totalDebtAssets,
                _totalShares: totalDebtShares,
                _roundingToAssets: Rounding.REPAY_TO_ASSETS,
                _roundingToShares: Rounding.REPAY_TO_SHARES,
                _assetType: ISilo.AssetType.Debt
            });
        }
        require(totalDebtAssets >= assets, ISilo.RepayTooHigh());
        unchecked { $.totalAssets[ISilo.AssetType.Debt] = totalDebtAssets - assets; }
        _debtShareToken.burn(_borrower, _repayer, shares);
        IERC20(_debtAsset).safeTransferFrom(_repayer, address(this), assets);
    }
    function accrueInterestForAsset(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        external
        returns (uint256 accruedInterest)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint64 lastTimestamp = $.interestRateTimestamp;
        if (lastTimestamp == block.timestamp) {
            return 0;
        }
        if (lastTimestamp == 0) {
            $.interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }
        uint256 totalFees;
        uint256 totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        uint256 totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
        uint256 rcomp;
        try
            IInterestRateModel(_interestRateModel).getCompoundInterestRateAndUpdate(
                totalCollateralAssets,
                totalDebtAssets,
                lastTimestamp
            )
            returns (uint256 interestRate)
        {
            rcomp = interestRate;
        } catch {
            emit IInterestRateModel.InterestRateModelError();
        }
        (
            $.totalAssets[ISilo.AssetType.Collateral], $.totalAssets[ISilo.AssetType.Debt], totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest(
            totalCollateralAssets,
            totalDebtAssets,
            rcomp,
            _daoFee,
            _deployerFee
        );
        $.interestRateTimestamp = uint64(block.timestamp);
        unchecked { $.daoAndDeployerRevenue += uint192(totalFees); }
    }
    function borrow(
        address _debtShareToken,
        address _token,
        address _spender,
        ISilo.BorrowArgs memory _args
    )
        internal
        returns (uint256 borrowedAssets, uint256 borrowedShares)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint256 totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
        (borrowedAssets, borrowedShares) = SiloMathLib.convertToAssetsOrToShares(
            _args.assets,
            _args.shares,
            totalDebtAssets,
            IShareToken(_debtShareToken).totalSupply(),
            Rounding.BORROW_TO_ASSETS,
            Rounding.BORROW_TO_SHARES,
            ISilo.AssetType.Debt
        );
        uint256 totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        require(
            _token == address(0) || borrowedAssets <= SiloMathLib.liquidity(totalCollateralAssets, totalDebtAssets),
            ISilo.NotEnoughLiquidity()
        );
        $.totalAssets[ISilo.AssetType.Debt] = totalDebtAssets + borrowedAssets;
        IShareToken(_debtShareToken).mint(_args.borrower, _spender, borrowedShares);
        if (_token != address(0)) {
            IERC20(_token).safeTransfer(_args.receiver, borrowedAssets);
        }
    }
    function calculateMaxBorrow( 
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares,
        ISiloConfig _siloConfig
    )
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations({
            _collateralConfig: _collateralConfig,
            _debtConfig: _debtConfig,
            _borrower: _borrower,
            _oracleType: ISilo.OracleType.MaxLtv,
            _accrueInMemory: ISilo.AccrueInterestInMemory.Yes,
            _debtShareBalanceCached: 0 
        });
        (
            uint256 sumOfBorrowerCollateralValue, uint256 borrowerDebtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);
        uint256 maxBorrowValue = SiloMathLib.calculateMaxBorrowValue(
            _collateralConfig.maxLtv,
            sumOfBorrowerCollateralValue,
            borrowerDebtValue
        );
        (assets, shares) = maxBorrowValueToAssetsAndShares({
            _maxBorrowValue: maxBorrowValue,
            _debtAsset: _debtConfig.token,
            _debtOracle: ltvData.debtOracle,
            _totalDebtAssets: _totalDebtAssets,
            _totalDebtShares: _totalDebtShares
        });
        if (assets == 0 || shares == 0) return (0, 0);
        uint256 liquidityWithInterest = getLiquidity(_siloConfig);
        if (assets > liquidityWithInterest) {
            assets = liquidityWithInterest;
            shares = SiloMathLib.convertToShares(
                assets,
                _totalDebtAssets,
                _totalDebtShares,
                Rounding.MAX_BORROW_TO_SHARES,
                ISilo.AssetType.Debt
            );
        }
    }
    function maxBorrow(address _borrower, bool _sameAsset)
        internal
        view
        returns (uint256 maxAssets, uint256 maxShares)
    {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        if (siloConfig.hasDebtInOtherSilo(address(this), _borrower)) return (0, 0);
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        if (_sameAsset) {
            debtConfig = siloConfig.getConfig(address(this));
            collateralConfig = debtConfig;
        } else {
            (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow({_debtSilo: address(this)});
        }
        (uint256 totalDebtAssets, uint256 totalDebtShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(debtConfig, ISilo.AssetType.Debt);
        return calculateMaxBorrow(
            collateralConfig,
            debtConfig,
            _borrower,
            totalDebtAssets,
            totalDebtShares,
            siloConfig
        );
    }
    function getLiquidity(ISiloConfig _siloConfig) internal view returns (uint256 liquidity) {
        ISiloConfig.ConfigData memory config = _siloConfig.getConfig(address(this));
        (liquidity,,) = getLiquidityAndAssetsWithInterest(config.interestRateModel, config.daoFee, config.deployerFee);
    }
    function getLiquidityAndAssetsWithInterest(address _interestRateModel, uint256 _daoFee, uint256 _deployerFee)
        internal
        view
        returns (uint256 liquidity, uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        totalCollateralAssets = SiloStdLib.getTotalCollateralAssetsWithInterest(
            address(this),
            _interestRateModel,
            _daoFee,
            _deployerFee
        );
        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            address(this),
            _interestRateModel
        );
        liquidity = SiloMathLib.liquidity(totalCollateralAssets, totalDebtAssets);
    }
    function maxBorrowValueToAssetsAndShares(
        uint256 _maxBorrowValue,
        address _debtAsset,
        ISiloOracle _debtOracle,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares
    )
        internal
        view
        returns (uint256 assets, uint256 shares)
    {
        if (_maxBorrowValue == 0) {
            return (0, 0);
        }
        uint256 debtTokenSample = _PRECISION_DECIMALS;
        uint256 debtSampleValue = address(_debtOracle) == address(0)
            ? debtTokenSample
            : _debtOracle.quote(debtTokenSample, _debtAsset);
        assets = _maxBorrowValue.mulDiv(debtTokenSample, debtSampleValue, Rounding.MAX_BORROW_TO_ASSETS);
        shares = SiloMathLib.convertToShares(
            assets, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_SHARES, ISilo.AssetType.Debt
        );
        assets = SiloMathLib.convertToAssets(
            shares, _totalDebtAssets, _totalDebtShares, Rounding.MAX_BORROW_TO_ASSETS, ISilo.AssetType.Debt
        );
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloLendingLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/RevertLib.sol ---
pragma solidity >=0.7.6 <=0.9.0;
library RevertLib {
    function revertBytes(bytes memory _errMsg, string memory _customErr) internal pure {
        if (_errMsg.length > 0) {
            assembly { 
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }
        revert(_customErr);
    }
    function revertIfError(bytes4 _errorSelector) internal pure {
        if (_errorSelector == 0) return;
        bytes memory customError = abi.encodeWithSelector(_errorSelector);
        assembly {
            revert(add(32, customError), mload(customError))
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/RevertLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/NonReentrantLib.sol ---
pragma solidity ^0.8.28;
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ICrossReentrancyGuard} from "../interfaces/ICrossReentrancyGuard.sol";
library NonReentrantLib {
    function nonReentrant(ISiloConfig _config) internal view {
        require(!_config.reentrancyGuardEntered(), ICrossReentrancyGuard.CrossReentrantCall());
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/NonReentrantLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloSolvencyLib.sol ---
pragma solidity ^0.8.28;
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Rounding} from "./Rounding.sol";
library SiloSolvencyLib {
    using Math for uint256;
    struct LtvData {
        ISiloOracle collateralOracle;
        ISiloOracle debtOracle;
        uint256 borrowerProtectedAssets;
        uint256 borrowerCollateralAssets;
        uint256 borrowerDebtAssets;
    }
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _INFINITY = type(uint256).max;
    function isSolvent(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        if (_debtConfig.silo == address(0)) return true; 
        uint256 ltv = getLtv(
            _collateralConfig,
            _debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            _accrueInMemory,
            IShareToken(_debtConfig.debtShareToken).balanceOf(_borrower)
        );
        return ltv <= _collateralConfig.lt;
    }
    function isBelowMaxLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.AccrueInterestInMemory _accrueInMemory
    ) internal view returns (bool) {
        uint256 debtShareBalance = IShareToken(_debtConfig.debtShareToken).balanceOf(_borrower);
        if (debtShareBalance == 0) return true;
        uint256 ltv = getLtv(
            _collateralConfig,
            _debtConfig,
            _borrower,
            ISilo.OracleType.MaxLtv,
            _accrueInMemory,
            debtShareBalance
        );
        return ltv <= _collateralConfig.maxLtv;
    }
    function getAssetsDataForLtvCalculations( 
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalanceCached
    ) internal view returns (LtvData memory ltvData) {
        if (_collateralConfig.token != _debtConfig.token) {
            (ltvData.collateralOracle, ltvData.debtOracle) = _oracleType == ISilo.OracleType.MaxLtv
                ? (ISiloOracle(_collateralConfig.maxLtvOracle), ISiloOracle(_debtConfig.maxLtvOracle))
                : (ISiloOracle(_collateralConfig.solvencyOracle), ISiloOracle(_debtConfig.solvencyOracle));
        }
        uint256 totalShares;
        uint256 shares;
        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _collateralConfig.protectedShareToken, _borrower, 0 
        );
        (
            uint256 totalCollateralAssets, uint256 totalProtectedAssets
        ) = ISilo(_collateralConfig.silo).getCollateralAndProtectedTotalsStorage();
        ltvData.borrowerProtectedAssets = SiloMathLib.convertToAssets(
            shares, totalProtectedAssets, totalShares, Rounding.COLLATERAL_TO_ASSETS, ISilo.AssetType.Protected
        );
        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _collateralConfig.collateralShareToken, _borrower, 0 
        );
        totalCollateralAssets = _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
            ? SiloStdLib.getTotalCollateralAssetsWithInterest(
                _collateralConfig.silo,
                _collateralConfig.interestRateModel,
                _collateralConfig.daoFee,
                _collateralConfig.deployerFee
            )
            : totalCollateralAssets;
        ltvData.borrowerCollateralAssets = SiloMathLib.convertToAssets(
            shares, totalCollateralAssets, totalShares, Rounding.COLLATERAL_TO_ASSETS, ISilo.AssetType.Collateral
        );
        (shares, totalShares) = SiloStdLib.getSharesAndTotalSupply(
            _debtConfig.debtShareToken, _borrower, _debtShareBalanceCached
        );
        uint256 totalDebtAssets = _accrueInMemory == ISilo.AccrueInterestInMemory.Yes
            ? SiloStdLib.getTotalDebtAssetsWithInterest(_debtConfig.silo, _debtConfig.interestRateModel)
            : ISilo(_debtConfig.silo).getTotalAssetsStorage(ISilo.AssetType.Debt);
        ltvData.borrowerDebtAssets = SiloMathLib.convertToAssets(
            shares, totalDebtAssets, totalShares, Rounding.DEBT_TO_ASSETS, ISilo.AssetType.Debt
        );
    }
    function getLtv(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        ISilo.OracleType _oracleType,
        ISilo.AccrueInterestInMemory _accrueInMemory,
        uint256 _debtShareBalance
    ) internal view returns (uint256 ltvInDp) {
        if (_debtShareBalance == 0) return 0;
        LtvData memory ltvData = getAssetsDataForLtvCalculations(
            _collateralConfig, _debtConfig, _borrower, _oracleType, _accrueInMemory, _debtShareBalance
        );
        if (ltvData.borrowerDebtAssets == 0) return 0;
        (,, ltvInDp) = calculateLtv(ltvData, _collateralConfig.token, _debtConfig.token);
    }
    function calculateLtv(
        SiloSolvencyLib.LtvData memory _ltvData, address _collateralToken, address _debtAsset)
        internal
        view
        returns (uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvInDp)
    {
        (
            sumOfBorrowerCollateralValue, totalBorrowerDebtValue
        ) = getPositionValues(_ltvData, _collateralToken, _debtAsset);
        if (sumOfBorrowerCollateralValue == 0 && totalBorrowerDebtValue == 0) {
            return (0, 0, 0);
        } else if (sumOfBorrowerCollateralValue == 0) {
            ltvInDp = _INFINITY;
        } else {
            ltvInDp = ltvMath(totalBorrowerDebtValue, sumOfBorrowerCollateralValue);
        }
    }
    function getPositionValues(LtvData memory _ltvData, address _collateralAsset, address _debtAsset)
        internal
        view
        returns (uint256 sumOfCollateralValue, uint256 debtValue)
    {
        uint256 sumOfCollateralAssets;
        sumOfCollateralAssets = _ltvData.borrowerProtectedAssets + _ltvData.borrowerCollateralAssets;
        if (sumOfCollateralAssets != 0) {
            sumOfCollateralValue = address(_ltvData.collateralOracle) != address(0)
                ? _ltvData.collateralOracle.quote(sumOfCollateralAssets, _collateralAsset)
                : sumOfCollateralAssets;
        }
        if (_ltvData.borrowerDebtAssets != 0) {
            debtValue = address(_ltvData.debtOracle) != address(0)
                ? _ltvData.debtOracle.quote(_ltvData.borrowerDebtAssets, _debtAsset)
                : _ltvData.borrowerDebtAssets;
        }
    }
    function ltvMath(uint256 _totalBorrowerDebtValue, uint256 _sumOfBorrowerCollateralValue)
        internal
        pure
        returns (uint256 ltvInDp)
    {
        ltvInDp = _totalBorrowerDebtValue.mulDiv(_PRECISION_DECIMALS, _sumOfBorrowerCollateralValue, Rounding.LTV);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloSolvencyLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/PRBMathSD59x18.sol ---
pragma solidity ^0.8.28;
import {PRBMathCommon} from "./PRBMathCommon.sol";
library PRBMathSD59x18 {
    int256 internal constant _LOG2_E = 1442695040888963407;
    int256 internal constant _HALF_SCALE = 5e17;
    int256 internal constant _MAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728792003956564819967;
    int256 internal constant _SCALE = 1e18;
    function exp(int256 x) internal pure returns (int256 result) {
        if (x < -41446531673892822322) {
            return 0;
        }
        require(x < 88722839111672999628);
        unchecked {
            int256 doubleScaleProduct = x * _LOG2_E;
            result = exp2((doubleScaleProduct + _HALF_SCALE) / _SCALE);
        }
    }
    function exp2(int256 x) internal pure returns (int256 result) {
        if (x < 0) {
            if (x < -59794705707972522261) {
                return 0;
            }
            unchecked { result = 1e36 / exp2(-x); }
            return result;
        } else {
            require(x < 128e18);
            unchecked {
                uint256 x128x128 = (uint256(x) << 128) / uint256(_SCALE);
                result = int256(PRBMathCommon.exp2(x128x128));
            }
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/PRBMathSD59x18.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloMathLib.sol ---
pragma solidity ^0.8.28;
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Rounding} from "../lib/Rounding.sol";
import {ISilo} from "../interfaces/ISilo.sol";
library SiloMathLib {
    using Math for uint256;
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _DECIMALS_OFFSET = 3;
    uint256 internal constant _DECIMALS_OFFSET_POW = 10 ** _DECIMALS_OFFSET;
    function liquidity(uint256 _collateralAssets, uint256 _debtAssets) internal pure returns (uint256 liquidAssets) {
        unchecked {
            liquidAssets = _debtAssets > _collateralAssets ? 0 : _collateralAssets - _debtAssets;
        }
    }
    function getCollateralAmountsWithInterest(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _rcomp,
        uint256 _daoFee,
        uint256 _deployerFee
    )
        internal
        pure
        returns (
            uint256 collateralAssetsWithInterest,
            uint256 debtAssetsWithInterest,
            uint256 daoAndDeployerRevenue,
            uint256 accruedInterest
        )
    {
        (debtAssetsWithInterest, accruedInterest) = getDebtAmountsWithInterest(_debtAssets, _rcomp);
        uint256 fees;
        unchecked { fees = _daoFee + _deployerFee; }
        daoAndDeployerRevenue = mulDivOverflow(accruedInterest, fees, _PRECISION_DECIMALS);
        uint256 collateralInterest = accruedInterest - daoAndDeployerRevenue;
        uint256 cap = type(uint256).max - _collateralAssets;
        if (cap < collateralInterest) {
            collateralInterest = cap;
        }
        unchecked {  collateralAssetsWithInterest = _collateralAssets + collateralInterest; }
    }
    function getDebtAmountsWithInterest(uint256 _totalDebtAssets, uint256 _rcomp)
        internal
        pure
        returns (uint256 debtAssetsWithInterest, uint256 accruedInterest)
    {
        if (_totalDebtAssets == 0 || _rcomp == 0) {
            return (_totalDebtAssets, 0);
        }
        accruedInterest = mulDivOverflow(_totalDebtAssets, _rcomp, _PRECISION_DECIMALS);
        unchecked {
            debtAssetsWithInterest = _totalDebtAssets + accruedInterest;
            if (debtAssetsWithInterest < _totalDebtAssets) {
                debtAssetsWithInterest = _totalDebtAssets;
                accruedInterest = 0;
            }
        }
    }
    function calculateUtilization(uint256 _dp, uint256 _collateralAssets, uint256 _debtAssets)
        internal
        pure
        returns (uint256 utilization)
    {
        if (_collateralAssets == 0 || _debtAssets == 0 || _dp == 0) return 0;
        if (type(uint256).max / _dp > _debtAssets / _collateralAssets) {
            utilization = _debtAssets.mulDiv(_dp, _collateralAssets, Rounding.ACCRUED_INTEREST);
            if (utilization > _dp) utilization = _dp;
        } else {
            utilization = _dp;
        }
    }
    function convertToAssetsOrToShares(
        uint256 _assets,
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _roundingToAssets,
        Math.Rounding _roundingToShares,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_assets == 0) {
            require(_shares != 0, ISilo.InputZeroShares());
            shares = _shares;
            assets = convertToAssets(_shares, _totalAssets, _totalShares, _roundingToAssets, _assetType);
            require(assets != 0, ISilo.ReturnZeroAssets());
        } else if (_shares == 0) {
            shares = convertToShares(_assets, _totalAssets, _totalShares, _roundingToShares, _assetType);
            assets = _assets;
            require(shares != 0, ISilo.ReturnZeroShares());
        } else {
            revert ISilo.InputCanBeAssetsOrShares();
        }
    }
    function convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 shares) {
        (uint256 totalShares, uint256 totalAssets) = _commonConvertTo(_totalAssets, _totalShares, _assetType);
        if (totalShares == 0) return _assets;
        shares = _assets.mulDiv(totalShares, totalAssets, _rounding);
    }
    function convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalShares,
        Math.Rounding _rounding,
        ISilo.AssetType _assetType
    ) internal pure returns (uint256 assets) {
        (uint256 totalShares, uint256 totalAssets) = _commonConvertTo(_totalAssets, _totalShares, _assetType);
        if (totalShares == 0) return _shares;
        assets = _shares.mulDiv(totalAssets, totalShares, _rounding);
    }
    function calculateMaxBorrowValue(
        uint256 _collateralMaxLtv,
        uint256 _sumOfBorrowerCollateralValue,
        uint256 _borrowerDebtValue
    ) internal pure returns (uint256 maxBorrowValue) {
        if (_sumOfBorrowerCollateralValue == 0) {
            return 0;
        }
        uint256 maxDebtValue = _sumOfBorrowerCollateralValue.mulDiv(
            _collateralMaxLtv, _PRECISION_DECIMALS, Rounding.MAX_BORROW_VALUE
        );
        unchecked {
            maxBorrowValue = maxDebtValue > _borrowerDebtValue ? maxDebtValue - _borrowerDebtValue : 0;
        }
    }
    function calculateMaxAssetsToWithdraw(
        uint256 _sumOfCollateralsValue,
        uint256 _debtValue,
        uint256 _lt,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets
    ) internal pure returns (uint256 maxAssets) {
        if (_sumOfCollateralsValue == 0) return 0;
        if (_debtValue == 0) return _sumOfCollateralsValue;
        if (_lt == 0) return 0;
        uint256 minimumCollateralValue = _debtValue.mulDiv(_PRECISION_DECIMALS, _lt, Rounding.LTV);
        if (_sumOfCollateralsValue <= minimumCollateralValue) {
            return 0;
        }
        uint256 spareCollateralValue;
        unchecked { spareCollateralValue = _sumOfCollateralsValue - minimumCollateralValue; }
        maxAssets = (_borrowerProtectedAssets + _borrowerCollateralAssets)
                .mulDiv(spareCollateralValue, _sumOfCollateralsValue, Rounding.MAX_WITHDRAW_TO_ASSETS);
    }
    function maxWithdrawToAssetsAndShares(
        uint256 _maxAssets,
        uint256 _borrowerCollateralAssets,
        uint256 _borrowerProtectedAssets,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets,
        uint256 _assetTypeShareTokenTotalSupply,
        uint256 _liquidity
    ) internal pure returns (uint256 assets, uint256 shares) {
        if (_maxAssets == 0) return (0, 0);
        if (_assetTypeShareTokenTotalSupply == 0) return (0, 0);
        if (_collateralType == ISilo.CollateralType.Collateral) {
            assets = _maxAssets > _borrowerCollateralAssets ? _borrowerCollateralAssets : _maxAssets;
            if (assets > _liquidity) {
                assets = _liquidity;
            }
        } else {
            assets = _maxAssets > _borrowerProtectedAssets ? _borrowerProtectedAssets : _maxAssets;
        }
        shares = SiloMathLib.convertToShares(
            assets,
            _totalAssets,
            _assetTypeShareTokenTotalSupply,
            Rounding.MAX_WITHDRAW_TO_SHARES,
            ISilo.AssetType(uint256(_collateralType))
        );
    }
    function mulDivOverflow(uint256 _a, uint256 _b, uint256 _c)
        internal
        pure
        returns (uint256 mulDivResult)
    {
        if (_a == 0) return (0);
        unchecked {
            mulDivResult = _a * _b;
            if (mulDivResult / _a != _b) return 0;
            mulDivResult /= _c;
        }
    }
    function _commonConvertTo(
        uint256 _totalAssets,
        uint256 _totalShares,
        ISilo.AssetType _assetType
    ) private pure returns (uint256 totalShares, uint256 totalAssets) {
        if (_totalShares == 0) {
            _totalAssets = 0;
        }
            (totalShares, totalAssets) = _assetType == ISilo.AssetType.Debt
                ? (_totalShares, _totalAssets)
                : (_totalShares + _DECIMALS_OFFSET_POW, _totalAssets + 1);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloMathLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloERC4626Lib.sol ---
pragma solidity ^0.8.28;
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {Rounding} from "./Rounding.sol";
import {Hook} from "./Hook.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";
library SiloERC4626Lib {
    using SafeERC20 for IERC20;
    using Math for uint256;
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _VIRTUAL_DEPOSIT_LIMIT = type(uint256).max;
    function deposit(
        address _token,
        address _depositor,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        IShareToken _collateralShareToken,
        ISilo.CollateralType _collateralType
    ) internal returns (uint256 assets, uint256 shares) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint256 totalAssets = $.totalAssets[ISilo.AssetType(uint256(_collateralType))];
        (assets, shares) = SiloMathLib.convertToAssetsOrToShares(
            _assets,
            _shares,
            totalAssets,
            _collateralShareToken.totalSupply(),
            Rounding.DEPOSIT_TO_ASSETS,
            Rounding.DEPOSIT_TO_SHARES,
            ISilo.AssetType(uint256(_collateralType))
        );
        $.totalAssets[ISilo.AssetType(uint256(_collateralType))] = totalAssets + assets;
        _collateralShareToken.mint(_receiver, _depositor, shares);
        if (_token != address(0)) {
            IERC20(_token).safeTransferFrom(_depositor, address(this), assets);
        }
    }
    function withdraw(
        address _asset,
        address _shareToken,
        ISilo.WithdrawArgs memory _args
    ) internal returns (uint256 assets, uint256 shares) {
        uint256 shareTotalSupply = IShareToken(_shareToken).totalSupply();
        require(shareTotalSupply != 0, ISilo.NothingToWithdraw());
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        { 
            uint256 totalAssets = $.totalAssets[ISilo.AssetType(uint256(_args.collateralType))];
            (assets, shares) = SiloMathLib.convertToAssetsOrToShares(
                _args.assets,
                _args.shares,
                totalAssets,
                shareTotalSupply,
                Rounding.WITHDRAW_TO_ASSETS,
                Rounding.WITHDRAW_TO_SHARES,
                ISilo.AssetType(uint256(_args.collateralType))
            );
            uint256 liquidity = _args.collateralType == ISilo.CollateralType.Collateral
                ? SiloMathLib.liquidity($.totalAssets[ISilo.AssetType.Collateral], $.totalAssets[ISilo.AssetType.Debt])
                : $.totalAssets[ISilo.AssetType.Protected];
            require(assets <= liquidity, ISilo.NotEnoughLiquidity());
            $.totalAssets[ISilo.AssetType(uint256(_args.collateralType))] = totalAssets - assets;
        }
        IShareToken(_shareToken).burn(_args.owner, _args.spender, shares);
        if (_asset != address(0)) {
            IERC20(_asset).safeTransfer(_args.receiver, assets);
        }
    }
    function maxWithdraw(
        address _owner,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        (
            ISiloConfig.DepositConfig memory depositConfig,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = ShareTokenLib.siloConfig().getConfigsForWithdraw(address(this), _owner);
        uint256 shareTokenTotalSupply;
        uint256 liquidity;
        if (_collateralType == ISilo.CollateralType.Collateral) {
            shareTokenTotalSupply = IShareToken(depositConfig.collateralShareToken).totalSupply();
            (liquidity, _totalAssets, ) = SiloLendingLib.getLiquidityAndAssetsWithInterest(
                depositConfig.interestRateModel,
                depositConfig.daoFee,
                depositConfig.deployerFee
            );
        } else {
            shareTokenTotalSupply = IShareToken(depositConfig.protectedShareToken).totalSupply();
            liquidity = _totalAssets;
        }
        if (depositConfig.silo != collateralConfig.silo) {
            shares = _collateralType == ISilo.CollateralType.Protected
                ? IShareToken(depositConfig.protectedShareToken).balanceOf(_owner)
                : IShareToken(depositConfig.collateralShareToken).balanceOf(_owner);
            assets = SiloMathLib.convertToAssets(
                shares,
                _totalAssets,
                shareTokenTotalSupply,
                Rounding.MAX_WITHDRAW_TO_ASSETS,
                ISilo.AssetType(uint256(_collateralType))
            );
            if (_collateralType == ISilo.CollateralType.Protected || assets <= liquidity) return (assets, shares);
            assets = liquidity;
            shares = SiloMathLib.convertToShares(
                assets,
                _totalAssets,
                shareTokenTotalSupply,
                Rounding.MAX_WITHDRAW_TO_SHARES,
                ISilo.AssetType.Collateral
            );
            return (assets, shares);
        } else {
            return maxWithdrawWhenDebt(
                collateralConfig, debtConfig, _owner, liquidity, shareTokenTotalSupply, _collateralType, _totalAssets
            );
        }
    }
    function maxWithdrawWhenDebt(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _owner,
        uint256 _liquidity,
        uint256 _shareTokenTotalSupply,
        ISilo.CollateralType _collateralType,
        uint256 _totalAssets
    ) internal view returns (uint256 assets, uint256 shares) {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            _collateralConfig,
            _debtConfig,
            _owner,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            IShareToken(_debtConfig.debtShareToken).balanceOf(_owner)
        );
        {
            (uint256 collateralValue, uint256 debtValue) =
                                SiloSolvencyLib.getPositionValues(ltvData, _collateralConfig.token, _debtConfig.token);
            assets = SiloMathLib.calculateMaxAssetsToWithdraw(
                collateralValue,
                debtValue,
                _collateralConfig.lt,
                ltvData.borrowerProtectedAssets,
                ltvData.borrowerCollateralAssets
            );
        }
        (assets, shares) = SiloMathLib.maxWithdrawToAssetsAndShares(
            assets,
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerProtectedAssets,
            _collateralType,
            _totalAssets,
            _shareTokenTotalSupply,
            _liquidity
        );
        if (assets != 0) {
            assets = SiloMathLib.convertToAssets(
                shares,
                _totalAssets,
                _shareTokenTotalSupply,
                Rounding.MAX_WITHDRAW_TO_ASSETS,
                ISilo.AssetType(uint256(_collateralType))
            );
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloERC4626Lib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/PRBMathCommon.sol ---
pragma solidity ^0.8.28;
library PRBMathCommon {
    uint256 internal constant _SCALE = 1e18;
    function exp2(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            result = 0x80000000000000000000000000000000;
            if (x & 0x80000000000000000000000000000000 > 0) result = (result * 0x16A09E667F3BCC908B2FB1366EA957D3E) >> 128;
            if (x & 0x40000000000000000000000000000000 > 0) result = (result * 0x1306FE0A31B7152DE8D5A46305C85EDED) >> 128;
            if (x & 0x20000000000000000000000000000000 > 0) result = (result * 0x1172B83C7D517ADCDF7C8C50EB14A7920) >> 128;
            if (x & 0x10000000000000000000000000000000 > 0) result = (result * 0x10B5586CF9890F6298B92B71842A98364) >> 128;
            if (x & 0x8000000000000000000000000000000 > 0) result = (result * 0x1059B0D31585743AE7C548EB68CA417FE) >> 128;
            if (x & 0x4000000000000000000000000000000 > 0) result = (result * 0x102C9A3E778060EE6F7CACA4F7A29BDE9) >> 128;
            if (x & 0x2000000000000000000000000000000 > 0) result = (result * 0x10163DA9FB33356D84A66AE336DCDFA40) >> 128;
            if (x & 0x1000000000000000000000000000000 > 0) result = (result * 0x100B1AFA5ABCBED6129AB13EC11DC9544) >> 128;
            if (x & 0x800000000000000000000000000000 > 0) result = (result * 0x10058C86DA1C09EA1FF19D294CF2F679C) >> 128;
            if (x & 0x400000000000000000000000000000 > 0) result = (result * 0x1002C605E2E8CEC506D21BFC89A23A011) >> 128;
            if (x & 0x200000000000000000000000000000 > 0) result = (result * 0x100162F3904051FA128BCA9C55C31E5E0) >> 128;
            if (x & 0x100000000000000000000000000000 > 0) result = (result * 0x1000B175EFFDC76BA38E31671CA939726) >> 128;
            if (x & 0x80000000000000000000000000000 > 0) result = (result * 0x100058BA01FB9F96D6CACD4B180917C3E) >> 128;
            if (x & 0x40000000000000000000000000000 > 0) result = (result * 0x10002C5CC37DA9491D0985C348C68E7B4) >> 128;
            if (x & 0x20000000000000000000000000000 > 0) result = (result * 0x1000162E525EE054754457D5995292027) >> 128;
            if (x & 0x10000000000000000000000000000 > 0) result = (result * 0x10000B17255775C040618BF4A4ADE83FD) >> 128;
            if (x & 0x8000000000000000000000000000 > 0) result = (result * 0x1000058B91B5BC9AE2EED81E9B7D4CFAC) >> 128;
            if (x & 0x4000000000000000000000000000 > 0) result = (result * 0x100002C5C89D5EC6CA4D7C8ACC017B7CA) >> 128;
            if (x & 0x2000000000000000000000000000 > 0) result = (result * 0x10000162E43F4F831060E02D839A9D16D) >> 128;
            if (x & 0x1000000000000000000000000000 > 0) result = (result * 0x100000B1721BCFC99D9F890EA06911763) >> 128;
            if (x & 0x800000000000000000000000000 > 0) result = (result * 0x10000058B90CF1E6D97F9CA14DBCC1629) >> 128;
            if (x & 0x400000000000000000000000000 > 0) result = (result * 0x1000002C5C863B73F016468F6BAC5CA2C) >> 128;
            if (x & 0x200000000000000000000000000 > 0) result = (result * 0x100000162E430E5A18F6119E3C02282A6) >> 128;
            if (x & 0x100000000000000000000000000 > 0) result = (result * 0x1000000B1721835514B86E6D96EFD1BFF) >> 128;
            if (x & 0x80000000000000000000000000 > 0) result = (result * 0x100000058B90C0B48C6BE5DF846C5B2F0) >> 128;
            if (x & 0x40000000000000000000000000 > 0) result = (result * 0x10000002C5C8601CC6B9E94213C72737B) >> 128;
            if (x & 0x20000000000000000000000000 > 0) result = (result * 0x1000000162E42FFF037DF38AA2B219F07) >> 128;
            if (x & 0x10000000000000000000000000 > 0) result = (result * 0x10000000B17217FBA9C739AA5819F44FA) >> 128;
            if (x & 0x8000000000000000000000000 > 0) result = (result * 0x1000000058B90BFCDEE5ACD3C1CEDC824) >> 128;
            if (x & 0x4000000000000000000000000 > 0) result = (result * 0x100000002C5C85FE31F35A6A30DA1BE51) >> 128;
            if (x & 0x2000000000000000000000000 > 0) result = (result * 0x10000000162E42FF0999CE3541B9FFFD0) >> 128;
            if (x & 0x1000000000000000000000000 > 0) result = (result * 0x100000000B17217F80F4EF5AADDA45554) >> 128;
            if (x & 0x800000000000000000000000 > 0) result = (result * 0x10000000058B90BFBF8479BD5A81B51AE) >> 128;
            if (x & 0x400000000000000000000000 > 0) result = (result * 0x1000000002C5C85FDF84BD62AE30A74CD) >> 128;
            if (x & 0x200000000000000000000000 > 0) result = (result * 0x100000000162E42FEFB2FED257559BDAA) >> 128;
            if (x & 0x100000000000000000000000 > 0) result = (result * 0x1000000000B17217F7D5A7716BBA4A9AF) >> 128;
            if (x & 0x80000000000000000000000 > 0) result = (result * 0x100000000058B90BFBE9DDBAC5E109CCF) >> 128;
            if (x & 0x40000000000000000000000 > 0) result = (result * 0x10000000002C5C85FDF4B15DE6F17EB0E) >> 128;
            if (x & 0x20000000000000000000000 > 0) result = (result * 0x1000000000162E42FEFA494F1478FDE05) >> 128;
            if (x & 0x10000000000000000000000 > 0) result = (result * 0x10000000000B17217F7D20CF927C8E94D) >> 128;
            if (x & 0x8000000000000000000000 > 0) result = (result * 0x1000000000058B90BFBE8F71CB4E4B33E) >> 128;
            if (x & 0x4000000000000000000000 > 0) result = (result * 0x100000000002C5C85FDF477B662B26946) >> 128;
            if (x & 0x2000000000000000000000 > 0) result = (result * 0x10000000000162E42FEFA3AE53369388D) >> 128;
            if (x & 0x1000000000000000000000 > 0) result = (result * 0x100000000000B17217F7D1D351A389D41) >> 128;
            if (x & 0x800000000000000000000 > 0) result = (result * 0x10000000000058B90BFBE8E8B2D3D4EDF) >> 128;
            if (x & 0x400000000000000000000 > 0) result = (result * 0x1000000000002C5C85FDF4741BEA6E77F) >> 128;
            if (x & 0x200000000000000000000 > 0) result = (result * 0x100000000000162E42FEFA39FE95583C3) >> 128;
            if (x & 0x100000000000000000000 > 0) result = (result * 0x1000000000000B17217F7D1CFB72B45E3) >> 128;
            if (x & 0x80000000000000000000 > 0) result = (result * 0x100000000000058B90BFBE8E7CC35C3F2) >> 128;
            if (x & 0x40000000000000000000 > 0) result = (result * 0x10000000000002C5C85FDF473E242EA39) >> 128;
            if (x & 0x20000000000000000000 > 0) result = (result * 0x1000000000000162E42FEFA39F02B772C) >> 128;
            if (x & 0x10000000000000000000 > 0) result = (result * 0x10000000000000B17217F7D1CF7D83C1A) >> 128;
            if (x & 0x8000000000000000000 > 0) result = (result * 0x1000000000000058B90BFBE8E7BDCBE2E) >> 128;
            if (x & 0x4000000000000000000 > 0) result = (result * 0x100000000000002C5C85FDF473DEA871F) >> 128;
            if (x & 0x2000000000000000000 > 0) result = (result * 0x10000000000000162E42FEFA39EF44D92) >> 128;
            if (x & 0x1000000000000000000 > 0) result = (result * 0x100000000000000B17217F7D1CF79E949) >> 128;
            if (x & 0x800000000000000000 > 0) result = (result * 0x10000000000000058B90BFBE8E7BCE545) >> 128;
            if (x & 0x400000000000000000 > 0) result = (result * 0x1000000000000002C5C85FDF473DE6ECA) >> 128;
            if (x & 0x200000000000000000 > 0) result = (result * 0x100000000000000162E42FEFA39EF366F) >> 128;
            if (x & 0x100000000000000000 > 0) result = (result * 0x1000000000000000B17217F7D1CF79AFA) >> 128;
            if (x & 0x80000000000000000 > 0) result = (result * 0x100000000000000058B90BFBE8E7BCD6E) >> 128;
            if (x & 0x40000000000000000 > 0) result = (result * 0x10000000000000002C5C85FDF473DE6B3) >> 128;
            if (x & 0x20000000000000000 > 0) result = (result * 0x1000000000000000162E42FEFA39EF359) >> 128;
            if (x & 0x10000000000000000 > 0) result = (result * 0x10000000000000000B17217F7D1CF79AC) >> 128;
            result = result << ((x >> 128) + 1);
            result = PRBMathCommon.mulDiv(result, 1e18, 2**128);
        }
    }
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        uint256 prod0; 
        uint256 prod1; 
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }
        require(denominator > prod1);
        uint256 remainder;
        assembly {
            remainder := mulmod(x, y, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }
        unchecked {
            uint256 lpotdod = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, lpotdod)
                prod0 := div(prod0, lpotdod)
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }
            prod0 |= prod1 * lpotdod;
            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            result = prod0 * inverse;
            return result;
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/PRBMathCommon.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/IsContract.sol ---
pragma solidity ^0.8.24;
library IsContract {
    function isContract(address _account) internal view returns (bool) {
        return _account.code.length > 0;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/IsContract.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/TokenHelper.sol ---
pragma solidity ^0.8.28;
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {IsContract} from "./IsContract.sol";
library TokenHelper {
    uint256 private constant _BYTES32_SIZE = 32;
    error TokenIsNotAContract();
    function assertAndGetDecimals(address _token) internal view returns (uint256) {
        (bool hasMetadata, bytes memory data) =
            _tokenMetadataCall(_token, abi.encodeCall(IERC20Metadata.decimals, ()));
        if (!hasMetadata) {
            return 0;
        }
        return abi.decode(data, (uint8));
    }
    function symbol(address _token) internal view returns (string memory assetSymbol) {
        (bool hasMetadata, bytes memory data) =
            _tokenMetadataCall(_token, abi.encodeCall(IERC20Metadata.symbol, ()));
        if (!hasMetadata || data.length == 0) {
            return "?";
        } else if (data.length == _BYTES32_SIZE) {
            return string(removeZeros(data));
        } else {
            return abi.decode(data, (string));
        }
    }
    function removeZeros(bytes memory _data) internal pure returns (bytes memory result) {
        uint256 n = _data.length;
        for (uint256 i; i < n; i++) {
            if (_data[i] == 0) continue;
            result = abi.encodePacked(result, _data[i]);
        }
    }
    function _tokenMetadataCall(address _token, bytes memory _data) private view returns (bool, bytes memory) {
        require(IsContract.isContract(_token), TokenIsNotAContract());
        (bool success, bytes memory result) = _token.staticcall(_data);
        if (!success) {
            return (false, "");
        }
        return (true, result);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/TokenHelper.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloLensLib.sol ---
pragma solidity ^0.8.28;
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
library SiloLensLib {
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    function getRawLiquidity(ISilo _silo) internal view returns (uint256 liquidity) {
        return SiloMathLib.liquidity(
            _silo.getTotalAssetsStorage(ISilo.AssetType.Collateral),
            _silo.getTotalAssetsStorage(ISilo.AssetType.Debt)
        );
    }
    function getMaxLtv(ISilo _silo) internal view returns (uint256 maxLtv) {
        maxLtv = _silo.config().getConfig(address(_silo)).maxLtv;
    }
    function getLt(ISilo _silo) internal view returns (uint256 lt) {
        lt = _silo.config().getConfig(address(_silo)).lt;
    }
    function getInterestRateModel(ISilo _silo) internal view returns (address irm) {
        irm = _silo.config().getConfig(address(_silo)).interestRateModel;
    }
    function getBorrowAPR(ISilo _silo) internal view returns (uint256 borrowAPR) {
        IInterestRateModel model = IInterestRateModel(_silo.config().getConfig((address(_silo))).interestRateModel);
        borrowAPR = model.getCurrentInterestRate(address(_silo), block.timestamp);
    }
    function getDepositAPR(ISilo _silo) internal view returns (uint256 depositAPR) {
        uint256 collateralAssets = _silo.getCollateralAssets();
        if (collateralAssets == 0) {
            return 0;
        }
        ISiloConfig.ConfigData memory cfg = _silo.config().getConfig((address(_silo)));
        depositAPR = getBorrowAPR(_silo) * _silo.getDebtAssets() / collateralAssets;
        depositAPR = depositAPR * (_PRECISION_DECIMALS - cfg.daoFee - cfg.deployerFee) / _PRECISION_DECIMALS;
    }
    function getLtv(ISilo _silo, address _borrower) internal view returns (uint256 ltv) {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _silo.config().getConfigsForSolvency(_borrower);
        if (debtConfig.silo != address(0)) {
            ltv = SiloSolvencyLib.getLtv(
                collateralConfig,
                debtConfig,
                _borrower,
                ISilo.OracleType.Solvency,
                ISilo.AccrueInterestInMemory.Yes,
                IShareToken(debtConfig.debtShareToken).balanceOf(_borrower)
            );
        }
    }
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        internal
        view
        returns (uint256 borrowerCollateral)
    {
        (
            address protectedShareToken, address collateralShareToken,
        ) = _silo.config().getShareTokens(address(_silo));
        uint256 protectedShareBalance = IShareToken(protectedShareToken).balanceOf(_borrower);
        uint256 collateralShareBalance = IShareToken(collateralShareToken).balanceOf(_borrower);
        if (protectedShareBalance != 0) {
            borrowerCollateral = _silo.previewRedeem(protectedShareBalance, ISilo.CollateralType.Protected);
        }
        if (collateralShareBalance != 0) {
            borrowerCollateral += _silo.previewRedeem(collateralShareBalance, ISilo.CollateralType.Collateral);
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloLensLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/ShareCollateralTokenLib.sol ---
pragma solidity ^0.8.0;
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
library ShareCollateralTokenLib {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;
    function isSolventAfterCollateralTransfer(address _sender) external returns (bool isSolvent) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        ISiloConfig siloConfig = $.siloConfig;
        (
            ISiloConfig.DepositConfig memory deposit,
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = siloConfig.getConfigsForWithdraw(address($.silo), _sender);
        if (collateral.silo != deposit.silo) return true;
        siloConfig.accrueInterestForBothSilos();
        ShareTokenLib.callOracleBeforeQuote(siloConfig, _sender);
        isSolvent = SiloSolvencyLib.isSolvent(collateral, debt, _sender, ISilo.AccrueInterestInMemory.No);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/ShareCollateralTokenLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/Actions.sol ---
pragma solidity ^0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {Hook} from "./Hook.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";
import {NonReentrantLib} from "./NonReentrantLib.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";
import {Views} from "./Views.sol";
library Actions {
    using SafeERC20 for IERC20;
    using Hook for uint256;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    error FeeOverflow();
    error FlashLoanNotPossible();
    function initialize(ISiloConfig _siloConfig) external returns (address hookReceiver) {
        IShareToken.ShareTokenStorage storage _sharedStorage = ShareTokenLib.getShareTokenStorage();
        require(address(_sharedStorage.siloConfig) == address(0), ISilo.SiloInitialized());
        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(this));
        _sharedStorage.siloConfig = _siloConfig;
        return configData.hookReceiver;
    }
    function deposit(
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        ISilo.CollateralType _collateralType
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeDeposit(_collateralType, _assets, _shares, _receiver);
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        (
            address shareToken, address asset
        ) = siloConfig.getCollateralShareTokenAndAsset(address(this), _collateralType);
        (assets, shares) = SiloERC4626Lib.deposit({
            _token: asset,
            _depositor: msg.sender,
            _assets: _assets,
            _shares: _shares,
            _receiver: _receiver,
            _collateralShareToken: IShareToken(shareToken),
            _collateralType: _collateralType
        });
        siloConfig.turnOffReentrancyProtection();
        _hookCallAfterDeposit(_collateralType, _assets, _shares, _receiver, assets, shares);
    }
    function withdraw(ISilo.WithdrawArgs calldata _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeWithdraw(_args);
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        ISiloConfig.DepositConfig memory depositConfig;
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        (depositConfig, collateralConfig, debtConfig) = siloConfig.getConfigsForWithdraw(address(this), _args.owner);
        (assets, shares) = SiloERC4626Lib.withdraw(
            depositConfig.token,
            _args.collateralType == ISilo.CollateralType.Collateral
                ? depositConfig.collateralShareToken
                : depositConfig.protectedShareToken,
            _args
        );
        if (depositConfig.silo == collateralConfig.silo) {
            _checkSolvencyWithoutAccruingInterest(collateralConfig, debtConfig, _args.owner);
        }
        siloConfig.turnOffReentrancyProtection();
        _hookCallAfterWithdraw(_args, assets, shares);
    }
    function borrow(ISilo.BorrowArgs memory _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeBorrow(_args, Hook.BORROW);
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        require(!siloConfig.hasDebtInOtherSilo(address(this), _args.borrower), ISilo.BorrowNotPossible());
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        siloConfig.setOtherSiloAsCollateralSilo(_args.borrower);
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        (collateralConfig, debtConfig) = siloConfig.getConfigsForBorrow({_debtSilo: address(this)});
        (assets, shares) = SiloLendingLib.borrow(
            debtConfig.debtShareToken,
            debtConfig.token,
            msg.sender,
            _args
        );
        _checkLTVWithoutAccruingInterest(collateralConfig, debtConfig, _args.borrower);
        siloConfig.turnOffReentrancyProtection();
        _hookCallAfterBorrow(_args, Hook.BORROW, assets, shares);
    }
    function borrowSameAsset(ISilo.BorrowArgs memory _args)
        external
        returns (uint256 assets, uint256 shares)
    {
        _hookCallBeforeBorrow(_args, Hook.BORROW_SAME_ASSET);
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        require(!siloConfig.hasDebtInOtherSilo(address(this), _args.borrower), ISilo.BorrowNotPossible());
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        siloConfig.setThisSiloAsCollateralSilo(_args.borrower);
        ISiloConfig.ConfigData memory collateralConfig = siloConfig.getConfig(address(this));
        ISiloConfig.ConfigData memory debtConfig = collateralConfig;
        (assets, shares) = SiloLendingLib.borrow({
            _debtShareToken: debtConfig.debtShareToken,
            _token: debtConfig.token,
            _spender: msg.sender,
            _args: _args
        });
        _checkLTVWithoutAccruingInterest(collateralConfig, debtConfig, _args.borrower);
        siloConfig.turnOffReentrancyProtection();
        _hookCallAfterBorrow(_args, Hook.BORROW_SAME_ASSET, assets, shares);
    }
    function repay(
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        if (_shareStorage.hookSetup.hooksBefore.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.REPAY, data);
        }
        ISiloConfig siloConfig = _shareStorage.siloConfig;
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));
        (address debtShareToken, address debtAsset) = siloConfig.getDebtShareTokenAndAsset(address(this));
        (assets, shares) = SiloLendingLib.repay(
            IShareToken(debtShareToken), debtAsset, _assets, _shares, _borrower, _repayer
        );
        siloConfig.turnOffReentrancyProtection();
        if (_shareStorage.hookSetup.hooksAfter.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.REPAY, data);
        }
    }
    function transitionCollateral(ISilo.TransitionCollateralArgs memory _args)
        external
        returns (uint256 assets, uint256 toShares)
    {
        _hookCallBeforeTransitionCollateral(_args);
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForBothSilos();
        (
            ISiloConfig.DepositConfig memory depositConfig,
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = siloConfig.getConfigsForWithdraw(address(this), _args.owner);
        uint256 shares;
        address shareTokenFrom = _args.transitionFrom == ISilo.CollateralType.Collateral
            ? depositConfig.collateralShareToken
            : depositConfig.protectedShareToken;
        (assets, shares) = SiloERC4626Lib.withdraw({
            _asset: address(0), 
            _shareToken: shareTokenFrom,
            _args: ISilo.WithdrawArgs({
                assets: 0,
                shares: _args.shares,
                owner: _args.owner,
                receiver: _args.owner,
                spender: msg.sender,
                collateralType: _args.transitionFrom
            })
        });
        (ISilo.CollateralType depositType, address shareTokenTo) =
            _args.transitionFrom == ISilo.CollateralType.Collateral
                ? (ISilo.CollateralType.Protected, depositConfig.protectedShareToken)
                : (ISilo.CollateralType.Collateral, depositConfig.collateralShareToken);
        (assets, toShares) = SiloERC4626Lib.deposit({
            _token: address(0), 
            _depositor: msg.sender,
            _assets: assets,
            _shares: 0,
            _receiver: _args.owner,
            _collateralShareToken: IShareToken(shareTokenTo),
            _collateralType: depositType
        });
        if (depositConfig.silo == collateralConfig.silo) {
            _checkSolvencyWithoutAccruingInterest(collateralConfig, debtConfig, _args.owner);
        }
        siloConfig.turnOffReentrancyProtection();
        _hookCallAfterTransitionCollateral(_args, toShares, assets);
    }
    function switchCollateralToThisSilo() external {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.SWITCH_COLLATERAL;
        if (_shareStorage.hookSetup.hooksBefore.matchAction(action)) {
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(
                address(this), action, abi.encodePacked(msg.sender)
            );
        }
        ISiloConfig siloConfig = _shareStorage.siloConfig;
        require(siloConfig.borrowerCollateralSilo(msg.sender) != address(this), ISilo.CollateralSiloAlreadySet());
        siloConfig.turnOnReentrancyProtection();
        siloConfig.setThisSiloAsCollateralSilo(msg.sender);
        ISiloConfig.ConfigData memory collateralConfig;
        ISiloConfig.ConfigData memory debtConfig;
        (collateralConfig, debtConfig) = siloConfig.getConfigsForSolvency(msg.sender);
        if (debtConfig.silo != address(0)) {
            siloConfig.accrueInterestForBothSilos();
            _checkSolvencyWithoutAccruingInterest(collateralConfig, debtConfig, msg.sender);
        }
        siloConfig.turnOffReentrancyProtection();
        if (_shareStorage.hookSetup.hooksAfter.matchAction(action)) {
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(
                address(this), action, abi.encodePacked(msg.sender)
            );
        }
    }
    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns (bool success)
    {
        require(_amount != 0, ISilo.ZeroAmount());
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        if (_shareStorage.hookSetup.hooksBefore.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.FLASH_LOAN, data);
        }
        uint256 fee = SiloStdLib.flashFee(_shareStorage.siloConfig, _token, _amount);
        require(fee <= type(uint192).max, FeeOverflow());
        require(_amount <= Views.maxFlashLoan(_token), FlashLoanNotPossible());
        SiloStorageLib.getSiloStorage().daoAndDeployerRevenue += uint192(fee);
        IERC20(_token).safeTransfer(address(_receiver), _amount);
        require(
            _receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) == _FLASHLOAN_CALLBACK,
            ISilo.FlashloanFailed()
        );
        IERC20(_token).safeTransferFrom(address(_receiver), address(this), _amount + fee);
        if (_shareStorage.hookSetup.hooksAfter.matchAction(Hook.FLASH_LOAN)) {
            bytes memory data = abi.encodePacked(_receiver, _token, _amount, fee);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.FLASH_LOAN, data);
        }
        success = true;
    }
    function withdrawFees(ISilo _silo) external returns (uint256 daoRevenue, uint256 deployerRevenue) {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        siloConfig.turnOnReentrancyProtection();
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint256 earnedFees = $.daoAndDeployerRevenue;
        require(earnedFees != 0, ISilo.EarnedZero());
        (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        ) = SiloStdLib.getFeesAndFeeReceiversWithAsset(_silo);
        uint256 availableLiquidity;
        uint256 siloBalance = IERC20(asset).balanceOf(address(this));
        uint256 protectedAssets = $.totalAssets[ISilo.AssetType.Protected];
        unchecked { availableLiquidity = protectedAssets > siloBalance ? 0 : siloBalance - protectedAssets; }
        require(availableLiquidity != 0, ISilo.NoLiquidity());
        if (earnedFees > availableLiquidity) earnedFees = availableLiquidity;
        unchecked { $.daoAndDeployerRevenue -= uint192(earnedFees); }
        if (deployerFeeReceiver == address(0)) {
            IERC20(asset).safeTransfer(daoFeeReceiver, earnedFees);
        } else {
            daoRevenue = earnedFees * daoFee;
            unchecked {
                daoRevenue = daoRevenue / (daoFee + deployerFee);
                deployerRevenue = earnedFees - daoRevenue;
            }
            IERC20(asset).safeTransfer(daoFeeReceiver, daoRevenue);
            IERC20(asset).safeTransfer(deployerFeeReceiver, deployerRevenue);
        }
        siloConfig.turnOffReentrancyProtection();
    }
    function updateHooks() external returns (uint24 hooksBefore, uint24 hooksAfter) {
        ISiloConfig siloConfig = ShareTokenLib.siloConfig();
        NonReentrantLib.nonReentrant(siloConfig);
        ISiloConfig.ConfigData memory cfg = siloConfig.getConfig(address(this));
        if (cfg.hookReceiver == address(0)) return (0, 0);
        (hooksBefore, hooksAfter) = IHookReceiver(cfg.hookReceiver).hookReceiverConfig(address(this));
        IShareToken(cfg.collateralShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.protectedShareToken).synchronizeHooks(hooksBefore, hooksAfter);
        IShareToken(cfg.debtShareToken).synchronizeHooks(hooksBefore, hooksAfter);
    }
    function callOnBehalfOfSilo(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        internal
        returns (bool success, bytes memory result)
    {
        require(
            msg.sender == address(ShareTokenLib.getShareTokenStorage().hookSetup.hookReceiver),
            ISilo.OnlyHookReceiver()
        );
        if (_callType == ISilo.CallType.Delegatecall) {
            (success, result) = _target.delegatecall(_input); 
        } else {
            (success, result) = _target.call{value: _value}(_input); 
        }
    }
    function _checkSolvencyWithoutAccruingInterest(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user
    ) private {
        if (_debtConfig.silo != _collateralConfig.silo) {
            _collateralConfig.callSolvencyOracleBeforeQuote();
            _debtConfig.callSolvencyOracleBeforeQuote();
        }
        bool userIsSolvent = SiloSolvencyLib.isSolvent(
            _collateralConfig, _debtConfig, _user, ISilo.AccrueInterestInMemory.No
        );
        require(userIsSolvent, ISilo.NotSolvent());
    }
    function _checkLTVWithoutAccruingInterest(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower
    ) private {
        if (_collateralConfig.silo != _debtConfig.silo) {
            _collateralConfig.callMaxLtvOracleBeforeQuote();
            _debtConfig.callMaxLtvOracleBeforeQuote();
        }
        bool borrowerIsBelowMaxLtv = SiloSolvencyLib.isBelowMaxLtv(
            _collateralConfig, _debtConfig, _borrower, ISilo.AccrueInterestInMemory.No
        );
        require(borrowerIsBelowMaxLtv, ISilo.AboveMaxLtv());
    }
    function _hookCallBeforeWithdraw(
        ISilo.WithdrawArgs calldata _args
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.withdrawAction(_args.collateralType);
        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;
        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }
    function _hookCallAfterWithdraw(
        ISilo.WithdrawArgs calldata _args,
        uint256 assets,
        uint256 shares
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.withdrawAction(_args.collateralType);
        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;
        bytes memory data =
            abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.owner, _args.spender, assets, shares);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }
    function _hookCallBeforeBorrow(ISilo.BorrowArgs memory _args, uint256 action) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;
        bytes memory data = abi.encodePacked(
            _args.assets,
            _args.shares,
            _args.receiver,
            _args.borrower,
            msg.sender 
        );
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }
    function _hookCallAfterBorrow(
        ISilo.BorrowArgs memory _args,
        uint256 action,
        uint256 assets,
        uint256 shares
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;
        bytes memory data = abi.encodePacked(
            _args.assets,
            _args.shares,
            _args.receiver,
            _args.borrower,
            msg.sender, 
            assets,
            shares
        );
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }
    function _hookCallBeforeTransitionCollateral(ISilo.TransitionCollateralArgs memory _args) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.transitionCollateralAction(_args.transitionFrom);
        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;
        bytes memory data = abi.encodePacked(_args.shares, _args.owner);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }
    function _hookCallAfterTransitionCollateral(
        ISilo.TransitionCollateralArgs memory _args,
        uint256 _shares,
        uint256 _assets
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.transitionCollateralAction(_args.transitionFrom);
        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;
        bytes memory data = abi.encodePacked(_shares, _args.owner, _assets);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }
    function _hookCallBeforeDeposit(
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.depositAction(_collateralType);
        if (!_shareStorage.hookSetup.hooksBefore.matchAction(action)) return;
        bytes memory data = abi.encodePacked(_assets, _shares, _receiver);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), action, data);
    }
    function _hookCallAfterDeposit(
        ISilo.CollateralType _collateralType,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        uint256 _exactAssets,
        uint256 _exactShare
    ) private {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();
        uint256 action = Hook.depositAction(_collateralType);
        if (!_shareStorage.hookSetup.hooksAfter.matchAction(action)) return;
        bytes memory data = abi.encodePacked(_assets, _shares, _receiver, _exactAssets, _exactShare);
        IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), action, data);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/Actions.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/ShareTokenLib.sol ---
pragma solidity ^0.8.0;
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {TokenHelper} from "../lib/TokenHelper.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";
import {Hook} from "../lib/Hook.sol";
library ShareTokenLib {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;
    bytes32 private constant _STORAGE_LOCATION = 0x01b0b3f9d6e360167e522fa2b18ba597ad7b2b35841fec7e1ca4dbb0adea1200;
    function getShareTokenStorage() internal pure returns (IShareToken.ShareTokenStorage storage $) {
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
    function __ShareToken_init(ISilo _silo, address _hookReceiver, uint24 _tokenType) external {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        $.silo = _silo;
        $.siloConfig = _silo.config();
        $.hookSetup.hookReceiver = _hookReceiver;
        $.hookSetup.tokenType = _tokenType;
        $.transferWithChecks = true;
    }
    function decimals() external view returns (uint8) {
        IShareToken.ShareTokenStorage storage $ = getShareTokenStorage();
        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        return uint8(TokenHelper.assertAndGetDecimals(configData.token));
    }
    function name() external view returns (string memory) {
        IShareToken.ShareTokenStorage storage $ = getShareTokenStorage();
        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        string memory siloIdAscii = Strings.toString($.siloConfig.SILO_ID());
        string memory pre = "";
        string memory post = " Deposit";
        if (address(this) == configData.protectedShareToken) {
            pre = "Non-borrowable ";
        } else if (address(this) == configData.collateralShareToken) {
            pre = "Borrowable ";
        } else if (address(this) == configData.debtShareToken) {
            post = " Debt";
        }
        string memory tokenSymbol = TokenHelper.symbol(configData.token);
        return string.concat("Silo Finance ", pre, tokenSymbol, post, ", SiloId: ", siloIdAscii);
    }
    function symbol() external view returns (string memory) {
        IShareToken.ShareTokenStorage storage $ = getShareTokenStorage();
        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        string memory siloIdAscii = Strings.toString($.siloConfig.SILO_ID());
        string memory pre;
        if (address(this) == configData.protectedShareToken) {
            pre = "nb";
        } else if (address(this) == configData.collateralShareToken) {
            pre = "b";
        } else if (address(this) == configData.debtShareToken) {
            pre = "d";
        }
        string memory tokenSymbol = TokenHelper.symbol(configData.token);
        return string.concat(pre, tokenSymbol, "-", siloIdAscii);
    }
    function callOracleBeforeQuote(ISiloConfig _siloConfig, address _user) internal {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _siloConfig.getConfigsForSolvency(_user);
        collateralConfig.callSolvencyOracleBeforeQuote();
        debtConfig.callSolvencyOracleBeforeQuote();
    }
    function callOnBehalfOfShareToken(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        internal
        returns (bool success, bytes memory result)
    {
        if (_callType == ISilo.CallType.Delegatecall) {
            (success, result) = _target.delegatecall(_input); 
        } else {
            (success, result) = _target.call{value: _value}(_input); 
        }
    }
    function isTransfer(address _sender, address _recipient) internal pure returns (bool) {
        return _sender != address(0) && _recipient != address(0);
    }
    function siloConfig() internal view returns (ISiloConfig thisSiloConfig) {
        return ShareTokenLib.getShareTokenStorage().siloConfig;
    }
    function getConfig() internal view returns (ISiloConfig.ConfigData memory thisSiloConfigData) {
        thisSiloConfigData = ShareTokenLib.getShareTokenStorage().siloConfig.getConfig(address(this));
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/ShareTokenLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloStdLib.sol ---
pragma solidity ^0.8.28;
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
library SiloStdLib {
    using SafeERC20 for IERC20;
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    function flashFee(ISiloConfig _config, address _token, uint256 _amount) internal view returns (uint256 fee) {
        if (_amount == 0) return 0;
        (,, uint256 flashloanFee, address asset) = _config.getFeesWithAsset(address(this));
        require(_token == asset, ISilo.UnsupportedFlashloanToken());
        if (flashloanFee == 0) return 0;
        require(type(uint256).max / _amount >= flashloanFee, ISilo.FlashloanAmountTooBig());
        fee = _amount * flashloanFee / _PRECISION_DECIMALS;
        if (fee == 0) return 1;
    }
    function getTotalAssetsAndTotalSharesWithInterest(
        ISiloConfig.ConfigData memory _configData,
        ISilo.AssetType _assetType
    )
        internal
        view
        returns (uint256 totalAssets, uint256 totalShares)
    {
        if (_assetType == ISilo.AssetType.Protected) {
            totalAssets = ISilo(_configData.silo).getTotalAssetsStorage(ISilo.AssetType.Protected);
            totalShares = IShareToken(_configData.protectedShareToken).totalSupply();
        } else if (_assetType == ISilo.AssetType.Collateral) {
            totalAssets = getTotalCollateralAssetsWithInterest(
                _configData.silo,
                _configData.interestRateModel,
                _configData.daoFee,
                _configData.deployerFee
            );
            totalShares = IShareToken(_configData.collateralShareToken).totalSupply();
        } else { 
            totalAssets = getTotalDebtAssetsWithInterest(_configData.silo, _configData.interestRateModel);
            totalShares = IShareToken(_configData.debtShareToken).totalSupply();
        }
    }
    function getFeesAndFeeReceiversWithAsset(ISilo _silo)
        internal
        view
        returns (
            address daoFeeReceiver,
            address deployerFeeReceiver,
            uint256 daoFee,
            uint256 deployerFee,
            address asset
        )
    {
        (daoFee, deployerFee,, asset) = _silo.config().getFeesWithAsset(address(_silo));
        (daoFeeReceiver, deployerFeeReceiver) = _silo.factory().getFeeReceivers(address(_silo));
    }
    function getTotalCollateralAssetsWithInterest(
        address _silo,
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) internal view returns (uint256 totalCollateralAssetsWithInterest) {
        uint256 rcomp;
        try IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp) returns (uint256 r) {
            rcomp = r;
        } catch {
        }
        (uint256 collateralAssets, uint256 debtAssets) = ISilo(_silo).getCollateralAndDebtTotalsStorage();
        (totalCollateralAssetsWithInterest,,,) = SiloMathLib.getCollateralAmountsWithInterest(
            collateralAssets, debtAssets, rcomp, _daoFee, _deployerFee
        );
    }
    function getSharesAndTotalSupply(address _shareToken, address _owner, uint256 _balanceCached)
        internal
        view
        returns (uint256 shares, uint256 totalSupply)
    {
        if (_balanceCached == 0) {
            (shares, totalSupply) = IShareToken(_shareToken).balanceOfAndTotalSupply(_owner);
        } else {
            shares = _balanceCached;
            totalSupply = IShareToken(_shareToken).totalSupply();
        }
    }
    function getTotalDebtAssetsWithInterest(address _silo, address _interestRateModel)
        internal
        view
        returns (uint256 totalDebtAssetsWithInterest)
    {
        uint256 rcomp;
        try IInterestRateModel(_interestRateModel).getCompoundInterestRate(_silo, block.timestamp) returns (uint256 r) {
            rcomp = r;
        } catch {
        }
        (
            totalDebtAssetsWithInterest,
        ) = SiloMathLib.getDebtAmountsWithInterest(ISilo(_silo).getTotalAssetsStorage(ISilo.AssetType.Debt), rcomp);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/SiloStdLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/ERC20RStorageLib.sol ---
pragma solidity ^0.8.0;
import {IERC20R} from "../interfaces/IERC20R.sol";
library ERC20RStorageLib {
    bytes32 private constant _STORAGE_LOCATION = 0x5a499b742bad5e18c139447ced974d19a977bcf86e03691ee458d10efcd04d00;
    function getIERC20RStorage() internal pure returns (IERC20R.Storage storage $) {
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/ERC20RStorageLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/Hook.sol ---
pragma solidity ^0.8.28;
import {ISilo} from "../interfaces/ISilo.sol";
library Hook {
    struct BeforeDepositInput {
        uint256 assets;
        uint256 shares;
        address receiver;
    }
    struct AfterDepositInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        uint256 receivedAssets;
        uint256 mintedShares;
    }
    struct BeforeWithdrawInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
    }
    struct AfterWithdrawInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        uint256 withdrawnAssets;
        uint256 withdrawnShares;
    }
    struct AfterTokenTransfer {
        address sender;
        address recipient;
        uint256 amount;
        uint256 senderBalance;
        uint256 recipientBalance;
        uint256 totalSupply;
    }
    struct BeforeBorrowInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address borrower;
        address spender;
    }
    struct AfterBorrowInput {
        uint256 assets;
        uint256 shares;
        address receiver;
        address borrower;
        address spender;
        uint256 borrowedAssets;
        uint256 borrowedShares;
    }
    struct BeforeRepayInput {
        uint256 assets;
        uint256 shares;
        address borrower;
        address repayer;
    }
    struct AfterRepayInput {
        uint256 assets;
        uint256 shares;
        address borrower;
        address repayer;
        uint256 repaidAssets;
        uint256 repaidShares;
    }
    struct BeforeFlashLoanInput {
        address receiver;
        address token;
        uint256 amount;
    }
    struct AfterFlashLoanInput {
        address receiver;
        address token;
        uint256 amount;
        uint256 fee;
    }
    struct BeforeTransitionCollateralInput {
        uint256 shares;
        address owner;
    }
    struct AfterTransitionCollateralInput {
        uint256 shares;
        address owner;
        uint256 assets;
    }
    struct SwitchCollateralInput {
        address user;
    }
    uint256 internal constant NONE = 0;
    uint256 internal constant DEPOSIT = 2 ** 1;
    uint256 internal constant BORROW = 2 ** 2;
    uint256 internal constant BORROW_SAME_ASSET = 2 ** 3;
    uint256 internal constant REPAY = 2 ** 4;
    uint256 internal constant WITHDRAW = 2 ** 5;
    uint256 internal constant FLASH_LOAN = 2 ** 6;
    uint256 internal constant TRANSITION_COLLATERAL = 2 ** 7;
    uint256 internal constant SWITCH_COLLATERAL = 2 ** 8;
    uint256 internal constant LIQUIDATION = 2 ** 9;
    uint256 internal constant SHARE_TOKEN_TRANSFER = 2 ** 10;
    uint256 internal constant COLLATERAL_TOKEN = 2 ** 11;
    uint256 internal constant PROTECTED_TOKEN = 2 ** 12;
    uint256 internal constant DEBT_TOKEN = 2 ** 13;
    uint256 private constant PACKED_ADDRESS_LENGTH = 20;
    uint256 private constant PACKED_FULL_LENGTH = 32;
    uint256 private constant PACKED_ENUM_LENGTH = 1;
    uint256 private constant PACKED_BOOL_LENGTH = 1;
    error FailedToParseBoolean();
    function matchAction(uint256 _action, uint256 _expectedHook) internal pure returns (bool) {
        return _action & _expectedHook == _expectedHook;
    }
    function addAction(uint256 _action, uint256 _newAction) internal pure returns (uint256) {
        return _action | _newAction;
    }
    function removeAction(uint256 _action, uint256 _actionToRemove) internal pure returns (uint256) {
        return _action & (~_actionToRemove);
    }
    function depositAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return DEPOSIT | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }
    function withdrawAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return WITHDRAW | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }
    function transitionCollateralAction(ISilo.CollateralType _type) internal pure returns (uint256) {
        return TRANSITION_COLLATERAL | (_type == ISilo.CollateralType.Collateral ? COLLATERAL_TOKEN : PROTECTED_TOKEN);
    }
    function shareTokenTransfer(uint256 _tokenType) internal pure returns (uint256) {
        return SHARE_TOKEN_TRANSFER | _tokenType;
    }
    function afterTokenTransferDecode(bytes memory packed)
        internal
        pure
        returns (AfterTokenTransfer memory input)
    {
        address sender;
        address recipient;
        uint256 amount;
        uint256 senderBalance;
        uint256 recipientBalance;
        uint256 totalSupply;
        assembly { 
            let pointer := PACKED_ADDRESS_LENGTH
            sender := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            recipient := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            amount := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            senderBalance := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            recipientBalance := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            totalSupply := mload(add(packed, pointer))
        }
        input = AfterTokenTransfer(sender, recipient, amount, senderBalance, recipientBalance, totalSupply);
    }
    function beforeDepositDecode(bytes memory packed)
        internal
        pure
        returns (BeforeDepositInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
        }
        input = BeforeDepositInput(assets, shares, receiver);
    }
    function afterDepositDecode(bytes memory packed)
        internal
        pure
        returns (AfterDepositInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        uint256 receivedAssets;
        uint256 mintedShares;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            receivedAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            mintedShares := mload(add(packed, pointer))
        }
        input = AfterDepositInput(assets, shares, receiver, receivedAssets, mintedShares);
    }
    function beforeWithdrawDecode(bytes memory packed)
        internal
        pure
        returns (BeforeWithdrawInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
        }
        input = BeforeWithdrawInput(assets, shares, receiver, owner, spender);
    }
    function afterWithdrawDecode(bytes memory packed)
        internal
        pure
        returns (AfterWithdrawInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        uint256 withdrawnAssets;
        uint256 withdrawnShares;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            withdrawnAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            withdrawnShares := mload(add(packed, pointer))
        }
        input = AfterWithdrawInput(assets, shares, receiver, owner, spender, withdrawnAssets, withdrawnShares);
    }
    function beforeBorrowDecode(bytes memory packed)
        internal
        pure
        returns (BeforeBorrowInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address borrower;
        address spender;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            borrower := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
        }
        input = BeforeBorrowInput(assets, shares, receiver, borrower, spender);
    }
    function afterBorrowDecode(bytes memory packed)
        internal
        pure
        returns (AfterBorrowInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address receiver;
        address borrower;
        address spender;
        uint256 borrowedAssets;
        uint256 borrowedShares;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            borrower := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            spender := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            borrowedAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            borrowedShares := mload(add(packed, pointer))
        }
        input = AfterBorrowInput(assets, shares, receiver, borrower, spender, borrowedAssets, borrowedShares);
    }
    function beforeRepayDecode(bytes memory packed)
        internal
        pure
        returns (BeforeRepayInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address borrower;
        address repayer;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            borrower := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            repayer := mload(add(packed, pointer))
        }
        input = BeforeRepayInput(assets, shares, borrower, repayer);
    }
    function afterRepayDecode(bytes memory packed)
        internal
        pure
        returns (AfterRepayInput memory input)
    {
        uint256 assets;
        uint256 shares;
        address borrower;
        address repayer;
        uint256 repaidAssets;
        uint256 repaidShares;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            assets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            borrower := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            repayer := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            repaidAssets := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            repaidShares := mload(add(packed, pointer))
        }
        input = AfterRepayInput(assets, shares, borrower, repayer, repaidAssets, repaidShares);
    }
    function beforeFlashLoanDecode(bytes memory packed)
        internal
        pure
        returns (BeforeFlashLoanInput memory input)
    {
        address receiver;
        address token;
        uint256 amount;
        assembly { 
            let pointer := PACKED_ADDRESS_LENGTH
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            token := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            amount := mload(add(packed, pointer))
        }
        input = BeforeFlashLoanInput(receiver, token, amount);
    }
    function afterFlashLoanDecode(bytes memory packed)
        internal
        pure
        returns (AfterFlashLoanInput memory input)
    {
        address receiver;
        address token;
        uint256 amount;
        uint256 fee;
        assembly { 
            let pointer := PACKED_ADDRESS_LENGTH
            receiver := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            token := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            amount := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            fee := mload(add(packed, pointer))
        }
        input = AfterFlashLoanInput(receiver, token, amount, fee);
    }
    function beforeTransitionCollateralDecode(bytes memory packed)
        internal
        pure
        returns (BeforeTransitionCollateralInput memory input)
    {
        uint256 shares;
        address owner;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
        }
        input = BeforeTransitionCollateralInput(shares, owner);
    }
    function afterTransitionCollateralDecode(bytes memory packed)
        internal
        pure
        returns (AfterTransitionCollateralInput memory input)
    {
        uint256 shares;
        address owner;
        uint256 assets;
        assembly { 
            let pointer := PACKED_FULL_LENGTH
            shares := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_ADDRESS_LENGTH)
            owner := mload(add(packed, pointer))
            pointer := add(pointer, PACKED_FULL_LENGTH)
            assets := mload(add(packed, pointer))
        }
        input = AfterTransitionCollateralInput(shares, owner, assets);
    }
    function switchCollateralDecode(bytes memory packed)
        internal
        pure
        returns (SwitchCollateralInput memory input)
    {
        address user;
        assembly { 
            let pointer := PACKED_ADDRESS_LENGTH
            user := mload(add(packed, pointer))
        }
        input = SwitchCollateralInput(user);
    }
    function _toBoolean(uint8 _value) internal pure returns (bool result) {
        if (_value == 0) {
            result = false;
        } else if (_value == 1) {
            result = true;
        } else {
            revert FailedToParseBoolean();
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/Hook.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/CloneDeterministic.sol ---
pragma solidity 0.8.28;
import {Clones} from "openzeppelin5/proxy/Clones.sol";
library CloneDeterministic {
    bytes32 private constant _SILO_0 = keccak256("create2.salt.Silo0");
    bytes32 private constant _SHARE_PROTECTED_COLLATERAL_TOKEN_0 = keccak256(
        "create2.salt.ShareProtectedCollateralToken0"
    );
    bytes32 private constant _SHARE_DEBT_TOKEN_0 = keccak256("create2.salt.ShareDebtToken0");
    bytes32 private constant _SILO_1 = keccak256("create2.salt.Silo1");
    bytes32 private constant _SHARE_PROTECTED_COLLATERAL_TOKEN_1 = keccak256(
        "create2.salt.ShareProtectedCollateralToken1"
    );
    bytes32 private constant _SHARE_DEBT_TOKEN_1 = keccak256("create2.salt.ShareDebtToken1");
    function silo0(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _silo0Salt(_siloId));
    }
    function silo1(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _silo1Salt(_siloId));
    }
    function shareProtectedCollateralToken0(
        address _implementation,
        uint256 _siloId
    )
        internal
        returns (address instance)
    {
        instance = Clones.cloneDeterministic(_implementation, _shareProtectedCollateralToken0Salt(_siloId));
    }
    function shareDebtToken0(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _shareDebtToken0Salt(_siloId));
    }
    function shareProtectedCollateralToken1(
        address _implementation,
        uint256 _siloId
    )
        internal
        returns (address instance)
    {
        instance = Clones.cloneDeterministic(_implementation, _shareProtectedCollateralToken1Salt(_siloId));
    }
    function shareDebtToken1(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _shareDebtToken1Salt(_siloId));
    }
    function predictSilo0Addr(
        address _siloImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(_siloImpl, _silo0Salt(_siloId), _deployer);
    }
    function predictSilo1Addr(
        address _siloImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(_siloImpl, _silo1Salt(_siloId), _deployer);
    }
    function predictShareProtectedCollateralToken0Addr(
        address _shareProtectedCollateralTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareProtectedCollateralTokenImpl, _shareProtectedCollateralToken0Salt(_siloId), _deployer
        );
    }
    function predictShareDebtToken0Addr(
        address _shareDebtTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareDebtTokenImpl, _shareDebtToken0Salt(_siloId), _deployer
        );
    }
    function predictShareProtectedCollateralToken1Addr(
        address _shareProtectedCollateralTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareProtectedCollateralTokenImpl, _shareProtectedCollateralToken1Salt(_siloId), _deployer
        );
    }
    function predictShareDebtToken1Addr(
        address _shareDebtTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareDebtTokenImpl, _shareDebtToken1Salt(_siloId), _deployer
        );
    }
    function _silo0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SILO_0));
    }
    function _silo1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SILO_1));
    }
    function _shareProtectedCollateralToken0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_PROTECTED_COLLATERAL_TOKEN_0));
    }
    function _shareDebtToken0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_DEBT_TOKEN_0));
    }
    function _shareProtectedCollateralToken1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_PROTECTED_COLLATERAL_TOKEN_1));
    }
    function _shareDebtToken1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_DEBT_TOKEN_1));
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/CloneDeterministic.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/Rounding.sol ---
pragma solidity ^0.8.28;
import {Math} from "openzeppelin5/utils/math/Math.sol";
library Rounding {
    Math.Rounding internal constant UP = (Math.Rounding.Ceil);
    Math.Rounding internal constant DOWN = (Math.Rounding.Floor);
    Math.Rounding internal constant DEBT_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant COLLATERAL_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant DEPOSIT_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant DEPOSIT_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant BORROW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_BORROW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_BORROW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_BORROW_VALUE = (Math.Rounding.Floor);
    Math.Rounding internal constant REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant REPAY_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_REPAY_TO_ASSETS = (Math.Rounding.Ceil);
    Math.Rounding internal constant WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant WITHDRAW_TO_SHARES = (Math.Rounding.Ceil);
    Math.Rounding internal constant MAX_WITHDRAW_TO_ASSETS = (Math.Rounding.Floor);
    Math.Rounding internal constant MAX_WITHDRAW_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LIQUIDATE_TO_SHARES = (Math.Rounding.Floor);
    Math.Rounding internal constant LTV = (Math.Rounding.Ceil);
    Math.Rounding internal constant ACCRUED_INTEREST = (Math.Rounding.Floor);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/Rounding.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/lib/Views.sol ---
pragma solidity ^0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloOracle} from "../interfaces/ISiloOracle.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {SiloERC4626Lib} from "./SiloERC4626Lib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";
import {SiloLendingLib} from "./SiloLendingLib.sol";
import {SiloStdLib} from "./SiloStdLib.sol";
import {SiloMathLib} from "./SiloMathLib.sol";
import {Rounding} from "./Rounding.sol";
import {ShareTokenLib} from "./ShareTokenLib.sol";
import {SiloStorageLib} from "./SiloStorageLib.sol";
library Views {
    uint256 internal constant _100_PERCENT = 1e18;
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    function isSolvent(address _borrower) external view returns (bool) {
        (
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = ShareTokenLib.siloConfig().getConfigsForSolvency(_borrower);
        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, ISilo.AccrueInterestInMemory.Yes);
    }
    function flashFee(address _token, uint256 _amount) external view returns (uint256 fee) {
        fee = SiloStdLib.flashFee(ShareTokenLib.siloConfig(), _token, _amount);
    }
    function maxFlashLoan(address _token) internal view returns (uint256 maxLoan) {
        if (_token != ShareTokenLib.siloConfig().getAssetForSilo(address(this))) return 0;
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        uint256 protectedAssets = $.totalAssets[ISilo.AssetType.Protected];
        uint256 balance = IERC20(_token).balanceOf(address(this));
        unchecked {
            return balance > protectedAssets ? balance - protectedAssets : 0;
        }
    }
    function maxBorrow(address _borrower, bool _sameAsset)
        external
        view
        returns (uint256 maxAssets, uint256 maxShares)
    {
        return SiloLendingLib.maxBorrow(_borrower, _sameAsset);
    }
    function maxWithdraw(address _owner, ISilo.CollateralType _collateralType)
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        return SiloERC4626Lib.maxWithdraw(
            _owner,
            _collateralType,
            _collateralType == ISilo.CollateralType.Protected
                ? SiloStorageLib.getSiloStorage().totalAssets[ISilo.AssetType.Protected]
                : 0
        );
    }
    function maxRepay(address _borrower) external view returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = ShareTokenLib.getConfig();
        uint256 shares = IShareToken(configData.debtShareToken).balanceOf(_borrower);
        (uint256 totalSiloAssets, uint256 totalShares) =
            SiloStdLib.getTotalAssetsAndTotalSharesWithInterest(configData, ISilo.AssetType.Debt);
        return SiloMathLib.convertToAssets(
            shares, totalSiloAssets, totalShares, Rounding.MAX_REPAY_TO_ASSETS, ISilo.AssetType.Debt
        );
    }
    function getSiloStorage()
        internal
        view
        returns (
            uint192 daoAndDeployerRevenue,
            uint64 interestRateTimestamp,
            uint256 protectedAssets,
            uint256 collateralAssets,
            uint256 debtAssets
        )
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        daoAndDeployerRevenue = $.daoAndDeployerRevenue;
        interestRateTimestamp = $.interestRateTimestamp;
        protectedAssets = $.totalAssets[ISilo.AssetType.Protected];
        collateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        debtAssets = $.totalAssets[ISilo.AssetType.Debt];
    }
    function utilizationData() internal view returns (ISilo.UtilizationData memory) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        return ISilo.UtilizationData({
            collateralAssets: $.totalAssets[ISilo.AssetType.Collateral],
            debtAssets: $.totalAssets[ISilo.AssetType.Debt],
            interestRateTimestamp: $.interestRateTimestamp
        });
    }
    function getDebtAssets() internal view returns (uint256 totalDebtAssets) {
        ISiloConfig.ConfigData memory thisSiloConfig = ShareTokenLib.getConfig();
        totalDebtAssets = SiloStdLib.getTotalDebtAssetsWithInterest(
            thisSiloConfig.silo, thisSiloConfig.interestRateModel
        );
    }
    function getCollateralAndProtectedAssets()
        internal
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        totalProtectedAssets = $.totalAssets[ISilo.AssetType.Protected];
    }
    function getCollateralAndDebtAssets()
        internal
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets)
    {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();
        totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];
    }
    function copySiloConfig(
        ISiloConfig.InitData memory _initData,
        ISiloFactory.Range memory _daoFeeRange,
        uint256 _maxDeployerFee,
        uint256 _maxFlashloanFee,
        uint256 _maxLiquidationFee
    )
        internal
        view
        returns (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1)
    {
        validateSiloInitData(_initData, _daoFeeRange, _maxDeployerFee, _maxFlashloanFee, _maxLiquidationFee);
        configData0.hookReceiver = _initData.hookReceiver;
        configData0.token = _initData.token0;
        configData0.solvencyOracle = _initData.solvencyOracle0;
        configData0.maxLtvOracle = _initData.maxLtvOracle0 == address(0)
            ? _initData.solvencyOracle0
            : _initData.maxLtvOracle0;
        configData0.interestRateModel = _initData.interestRateModel0;
        configData0.maxLtv = _initData.maxLtv0;
        configData0.lt = _initData.lt0;
        configData0.liquidationTargetLtv = _initData.liquidationTargetLtv0;
        configData0.deployerFee = _initData.deployerFee;
        configData0.daoFee = _initData.daoFee;
        configData0.liquidationFee = _initData.liquidationFee0;
        configData0.flashloanFee = _initData.flashloanFee0;
        configData0.callBeforeQuote = _initData.callBeforeQuote0;
        configData1.hookReceiver = _initData.hookReceiver;
        configData1.token = _initData.token1;
        configData1.solvencyOracle = _initData.solvencyOracle1;
        configData1.maxLtvOracle = _initData.maxLtvOracle1 == address(0)
            ? _initData.solvencyOracle1
            : _initData.maxLtvOracle1;
        configData1.interestRateModel = _initData.interestRateModel1;
        configData1.maxLtv = _initData.maxLtv1;
        configData1.lt = _initData.lt1;
        configData1.liquidationTargetLtv = _initData.liquidationTargetLtv1;
        configData1.deployerFee = _initData.deployerFee;
        configData1.daoFee = _initData.daoFee;
        configData1.liquidationFee = _initData.liquidationFee1;
        configData1.flashloanFee = _initData.flashloanFee1;
        configData1.callBeforeQuote = _initData.callBeforeQuote1;
    }
    function validateSiloInitData(
        ISiloConfig.InitData memory _initData,
        ISiloFactory.Range memory _daoFeeRange,
        uint256 _maxDeployerFee,
        uint256 _maxFlashloanFee,
        uint256 _maxLiquidationFee
    ) internal view returns (bool) {
        require(_initData.hookReceiver != address(0), ISiloFactory.MissingHookReceiver());
        require(_initData.token0 != address(0), ISiloFactory.EmptyToken0());
        require(_initData.token1 != address(0), ISiloFactory.EmptyToken1());
        require(_initData.token0 != _initData.token1, ISiloFactory.SameAsset());
        require(_initData.maxLtv0 != 0 || _initData.maxLtv1 != 0, ISiloFactory.InvalidMaxLtv());
        require(_initData.maxLtv0 <= _initData.lt0, ISiloFactory.InvalidMaxLtv());
        require(_initData.maxLtv1 <= _initData.lt1, ISiloFactory.InvalidMaxLtv());
        require(_initData.liquidationFee0 <= _maxLiquidationFee, ISiloFactory.MaxLiquidationFeeExceeded());
        require(_initData.liquidationFee1 <= _maxLiquidationFee, ISiloFactory.MaxLiquidationFeeExceeded());
        require(_initData.lt0 + _initData.liquidationFee0 <= _100_PERCENT, ISiloFactory.InvalidLt());
        require(_initData.lt1 + _initData.liquidationFee1 <= _100_PERCENT, ISiloFactory.InvalidLt());
        require(
            _initData.maxLtvOracle0 == address(0) || _initData.solvencyOracle0 != address(0),
            ISiloFactory.OracleMisconfiguration()
        );
        require(
            !_initData.callBeforeQuote0 || _initData.solvencyOracle0 != address(0),
            ISiloFactory.InvalidCallBeforeQuote()
        );
        require(
            _initData.maxLtvOracle1 == address(0) || _initData.solvencyOracle1 != address(0),
            ISiloFactory.OracleMisconfiguration()
        );
        require(
            !_initData.callBeforeQuote1 || _initData.solvencyOracle1 != address(0),
            ISiloFactory.InvalidCallBeforeQuote()
        );
        verifyQuoteTokens(_initData);
        require(_initData.deployerFee == 0 || _initData.deployer != address(0), ISiloFactory.InvalidDeployer());
        require(_initData.deployerFee <= _maxDeployerFee, ISiloFactory.MaxDeployerFeeExceeded());
        require(_daoFeeRange.min <= _initData.daoFee, ISiloFactory.DaoMinRangeExceeded());
        require(_initData.daoFee <= _daoFeeRange.max, ISiloFactory.DaoMaxRangeExceeded());
        require(_initData.flashloanFee0 <= _maxFlashloanFee, ISiloFactory.MaxFlashloanFeeExceeded());
        require(_initData.flashloanFee1 <= _maxFlashloanFee, ISiloFactory.MaxFlashloanFeeExceeded());
        require(_initData.liquidationTargetLtv0 <= _initData.lt0, ISiloFactory.LiquidationTargetLtvTooHigh());
        require(_initData.liquidationTargetLtv1 <= _initData.lt1, ISiloFactory.LiquidationTargetLtvTooHigh());
        require(
            _initData.interestRateModel0 != address(0) && _initData.interestRateModel1 != address(0),
            ISiloFactory.InvalidIrm()
        );
        return true;
    }
    function verifyQuoteTokens(ISiloConfig.InitData memory _initData) internal view {
        address expectedQuoteToken;
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle0);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle0);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.solvencyOracle1);
        expectedQuoteToken = verifyQuoteToken(expectedQuoteToken, _initData.maxLtvOracle1);
    }
    function verifyQuoteToken(address _expectedQuoteToken, address _oracle)
        internal
        view
        returns (address quoteToken)
    {
        if (_oracle == address(0)) return _expectedQuoteToken;
        quoteToken = ISiloOracle(_oracle).quoteToken();
        if (_expectedQuoteToken == address(0)) return quoteToken;
        require(_expectedQuoteToken == quoteToken, ISiloFactory.InvalidQuoteToken());
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/lib/Views.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol ---
pragma solidity 0.8.28;
import {SiloIncentivesControllerGaugeLike} from "./SiloIncentivesControllerGaugeLike.sol";
import {ISiloIncentivesControllerGaugeLikeFactory} from "./interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol";
contract SiloIncentivesControllerGaugeLikeFactory is ISiloIncentivesControllerGaugeLikeFactory {
    mapping(address => bool) public createdInFactory;
    function createGaugeLike(
        address _owner,
        address _notifier,
        address _shareToken
    ) external returns (address gaugeLike) {
        gaugeLike = address(new SiloIncentivesControllerGaugeLike(_owner, _notifier, _shareToken));
        createdInFactory[gaugeLike] = true;
        emit GaugeLikeCreated(gaugeLike);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerGaugeLikeFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol ---
pragma solidity 0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IGaugeLike as IGauge} from "../interfaces/IGaugeLike.sol";
import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";
contract SiloIncentivesControllerGaugeLike is SiloIncentivesController, IGauge {
    address public immutable SHARE_TOKEN;
    bool internal _isKilled;
    constructor(
        address _owner,
        address _notifier,
        address _siloShareToken
    ) SiloIncentivesController(_owner, _notifier) {
        require(_siloShareToken != address(0), EmptyShareToken());
        SHARE_TOKEN = _siloShareToken;
    }
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    )
        public
        virtual
        override(SiloIncentivesController, IGauge)
        onlyNotifier
    {
        SiloIncentivesController.afterTokenTransfer(
            _sender, _senderBalance, _recipient, _recipientBalance, _totalSupply, _amount
        );
    }
    function killGauge() external virtual onlyOwner {
        _isKilled = true;
        emit GaugeKilled();
    }
    function unkillGauge() external virtual onlyOwner {
        _isKilled = false;
        emit GaugeUnKilled();
    }
    function share_token() external view returns (address) {
        return SHARE_TOKEN;
    }
    function is_killed() external view returns (bool) {
        return _isKilled;
    }
    function _shareToken() internal view override returns (IERC20 shareToken) {
        shareToken = IERC20(SHARE_TOKEN);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerGaugeLike.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerFactory.sol ---
pragma solidity 0.8.28;
import {SiloIncentivesController} from "./SiloIncentivesController.sol";
import {ISiloIncentivesControllerFactory} from "./interfaces/ISiloIncentivesControllerFactory.sol";
contract SiloIncentivesControllerFactory is ISiloIncentivesControllerFactory {
    mapping(address => bool) public isSiloIncentivesController;
    function create(address _owner, address _notifier) external returns (address controller) {
        controller = address(new SiloIncentivesController(_owner, _notifier));
        isSiloIncentivesController[controller] = true;
        emit SiloIncentivesControllerCreated(controller);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesControllerFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesController.sol ---
pragma solidity 0.8.28;
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloIncentivesController} from "./interfaces/ISiloIncentivesController.sol";
import {BaseIncentivesController} from "./base/BaseIncentivesController.sol";
import {DistributionTypes} from "./lib/DistributionTypes.sol";
contract SiloIncentivesController is BaseIncentivesController {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;
    constructor(address _owner, address _notifier) BaseIncentivesController(_owner, _notifier) {}
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) public virtual onlyNotifier {
        uint256 numberOfPrograms = _incentivesProgramIds.length();
        if (_sender == _recipient || numberOfPrograms == 0) {
            return;
        }
        if (_sender == address(0)) {
            unchecked { _totalSupply -= _amount; }
        } else if (_recipient == address(0)) {
            unchecked { _totalSupply += _amount; }
        }
        if (_sender != address(0)) {
            unchecked { _senderBalance = _senderBalance + _amount; }
        }
        if (_recipient != address(0)) {
            unchecked { _recipientBalance = _recipientBalance - _amount; }
        }
        for (uint256 i = 0; i < numberOfPrograms; i++) {
            bytes32 programId = _incentivesProgramIds.at(i);
            if (_sender != address(0)) {
                _handleAction(programId, _sender, _totalSupply, _senderBalance);
            }
            if (_recipient != address(0)) {
                _handleAction(programId, _recipient, _totalSupply, _recipientBalance);
            }
        }
    }
    function immediateDistribution(address _tokenToDistribute, uint104 _amount) external virtual onlyNotifierOrOwner {
        if (_amount == 0) return;
        uint256 totalStaked = _shareToken().totalSupply();
        bytes32 programId = _getOrCreateImmediateDistributionProgram(_tokenToDistribute);
        IncentivesProgram storage program = incentivesPrograms[programId];
        _updateAssetStateInternal(programId, totalStaked);
        uint40 distributionEndBefore = program.distributionEnd;
        uint104 emissionPerSecondBefore = program.emissionPerSecond;
        program.distributionEnd = uint40(block.timestamp);  
        program.lastUpdateTimestamp = uint40(block.timestamp - 1);
        program.emissionPerSecond = _amount;
        _updateAssetStateInternal(programId, totalStaked);
        program.distributionEnd = distributionEndBefore;
        program.lastUpdateTimestamp = uint40(block.timestamp);
        program.emissionPerSecond = emissionPerSecondBefore;
    }
    function rescueRewards(address _rewardToken) external onlyOwner {
        IERC20(_rewardToken).safeTransfer(msg.sender, IERC20(_rewardToken).balanceOf(address(this)));
    }
    function _getOrCreateImmediateDistributionProgram(address _tokenToDistribute)
        internal
        virtual
        returns (bytes32 programId)
    {
        string memory programName = Strings.toHexString(_tokenToDistribute);
        programId = getProgramId(programName);
        if (incentivesPrograms[programId].lastUpdateTimestamp == 0) {
            DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput;
            _incentivesProgramInput.name = programName;
            _incentivesProgramInput.rewardToken = _tokenToDistribute;
            _incentivesProgramInput.emissionPerSecond = 0;
            _incentivesProgramInput.distributionEnd = 0;
            _createIncentiveProgram(_incentivesProgramInput);
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/SiloIncentivesController.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/lib/DistributionTypes.sol ---
pragma solidity 0.8.28;
library DistributionTypes {
    struct IncentivesProgramCreationInput {
        string name;
        address rewardToken;
        uint104 emissionPerSecond;
        uint40 distributionEnd;
    }
    struct AssetConfigInput {
        uint104 emissionPerSecond;
        uint256 totalStaked;
        address underlyingAsset;
    }
    struct UserStakeInput {
        address underlyingAsset;
        uint256 stakedByUser;
        uint256 totalStaked;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/lib/DistributionTypes.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/base/DistributionManager.sol ---
pragma solidity 0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
import {IDistributionManager} from "../interfaces/IDistributionManager.sol";
import {DistributionTypes} from "../lib/DistributionTypes.sol";
import {TokenHelper} from "../../lib/TokenHelper.sol";
contract DistributionManager is IDistributionManager, Ownable2Step {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    EnumerableSet.Bytes32Set internal _incentivesProgramIds;
    mapping(bytes32 => IncentivesProgram) public incentivesPrograms;
    address public immutable NOTIFIER; 
    uint8 public constant PRECISION = 18;
    uint256 public constant TEN_POW_PRECISION = 10 ** PRECISION;
    modifier onlyNotifier() {
        if (msg.sender != NOTIFIER) revert OnlyNotifier();
        _;
    }
    modifier onlyNotifierOrOwner() {
        if (msg.sender != NOTIFIER && msg.sender != owner()) revert OnlyNotifierOrOwner();
        _;
    }
    constructor(address _owner, address _notifier) Ownable(_owner) {
        NOTIFIER = _notifier;
    }
    function setDistributionEnd(
        string calldata _incentivesProgram,
        uint40 _distributionEnd
    ) external virtual onlyOwner {
        require(_distributionEnd >= block.timestamp, ISiloIncentivesController.InvalidDistributionEnd());
        bytes32 programId = getProgramId(_incentivesProgram);
        require(_incentivesProgramIds.contains(programId), ISiloIncentivesController.IncentivesProgramNotFound());
        uint256 totalSupply = _shareToken().totalSupply();
        _updateAssetStateInternal(programId, totalSupply);
        incentivesPrograms[programId].distributionEnd = _distributionEnd;
        emit DistributionEndUpdated(_incentivesProgram, _distributionEnd);
    }
    function getDistributionEnd(string calldata _incentivesProgram) external view virtual override returns (uint256) {
        bytes32 incentivesProgramId = getProgramId(_incentivesProgram);
        return incentivesPrograms[incentivesProgramId].distributionEnd;
    }
    function getUserData(address _user, string calldata _incentivesProgram)
        public
        view
        virtual
        override
        returns (uint256)
    {
        bytes32 incentivesProgramId = getProgramId(_incentivesProgram);
        return incentivesPrograms[incentivesProgramId].users[_user];
    }
    function incentivesProgram(string calldata _incentivesProgram)
        external
        view
        virtual
        returns (IncentiveProgramDetails memory details)
    {
        bytes32 incentivesProgramId = getProgramId(_incentivesProgram);
        details = IncentiveProgramDetails(
            incentivesPrograms[incentivesProgramId].index,
            incentivesPrograms[incentivesProgramId].rewardToken,
            incentivesPrograms[incentivesProgramId].emissionPerSecond,
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp,
            incentivesPrograms[incentivesProgramId].distributionEnd
        );
    }
    function getAllProgramsNames() external view virtual returns (string[] memory programsNames) {
        uint256 length = _incentivesProgramIds.values().length;
        programsNames = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            programsNames[i] = getProgramName(_incentivesProgramIds.values()[i]);
        }
    }
    function getProgramId(string memory _programName) public pure virtual returns (bytes32) {
        require(bytes(_programName).length != 0, InvalidIncentivesProgramName());
        return bytes32(abi.encodePacked(_programName));
    }
    function getProgramName(bytes32 _programId) public pure virtual returns (string memory) {
        return string(TokenHelper.removeZeros(abi.encodePacked(_programId)));
    }
    function _updateAssetStateInternal(
        bytes32 incentivesProgramId,
        uint256 totalStaked
    ) internal virtual returns (uint256) {
        uint256 oldIndex = incentivesPrograms[incentivesProgramId].index;
        uint256 emissionPerSecond = incentivesPrograms[incentivesProgramId].emissionPerSecond;
        uint256 lastUpdateTimestamp = incentivesPrograms[incentivesProgramId].lastUpdateTimestamp;
        uint256 distributionEnd = incentivesPrograms[incentivesProgramId].distributionEnd;
        if (block.timestamp == lastUpdateTimestamp) {
            return oldIndex;
        }
        uint256 newIndex = _getIncentivesProgramIndex(
            oldIndex, emissionPerSecond, lastUpdateTimestamp, distributionEnd, totalStaked
        );
        if (newIndex != oldIndex) {
            incentivesPrograms[incentivesProgramId].index = newIndex;
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp = uint40(block.timestamp);
            emit IncentivesProgramIndexUpdated(getProgramName(incentivesProgramId), newIndex);
        } else {
            incentivesPrograms[incentivesProgramId].lastUpdateTimestamp = uint40(block.timestamp);
        }
        return newIndex;
    }
    function _updateUserAssetInternal(
        bytes32 incentivesProgramId,
        address user,
        uint256 stakedByUser,
        uint256 totalStaked
    ) internal virtual returns (uint256) {
        uint256 userIndex = incentivesPrograms[incentivesProgramId].users[user];
        uint256 accruedRewards = 0;
        uint256 newIndex = _updateAssetStateInternal(incentivesProgramId, totalStaked);
        if (userIndex != newIndex) {
            if (stakedByUser != 0) {
                accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
            }
            incentivesPrograms[incentivesProgramId].users[user] = newIndex;
            emit UserIndexUpdated(user, getProgramName(incentivesProgramId), newIndex);
        }
        return accruedRewards;
    }
    function _accrueRewards(address _user)
        internal
        virtual
        returns (AccruedRewards[] memory accruedRewards)
    {
        accruedRewards = _accrueRewardsForPrograms(_user, _incentivesProgramIds.values());
    }
    function _accrueRewardsForPrograms(address _user, bytes32[] memory _programIds)
        internal
        virtual
        returns (AccruedRewards[] memory accruedRewards)
    {
        uint256 length = _programIds.length;
        accruedRewards = new AccruedRewards[](length);
        (uint256 userStaked, uint256 totalStaked) = _getScaledUserBalanceAndSupply(_user);
        for (uint256 i = 0; i < length; i++) {
            accruedRewards[i] = _accrueRewards(_user, _programIds[i], totalStaked, userStaked);
        }
    }
    function _accrueRewards(address _user, bytes32 _programId, uint256 _totalStaked, uint256 _userStaked)
        internal
        virtual
        returns (AccruedRewards memory accruedRewards)
    {
        uint256 rewards = _updateUserAssetInternal(
            _programId,
            _user,
            _userStaked,
            _totalStaked
        );
        accruedRewards = AccruedRewards({
            amount: rewards,
            programId: _programId,
            rewardToken: incentivesPrograms[_programId].rewardToken
        });
    }
    function _getUnclaimedRewards(bytes32 programId, address user, uint256 stakedByUser, uint256 totalStaked)
        internal
        view
        virtual
        returns (uint256 accruedRewards)
    {
        uint256 userIndex = incentivesPrograms[programId].users[user];
        uint256 incentivesProgramIndex = _getIncentivesProgramIndex(
            incentivesPrograms[programId].index,
            incentivesPrograms[programId].emissionPerSecond,
            incentivesPrograms[programId].lastUpdateTimestamp,
            incentivesPrograms[programId].distributionEnd,
            totalStaked
        );
        accruedRewards = _getRewards(stakedByUser, incentivesProgramIndex, userIndex);
    }
    function _getRewards(
        uint256 principalUserBalance,
        uint256 reserveIndex,
        uint256 userIndex
    ) internal pure virtual returns (uint256 rewards) {
        rewards = principalUserBalance * (reserveIndex - userIndex);
        unchecked { rewards /= TEN_POW_PRECISION; }
    }
    function _getIncentivesProgramIndex(
        uint256 currentIndex,
        uint256 emissionPerSecond,
        uint256 lastUpdateTimestamp,
        uint256 distributionEnd,
        uint256 totalBalance
    ) internal view virtual returns (uint256 newIndex) {
        if (
            emissionPerSecond == 0 ||
            totalBalance == 0 ||
            lastUpdateTimestamp == block.timestamp ||
            lastUpdateTimestamp >= distributionEnd
        ) {
            return currentIndex;
        }
        uint256 currentTimestamp = block.timestamp > distributionEnd ? distributionEnd : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        newIndex = emissionPerSecond * timeDelta * TEN_POW_PRECISION;
        unchecked { newIndex /= totalBalance; }
        newIndex += currentIndex;
    }
    function _shareToken() internal view virtual returns (IERC20 shareToken) {
        shareToken = IERC20(NOTIFIER);
    }
    function _getScaledUserBalanceAndSupply(address _user)
        internal
        view
        virtual
        returns (uint256 userBalance, uint256 totalSupply)
    {
        userBalance = _shareToken().balanceOf(_user);
        totalSupply = _shareToken().totalSupply();
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/base/DistributionManager.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/base/BaseIncentivesController.sol ---
pragma solidity 0.8.28;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";
import {DistributionTypes} from "../lib/DistributionTypes.sol";
import {DistributionManager} from "./DistributionManager.sol";
import {ISiloIncentivesController} from "../interfaces/ISiloIncentivesController.sol";
abstract contract BaseIncentivesController is DistributionManager, ISiloIncentivesController {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    mapping(address user => mapping(bytes32 programId => uint256 unclaimedRewards)) internal _usersUnclaimedRewards;
    mapping(address user => address claimer) internal _authorizedClaimers;
    modifier onlyAuthorizedClaimers(address claimer, address user) {
        if (_authorizedClaimers[user] != claimer) revert ClaimerUnauthorized();
        _;
    }
    modifier inputsValidation(address _user, address _to) {
        if (_user == address(0)) revert InvalidUserAddress();
        if (_to == address(0)) revert InvalidToAddress();
        _;
    }
    constructor(address _owner, address _notifier) DistributionManager(_owner, _notifier) {}
    function createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput)
        external
        virtual
        onlyOwner
    {
        require(bytes(_incentivesProgramInput.name).length <= 32, TooLongProgramName());
        require(_incentivesProgramInput.distributionEnd >= block.timestamp, InvalidDistributionEnd());
        _createIncentiveProgram(_incentivesProgramInput);
    }
    function updateIncentivesProgram(
        string calldata _incentivesProgram,
        uint40 _distributionEnd,
        uint104 _emissionPerSecond
    ) external virtual onlyOwner {
        require(_distributionEnd >= block.timestamp, InvalidDistributionEnd());
        bytes32 programId = getProgramId(_incentivesProgram);
        require(_incentivesProgramIds.contains(programId), IncentivesProgramNotFound());
        uint256 totalSupply = _shareToken().totalSupply();
        _updateAssetStateInternal(programId, totalSupply);
        incentivesPrograms[programId].distributionEnd = _distributionEnd;
        incentivesPrograms[programId].emissionPerSecond = _emissionPerSecond;
        emit IncentivesProgramUpdated(_incentivesProgram);
    }
    function getRewardsBalance(address _user, string calldata _programName)
        external
        view
        virtual
        returns (uint256 unclaimedRewards)
    {
        bytes32 programId = getProgramId(_programName);
        (uint256 stakedByUser, uint256 totalStaked) = _getScaledUserBalanceAndSupply(_user);
        unclaimedRewards = _getRewardsBalance(_user, programId, stakedByUser, totalStaked);
    }
    function getRewardsBalance(address _user, string[] calldata _programNames)
        external
        view
        virtual
        returns (uint256 unclaimedRewards)
    {
        address rewardsToken;
        (uint256 stakedByUser, uint256 totalStaked) = _getScaledUserBalanceAndSupply(_user);
        for (uint256 i = 0; i < _programNames.length; i++) {
            bytes32 programId = getProgramId(_programNames[i]);
            address programRewardsToken = incentivesPrograms[programId].rewardToken;
            if (rewardsToken == address(0)) {
                rewardsToken = programRewardsToken;
            } else if (rewardsToken != programRewardsToken) {
                revert DifferentRewardsTokens();
            }
            unclaimedRewards += _getRewardsBalance(_user, programId, stakedByUser, totalStaked);
        }
    }
    function _getRewardsBalance(address _user, bytes32 _programId, uint256 _stakedByUser, uint256 _totalStaked)
        internal
        view
        virtual
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards = _usersUnclaimedRewards[_user][_programId];
        unclaimedRewards += _getUnclaimedRewards(_programId, _user, _stakedByUser, _totalStaked);
    }
    function claimRewards(address _to) external virtual returns (AccruedRewards[] memory accruedRewards) {
        if (_to == address(0)) revert InvalidToAddress();
        accruedRewards = _accrueRewards(msg.sender);
        _claimRewards(msg.sender, msg.sender, _to, accruedRewards);
    }
    function claimRewards(address _to, string[] calldata _programNames)
        external
        virtual
        returns (AccruedRewards[] memory accruedRewards)
    {
        if (_to == address(0)) revert InvalidToAddress();
        bytes32[] memory programIds = _getProgramsIds(_programNames);
        accruedRewards = _accrueRewardsForPrograms(msg.sender, programIds);
        _claimRewards(msg.sender, msg.sender, _to, accruedRewards);
    }
    function claimRewardsOnBehalf(address _user, address _to, string[] calldata _programNames)
        external
        virtual
        onlyAuthorizedClaimers(msg.sender, _user)
        inputsValidation(_user, _to)
        returns (AccruedRewards[] memory accruedRewards)
    {
        bytes32[] memory programIds = _getProgramsIds(_programNames);
        accruedRewards = _accrueRewardsForPrograms(_user, programIds);
        _claimRewards(msg.sender, _user, _to, accruedRewards);
    }
    function setClaimer(address _user, address _caller) external virtual onlyOwner {
        _authorizedClaimers[_user] = _caller;
        emit ClaimerSet(_user, _caller);
    }
    function getClaimer(address _user) external view virtual returns (address) {
        return _authorizedClaimers[_user];
    }
    function getUserUnclaimedRewards(address _user, string calldata _programName)
        external
        view
        virtual
        returns (uint256)
    {
        bytes32 programId = getProgramId(_programName);
        return _usersUnclaimedRewards[_user][programId];
    }
    function _handleAction(
        bytes32 _incentivesProgramId,
        address _user,
        uint256 _totalSupply,
        uint256 _userBalance
    ) internal virtual {
        uint256 accruedRewards = _updateUserAssetInternal(_incentivesProgramId, _user, _userBalance, _totalSupply);
        if (accruedRewards != 0) {
            uint256 newUnclaimedRewards = _usersUnclaimedRewards[_user][_incentivesProgramId] + accruedRewards;
            _usersUnclaimedRewards[_user][_incentivesProgramId] = newUnclaimedRewards;
            emit RewardsAccrued(
                _user,
                incentivesPrograms[_incentivesProgramId].rewardToken,
                getProgramName(_incentivesProgramId),
                newUnclaimedRewards
            );
        }
    }
    function _claimRewards(
        address claimer,
        address user,
        address to,
        AccruedRewards[] memory accruedRewards
    ) internal virtual {
        for (uint256 i = 0; i < accruedRewards.length; i++) {
            uint256 unclaimedRewards = _usersUnclaimedRewards[user][accruedRewards[i].programId];
            uint256 amountToClaim = accruedRewards[i].amount + unclaimedRewards;
            if (amountToClaim != 0) {
                if (accruedRewards[i].amount != 0) {
                    emit RewardsAccrued(
                        user,
                        accruedRewards[i].rewardToken,
                        getProgramName(accruedRewards[i].programId),
                        accruedRewards[i].amount
                    );
                }
                _usersUnclaimedRewards[user][accruedRewards[i].programId] = 0;
                _transferRewards(accruedRewards[i].rewardToken, to, amountToClaim);
                emit RewardsClaimed(
                    user,
                    to,
                    accruedRewards[i].rewardToken,
                    accruedRewards[i].programId,
                    claimer,
                    amountToClaim
                );
                accruedRewards[i].amount = amountToClaim;
            }
        }
    }
    function _createIncentiveProgram(
        DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput
    ) internal virtual {
        bytes32 programId = getProgramId(_incentivesProgramInput.name);
        require(_incentivesProgramInput.rewardToken != address(0), InvalidRewardToken());
        require(_incentivesProgramIds.add(programId), IncentivesProgramAlreadyExists());
        incentivesPrograms[programId].rewardToken = _incentivesProgramInput.rewardToken;
        incentivesPrograms[programId].distributionEnd = _incentivesProgramInput.distributionEnd;
        incentivesPrograms[programId].emissionPerSecond = _incentivesProgramInput.emissionPerSecond;
        incentivesPrograms[programId].lastUpdateTimestamp = uint40(block.timestamp);
        emit IncentivesProgramCreated(_incentivesProgramInput.name);
    }
    function _getProgramsIds(string[] calldata _programNames)
        internal
        pure
        virtual
        returns (bytes32[] memory programIds)
    {
        programIds = new bytes32[](_programNames.length);
        for (uint256 i = 0; i < _programNames.length; i++) {
            programIds[i] = getProgramId(_programNames[i]);
        }
    }
    function _transferRewards(address rewardToken, address to, uint256 amount) internal virtual {
        IERC20(rewardToken).transfer(to, amount);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/base/BaseIncentivesController.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol ---
pragma solidity 0.8.28;
interface ISiloIncentivesControllerGaugeLikeFactory {
    event GaugeLikeCreated(address gaugeLike);
    function createGaugeLike(address _owner, address _notifier, address _shareToken) external returns (address);
    function createdInFactory(address _gaugeLike) external view returns (bool);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerGaugeLikeFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerFactory.sol ---
pragma solidity 0.8.28;
interface ISiloIncentivesControllerFactory {
    event SiloIncentivesControllerCreated(address indexed controller);
    function create(address _owner, address _notifier) external returns (address);
    function isSiloIncentivesController(address _controller) external view returns (bool);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol ---
pragma solidity 0.8.28;
import {IDistributionManager} from "./IDistributionManager.sol";
import {DistributionTypes} from "../lib/DistributionTypes.sol";
interface ISiloIncentivesController is IDistributionManager {
    event ClaimerSet(address indexed user, address indexed claimer);
    event IncentivesProgramCreated(string name);
    event IncentivesProgramUpdated(string name);
    event RewardsAccrued(
        address indexed user,
        address indexed rewardToken,
        string indexed programName,
        uint256 amount
    );
    event RewardsClaimed(
        address indexed user,
        address indexed to,
        address indexed rewardToken,
        bytes32 programId,
        address claimer,
        uint256 amount
    );
    error InvalidDistributionEnd();
    error InvalidConfiguration();
    error IndexOverflowAtEmissionsPerSecond();
    error InvalidToAddress();
    error InvalidUserAddress();
    error ClaimerUnauthorized();
    error InvalidRewardToken();
    error IncentivesProgramAlreadyExists();
    error IncentivesProgramNotFound();
    error DifferentRewardsTokens();
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;
    function immediateDistribution(address _tokenToDistribute, uint104 _amount) external;
    function rescueRewards(address _rewardToken) external;
    function setClaimer(address _user, address _claimer) external;
    function createIncentivesProgram(DistributionTypes.IncentivesProgramCreationInput memory _incentivesProgramInput)
        external;
    function updateIncentivesProgram(
        string calldata _incentivesProgram,
        uint40 _distributionEnd,
        uint104 _emissionPerSecond
    ) external;
    function claimRewards(address _to) external returns (AccruedRewards[] memory accruedRewards);
    function claimRewards(address _to, string[] calldata _programNames)
        external
        returns (AccruedRewards[] memory accruedRewards);
    function claimRewardsOnBehalf(address _user, address _to, string[] calldata _programNames)
        external
        returns (AccruedRewards[] memory accruedRewards);
    function getClaimer(address _user) external view returns (address);
    function getRewardsBalance(address _user, string calldata _programName)
        external
        view
        returns (uint256 unclaimedRewards);
    function getRewardsBalance(address _user, string[] calldata _programNames)
        external
        view
        returns (uint256 unclaimedRewards);
    function getUserUnclaimedRewards(address _user, string calldata _programName) external view returns (uint256);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/IDistributionManager.sol ---
pragma solidity 0.8.28;
import {DistributionTypes} from "../lib/DistributionTypes.sol";
interface IDistributionManager {
    struct IncentivesProgram {
        uint256 index;
        address rewardToken; 
        uint104 emissionPerSecond; 
        uint40 lastUpdateTimestamp;
        uint40 distributionEnd; 
        mapping(address user => uint256 userIndex) users;
    }
    struct IncentiveProgramDetails {
        uint256 index;
        address rewardToken;
        uint104 emissionPerSecond;
        uint40 lastUpdateTimestamp;
        uint40 distributionEnd;
    }
    struct AccruedRewards {
        uint256 amount;
        bytes32 programId;
        address rewardToken;
    }
    event AssetConfigUpdated(address indexed asset, uint256 emission);
    event AssetIndexUpdated(address indexed asset, uint256 index);
    event DistributionEndUpdated(string incentivesProgram, uint256 newDistributionEnd);
    event IncentivesProgramIndexUpdated(string incentivesProgram, uint256 newIndex);
    event UserIndexUpdated(address indexed user, string incentivesProgram, uint256 newIndex);
    error OnlyNotifier();
    error TooLongProgramName();
    error InvalidIncentivesProgramName();
    error OnlyNotifierOrOwner();
    function setDistributionEnd(string calldata _incentivesProgram, uint40 _distributionEnd) external;
    function getDistributionEnd(string calldata _incentivesProgram) external view returns (uint256);
    function getUserData(address _user, string calldata _incentivesProgram) external view returns (uint256);
    function incentivesProgram(string calldata _incentivesProgram)
        external
        view
        returns (IncentiveProgramDetails memory details);
    function getProgramId(string calldata _programName) external pure returns (bytes32 programId);
    function getAllProgramsNames() external view returns (string[] memory programsNames);
    function getProgramName(bytes32 _programName) external pure returns (string memory programName);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/incentives/interfaces/IDistributionManager.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/Tower.sol ---
pragma solidity 0.8.28;
import "openzeppelin5/access/Ownable.sol";
contract Tower is Ownable {
    mapping(bytes32 => address) private _coordinates;
    event NewCoordinates(string key, address indexed newContract);
    event UpdateCoordinates(string key, address indexed newContract);
    event RemovedCoordinates(string key);
    error AddressZero();
    error KeyIsTaken();
    error EmptyCoordinates();
    constructor() Ownable(msg.sender) {}
    function register(string calldata _key, address _contract) external virtual onlyOwner {
        bytes32 key = makeKey(_key);
        if (_coordinates[key] != address(0)) revert KeyIsTaken();
        if (_contract == address(0)) revert AddressZero();
        _coordinates[key] = _contract;
        emit NewCoordinates(_key, _contract);
    }
    function unregister(string calldata _key) external virtual onlyOwner {
        bytes32 key = makeKey(_key);
        if (_coordinates[key] == address(0)) revert EmptyCoordinates();
        _coordinates[key] = address(0);
        emit RemovedCoordinates(_key);
    }
    function update(string calldata _key, address _contract) external virtual onlyOwner {
        bytes32 key = makeKey(_key);
        if (_coordinates[key] == address(0)) revert EmptyCoordinates();
        if (_contract == address(0)) revert AddressZero();
        _coordinates[key] = _contract;
        emit UpdateCoordinates(_key, _contract);
    }
    function coordinates(string calldata _key) external view virtual returns (address) {
        return _coordinates[makeKey(_key)];
    }
    function rawCoordinates(bytes32 _key) external view virtual returns (address) {
        return _coordinates[_key];
    }
    function makeKey(string calldata _key) public pure virtual returns (bytes32) {
        return keccak256(abi.encodePacked(_key));
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/Tower.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareToken.sol ---
pragma solidity 0.8.28;
import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20PermitUpgradeable} from "openzeppelin5-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IShareToken, ISilo} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../SiloConfig.sol";
import {Hook} from "../lib/Hook.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
abstract contract ShareToken is ERC20PermitUpgradeable, IShareToken {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;
    string private constant _NAME = "SiloShareTokenEIP712Name";
    modifier onlySilo() {
        require(msg.sender == address(_getSilo()), OnlySilo());
        _;
    }
    modifier onlyHookReceiver() {
        require(
            msg.sender == address(ShareTokenLib.getShareTokenStorage().hookSetup.hookReceiver),
            ISilo.OnlyHookReceiver()
        );
        _;
    }
    constructor() {
        _disableInitializers();
    }
    function synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external virtual onlySilo {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        $.hookSetup.hooksBefore = _hooksBefore;
        $.hookSetup.hooksAfter = _hooksAfter;
    }
    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount)
        external
        virtual
        onlyHookReceiver
    {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        $.transferWithChecks = false;
        _transfer(_from, _to, _amount);
        $.transferWithChecks = true;
    }
    function silo() external view virtual returns (ISilo) {
        return _getSilo();
    }
    function siloConfig() external view virtual returns (ISiloConfig) {
        return _getSiloConfig();
    }
    function hookSetup() external view virtual returns (HookSetup memory) {
        return ShareTokenLib.getShareTokenStorage().hookSetup;
    }
    function hookReceiver() external view virtual returns (address) {
        return ShareTokenLib.getShareTokenStorage().hookSetup.hookReceiver;
    }
    function transferFrom(address _from, address _to, uint256 _amount)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();
        result = ERC20Upgradeable.transferFrom(_from, _to, _amount);
        siloConfigCached.turnOffReentrancyProtection();
    }
    function transfer(address _to, uint256 _amount)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();
        result = ERC20Upgradeable.transfer(_to, _amount);
        siloConfigCached.turnOffReentrancyProtection();
    }
    function approve(address spender, uint256 value)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool result)
    {
        NonReentrantLib.nonReentrant(_getSiloConfig());
        result = ERC20Upgradeable.approve(spender, value);
    }
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        NonReentrantLib.nonReentrant(_getSiloConfig());
        ERC20PermitUpgradeable.permit(owner, spender, value, deadline, v, r, s);
    }
    function decimals() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return ShareTokenLib.decimals();
    }
    function name()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        return ShareTokenLib.name();
    }
    function symbol()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        return ShareTokenLib.symbol();
    }
    function balanceOfAndTotalSupply(address _account) public view virtual returns (uint256, uint256) {
        return (balanceOf(_account), totalSupply());
    }
    function _shareTokenInitialize(
        ISilo _silo,
        address _hookReceiver,
        uint24 _tokenType
    )
        internal
        virtual
        initializer
    {
        __ERC20Permit_init(_NAME);
        ShareTokenLib.__ShareToken_init(_silo, _hookReceiver, _tokenType);
    }
    function _update(address from, address to, uint256 value) internal virtual override {
        require(value != 0, ZeroTransfer());
        _beforeTokenTransfer(from, to, value);
        ERC20Upgradeable._update(from, to, value);
        _afterTokenTransfer(from, to, value);
    }
    function _beforeTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual {}
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        HookSetup memory setup = $.hookSetup;
        uint256 action = Hook.shareTokenTransfer(setup.tokenType);
        if (!setup.hooksAfter.matchAction(action)) return;
        IHookReceiver(setup.hookReceiver).afterAction(
            address($.silo),
            action,
            abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
        );
    }
    function _crossNonReentrantBefore()
        internal
        virtual
        returns (ISiloConfig siloConfigCached)
    {
        siloConfigCached = _getSiloConfig();
        siloConfigCached.turnOnReentrancyProtection();
    }
    function _getSiloConfig() internal view virtual returns (ISiloConfig) {
        return ShareTokenLib.getShareTokenStorage().siloConfig;
    }
    function _getSilo() internal view virtual returns (ISilo) {
        return ShareTokenLib.getShareTokenStorage().silo;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareProtectedCollateralToken.sol ---
pragma solidity 0.8.28;
import {ShareCollateralToken} from "./ShareCollateralToken.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IShareTokenInitializable} from "../interfaces/IShareTokenInitializable.sol";
contract ShareProtectedCollateralToken is ShareCollateralToken, IShareTokenInitializable {
    function callOnBehalfOfShareToken(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        external
        payable
        virtual
        onlyHookReceiver()
        returns (bool success, bytes memory result)
    {
        (success, result) = ShareTokenLib.callOnBehalfOfShareToken(_target, _value, _callType, _input);
    }
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual {
        _shareTokenInitialize(_silo, _hookReceiver, _tokenType);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareProtectedCollateralToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/CrossReentrancyGuard.sol ---
pragma solidity 0.8.28;
import {ICrossReentrancyGuard} from "../interfaces/ICrossReentrancyGuard.sol";
abstract contract CrossReentrancyGuard is ICrossReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 0;
    uint256 private constant _ENTERED = 1;
    uint256 private transient _crossReentrantStatus;
    function turnOnReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        require(_crossReentrantStatus != _ENTERED, CrossReentrantCall());
        _crossReentrantStatus = _ENTERED;
    }
    function turnOffReentrancyProtection() external virtual {
        _onlySiloOrTokenOrHookReceiver();
        require(_crossReentrantStatus != _NOT_ENTERED, CrossReentrancyNotActive());
        _crossReentrantStatus = _NOT_ENTERED;
    }
    function reentrancyGuardEntered() external view virtual returns (bool entered) {
        entered = _crossReentrantStatus == _ENTERED;
    }
    function _onlySiloOrTokenOrHookReceiver() internal virtual {}
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/CrossReentrancyGuard.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareCollateralToken.sol ---
pragma solidity 0.8.28;
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {SiloMathLib} from "../lib/SiloMathLib.sol";
import {ShareCollateralTokenLib} from "../lib/ShareCollateralTokenLib.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";
abstract contract ShareCollateralToken is ShareToken {
    function mint(address _owner, address , uint256 _amount) external virtual override onlySilo {
        _mint(_owner, _amount);
    }
    function burn(address _owner, address _spender, uint256 _amount) external virtual override onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        if (ShareTokenLib.isTransfer(_sender, _recipient) && $.transferWithChecks) {
            bool senderIsSolvent = ShareCollateralTokenLib.isSolventAfterCollateralTransfer(_sender);
            require(senderIsSolvent, IShareToken.SenderNotSolventAfterTransfer());
        }
        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareCollateralToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareDebtToken.sol ---
pragma solidity 0.8.28;
import {IERC20R} from "../interfaces/IERC20R.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {ERC20RStorageLib} from "../lib/ERC20RStorageLib.sol";
import {IShareTokenInitializable} from "../interfaces/IShareTokenInitializable.sol";
contract ShareDebtToken is IERC20R, ShareToken, IShareTokenInitializable {
    function callOnBehalfOfShareToken(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        external
        payable
        virtual
        onlyHookReceiver()
        returns (bool success, bytes memory result)
    {
        (success, result) = ShareTokenLib.callOnBehalfOfShareToken(_target, _value, _callType, _input);
    }
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual {
        _shareTokenInitialize(_silo, _hookReceiver, _tokenType);
    }
    function mint(address _owner, address _spender, uint256 _amount) external virtual override onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _mint(_owner, _amount);
    }
    function burn(address _owner, address , uint256 _amount) external virtual override onlySilo {
        _burn(_owner, _amount);
    }
    function setReceiveApproval(address owner, uint256 _amount) external virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);
        _setReceiveApproval(owner, _msgSender(), _amount);
    }
    function decreaseReceiveAllowance(address _owner, uint256 _subtractedValue) public virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);
        uint256 currentAllowance = _receiveAllowance(_owner, _msgSender());
        uint256 newAllowance;
        unchecked {
            newAllowance = currentAllowance < _subtractedValue ? 0 : currentAllowance - _subtractedValue;
        }
        _setReceiveApproval(_owner, _msgSender(), newAllowance);
    }
    function increaseReceiveAllowance(address _owner, uint256 _addedValue) public virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);
        uint256 currentAllowance = _receiveAllowance(_owner, _msgSender());
        _setReceiveApproval(_owner, _msgSender(), currentAllowance + _addedValue);
    }
    function receiveAllowance(address _owner, address _recipient) public view virtual override returns (uint256) {
        return _receiveAllowance(_owner, _recipient);
    }
    function _setReceiveApproval(address _owner, address _recipient, uint256 _amount) internal virtual {
        require(_owner != address(0), IShareToken.OwnerIsZero());
        require(_recipient != address(0), IShareToken.RecipientIsZero());
        IERC20R.Storage storage $ = ERC20RStorageLib.getIERC20RStorage();
        $._receiveAllowances[_owner][_recipient] = _amount;
        emit ReceiveApproval(_owner, _recipient, _amount);
    }
    function _beforeTokenTransfer(address _sender, address _recipient, uint256 _amount)
        internal
        virtual
        override
    {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        if (ShareTokenLib.isTransfer(_sender, _recipient)) {
            $.siloConfig.onDebtTransfer(_sender, _recipient);
            if (!$.transferWithChecks) return;
            uint256 currentAllowance = _receiveAllowance(_sender, _recipient);
            require(currentAllowance >= _amount, IShareToken.AmountExceedsAllowance());
            uint256 newDebtAllowance;
            unchecked {
                newDebtAllowance = currentAllowance - _amount;
            }
            _setReceiveApproval(_sender, _recipient, newDebtAllowance);
        }
    }
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        if (ShareTokenLib.isTransfer(_sender, _recipient) && $.transferWithChecks) {
            $.siloConfig.accrueInterestForBothSilos();
            ShareTokenLib.callOracleBeforeQuote($.siloConfig, _recipient);
            require($.silo.isSolvent(_recipient), IShareToken.RecipientNotSolventAfterTransfer());
        }
        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);
    }
    function _receiveAllowance(address _owner, address _recipient) internal view virtual returns (uint256) {
        return ERC20RStorageLib.getIERC20RStorage()._receiveAllowances[_owner][_recipient];
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/ShareDebtToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol ---
pragma solidity 0.8.28;
import {Address} from "openzeppelin5/utils/Address.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC3156FlashBorrower} from "../../interfaces/IERC3156FlashBorrower.sol";
import {IPartialLiquidation} from "../../interfaces/IPartialLiquidation.sol";
import {ILiquidationHelper} from "../../interfaces/ILiquidationHelper.sol";
import {ISilo} from "../../interfaces/ISilo.sol";
import {ISiloConfig} from "../../interfaces/ISiloConfig.sol";
import {IWrappedNativeToken} from "../../interfaces/IWrappedNativeToken.sol";
import {DexSwap} from "./DexSwap.sol";
contract LiquidationHelper is ILiquidationHelper, IERC3156FlashBorrower, DexSwap {
    using Address for address payable;
    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address payable public immutable TOKENS_RECEIVER;
    address public immutable NATIVE_TOKEN;
    uint256 private transient _withdrawCollateral;
    uint256 private transient _repayDebtAssets;
    error NoDebtToCover();
    error STokenNotSupported();
    constructor (
        address _nativeToken,
        address _exchangeProxy,
        address payable _tokensReceiver
    ) DexSwap(_exchangeProxy) {
        NATIVE_TOKEN = _nativeToken;
        EXCHANGE_PROXY = _exchangeProxy;
        TOKENS_RECEIVER = _tokensReceiver;
    }
    receive() external payable {}
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _swapsInputs0x
    ) external virtual returns (uint256 withdrawCollateral, uint256 repayDebtAssets) {
        require(_maxDebtToCover != 0, NoDebtToCover());
        _flashLoanFrom.flashLoan(this, _debtAsset, _maxDebtToCover, abi.encode(_liquidation, _swapsInputs0x));
        IERC20(_debtAsset).approve(address(_flashLoanFrom), 0);
        withdrawCollateral = _withdrawCollateral;
        repayDebtAssets = _repayDebtAssets;
    }
    function onFlashLoan(
        address ,
        address _debtAsset,
        uint256 _maxDebtToCover,
        uint256 _fee,
        bytes calldata _data
    )
        external
        virtual
        returns (bytes32)
    {
        (
            LiquidationData memory _liquidation,
            DexSwapInput[] memory _swapInputs
        ) = abi.decode(_data, (LiquidationData, DexSwapInput[]));
        IERC20(_debtAsset).approve(address(_liquidation.hook), _maxDebtToCover);
        (
            _withdrawCollateral, _repayDebtAssets
        ) = _liquidation.hook.liquidationCall({
            _collateralAsset: _liquidation.collateralAsset,
            _debtAsset: _debtAsset,
            _user: _liquidation.user,
            _maxDebtToCover: _maxDebtToCover,
            _receiveSToken: false
        });
        IERC20(_debtAsset).approve(address(_liquidation.hook), 0);
        uint256 flashLoanWithFee = _maxDebtToCover + _fee;
        if (_liquidation.collateralAsset == _debtAsset) {
            uint256 balance = IERC20(_liquidation.collateralAsset).balanceOf(address(this));
            require(flashLoanWithFee <= balance, UnableToRepayFlashloan());
            _transferToReceiver(_liquidation.collateralAsset, balance - flashLoanWithFee);
        } else {
            _executeSwap(_swapInputs);
            uint256 debtBalance = IERC20(_debtAsset).balanceOf(address(this));
            if (flashLoanWithFee < debtBalance) {
                unchecked {
                    _transferToReceiver(_debtAsset, debtBalance - flashLoanWithFee);
                }
            } else if (flashLoanWithFee != debtBalance) {
                revert UnableToRepayFlashloan();
            }
        }
        IERC20(_debtAsset).approve(msg.sender, flashLoanWithFee);
        return _FLASHLOAN_CALLBACK;
    }
    function _executeSwap(DexSwapInput[] memory _swapInputs) internal virtual {
        for (uint256 i; i < _swapInputs.length; i++) {
            fillQuote(_swapInputs[i].sellToken, _swapInputs[i].allowanceTarget, _swapInputs[i].swapCallData);
        }
    }
    function _transferToReceiver(address _asset, uint256 _amount) internal virtual {
        if (_amount == 0) return;
        if (_asset == NATIVE_TOKEN) {
            _transferNative(_amount);
        } else {
            IERC20(_asset).transfer(TOKENS_RECEIVER, _amount);
        }
    }
    function _transferNative(uint256 _amount) internal virtual {
        IWrappedNativeToken(address(NATIVE_TOKEN)).withdraw(_amount);
        TOKENS_RECEIVER.sendValue(_amount);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/liquidationHelper/LiquidationHelper.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/liquidationHelper/DexSwap.sol ---
pragma solidity ^0.8.20;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {ILiquidationHelper} from "../../interfaces/ILiquidationHelper.sol";
import {RevertLib} from "../../lib/RevertLib.sol";
contract DexSwap {
    using RevertLib for bytes;
    address public immutable EXCHANGE_PROXY;
    error AddressZero();
    constructor(address _exchangeProxy) {
        if (_exchangeProxy == address(0)) revert AddressZero();
        EXCHANGE_PROXY = _exchangeProxy;
    }
    function fillQuote(address _sellToken, address _spender, bytes memory _swapCallData) public virtual {
        IERC20(_sellToken).approve(_spender, type(uint256).max);
        (bool success, bytes memory data) = EXCHANGE_PROXY.call(_swapCallData);
        if (!success) data.revertBytes("SWAP_CALL_FAILED");
        IERC20(_sellToken).approve(_spender, 0);
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/liquidationHelper/DexSwap.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/_common/SiloHookReceiver.sol ---
pragma solidity 0.8.28;
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IHookReceiver} from "../../../interfaces/IHookReceiver.sol";
abstract contract SiloHookReceiver is IHookReceiver {
    mapping(address silo => HookConfig) private _hookConfig;
    function _setHookConfig(address _silo, uint256 _hooksBefore, uint256 _hooksAfter) internal virtual {
        _hookConfig[_silo] = HookConfig(uint24(_hooksBefore), uint24(_hooksAfter));
        emit HookConfigured(_silo, uint24(_hooksBefore), uint24(_hooksAfter));
        ISilo(_silo).updateHooks();
    }
    function _hookReceiverConfig(address _silo) internal view virtual returns (uint24 hooksBefore, uint24 hooksAfter) {
        HookConfig memory hookConfig = _hookConfig[_silo];
        hooksBefore = hookConfig.hooksBefore;
        hooksAfter = hookConfig.hooksAfter;
    }
    function _getHooksBefore(address _silo) internal view virtual returns (uint256 hooksBefore) {
        hooksBefore = _hookConfig[_silo].hooksBefore;
    }
    function _getHooksAfter(address _silo) internal view virtual returns (uint256 hooksAfter) {
        hooksAfter = _hookConfig[_silo].hooksAfter;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/_common/SiloHookReceiver.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol ---
pragma solidity 0.8.28;
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";
import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";
import {CallBeforeQuoteLib} from "silo-core/contracts/lib/CallBeforeQuoteLib.sol";
import {PartialLiquidationExecLib} from "./lib/PartialLiquidationExecLib.sol";
contract PartialLiquidation is IPartialLiquidation, IHookReceiver {
    using SafeERC20 for IERC20;
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;
    ISiloConfig public siloConfig;
    struct LiquidationCallParams {
        uint256 collateralShares;
        uint256 protectedShares;
        uint256 withdrawAssetsFromCollateral;
        uint256 withdrawAssetsFromProtected;
        bytes4 customError;
    }
    function initialize(ISiloConfig _siloConfig, bytes calldata) external virtual {
        _initialize(_siloConfig);
    }
    function beforeAction(address, uint256, bytes calldata) external virtual {
    }
    function afterAction(address, uint256, bytes calldata) external virtual {
    }
    function liquidationCall( 
        address _collateralAsset,
        address _debtAsset,
        address _borrower,
        uint256 _maxDebtToCover,
        bool _receiveSToken
    )
        external
        virtual
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        ISiloConfig siloConfigCached = siloConfig;
        require(address(siloConfigCached) != address(0), EmptySiloConfig());
        require(_maxDebtToCover != 0, NoDebtToCover());
        siloConfigCached.turnOnReentrancyProtection();
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _fetchConfigs(siloConfigCached, _collateralAsset, _debtAsset, _borrower);
        LiquidationCallParams memory params;
        (
            params.withdrawAssetsFromCollateral, params.withdrawAssetsFromProtected, repayDebtAssets, params.customError
        ) = PartialLiquidationExecLib.getExactLiquidationAmounts(
            collateralConfig,
            debtConfig,
            _borrower,
            _maxDebtToCover,
            collateralConfig.liquidationFee
        );
        RevertLib.revertIfError(params.customError);
        require(repayDebtAssets <= _maxDebtToCover, FullLiquidationRequired());
        IERC20(debtConfig.token).safeTransferFrom(msg.sender, address(this), repayDebtAssets);
        IERC20(debtConfig.token).safeIncreaseAllowance(debtConfig.silo, repayDebtAssets);
        address shareTokenReceiver = _receiveSToken ? msg.sender : address(this);
        params.collateralShares = _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            shareTokenReceiver,
            params.withdrawAssetsFromCollateral,
            collateralConfig.collateralShareToken,
            ISilo.AssetType.Collateral
        );
        params.protectedShares = _callShareTokenForwardTransferNoChecks(
            collateralConfig.silo,
            _borrower,
            shareTokenReceiver,
            params.withdrawAssetsFromProtected,
            collateralConfig.protectedShareToken,
            ISilo.AssetType.Protected
        );
        siloConfigCached.turnOffReentrancyProtection();
        ISilo(debtConfig.silo).repay(repayDebtAssets, _borrower);
        if (_receiveSToken) {
            if (params.collateralShares != 0) {
                withdrawCollateral = ISilo(collateralConfig.silo).previewRedeem(
                    params.collateralShares,
                    ISilo.CollateralType.Collateral
                );
            }
            if (params.protectedShares != 0) {
                unchecked {
                    withdrawCollateral += ISilo(collateralConfig.silo).previewRedeem(
                        params.protectedShares,
                        ISilo.CollateralType.Protected
                    );
                }
            }
        } else {
            if (params.collateralShares != 0) {
                withdrawCollateral = ISilo(collateralConfig.silo).redeem({
                    _shares: params.collateralShares,
                    _receiver: msg.sender,
                    _owner: address(this),
                    _collateralType: ISilo.CollateralType.Collateral
                });
            }
            if (params.protectedShares != 0) {
                unchecked {
                    withdrawCollateral += ISilo(collateralConfig.silo).redeem({
                        _shares: params.protectedShares,
                        _receiver: msg.sender,
                        _owner: address(this),
                        _collateralType: ISilo.CollateralType.Protected
                    });
                }
            }
        }
        emit LiquidationCall(
            msg.sender,
            debtConfig.silo,
            _borrower,
            repayDebtAssets,
            withdrawCollateral,
            _receiveSToken
        );
    }
    function hookReceiverConfig(address) external virtual view returns (uint24 hooksBefore, uint24 hooksAfter) {
        return (0, 0);
    }
    function maxLiquidation(address _borrower)
        external
        view
        virtual
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired)
    {
        return PartialLiquidationExecLib.maxLiquidation(siloConfig, _borrower);
    }
    function _fetchConfigs(
        ISiloConfig _siloConfigCached,
        address _collateralAsset,
        address _debtAsset,
        address _borrower
    )
        internal
        virtual
        returns (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        )
    {
        (collateralConfig, debtConfig) = _siloConfigCached.getConfigsForSolvency(_borrower);
        require(debtConfig.silo != address(0), UserIsSolvent());
        require(_collateralAsset == collateralConfig.token, UnexpectedCollateralToken());
        require(_debtAsset == debtConfig.token, UnexpectedDebtToken());
        ISilo(debtConfig.silo).accrueInterest();
        if (collateralConfig.silo != debtConfig.silo) {
            ISilo(collateralConfig.silo).accrueInterest();
            collateralConfig.callSolvencyOracleBeforeQuote();
            debtConfig.callSolvencyOracleBeforeQuote();
        }
    }
    function _callShareTokenForwardTransferNoChecks(
        address _silo,
        address _borrower,
        address _receiver,
        uint256 _withdrawAssets,
        address _shareToken,
        ISilo.AssetType _assetType
    ) internal virtual returns (uint256 shares) {
        if (_withdrawAssets == 0) return 0;
        shares = SiloMathLib.convertToShares(
            _withdrawAssets,
            ISilo(_silo).getTotalAssetsStorage(_assetType),
            IShareToken(_shareToken).totalSupply(),
            Rounding.LIQUIDATE_TO_SHARES,
            ISilo.AssetType(_assetType)
        );
        if (shares == 0) return 0;
        IShareToken(_shareToken).forwardTransferFromNoChecks(_borrower, _receiver, shares);
    }
    function _initialize(ISiloConfig _siloConfig) internal virtual {
        require(address(_siloConfig) != address(0), EmptySiloConfig());
        require(address(siloConfig) == address(0), AlreadyConfigured());
        siloConfig = _siloConfig;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/PartialLiquidation.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationExecLib.sol ---
pragma solidity 0.8.28;
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationLib} from "./PartialLiquidationLib.sol";
library PartialLiquidationExecLib {
    function getExactLiquidationAmounts(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _user,
        uint256 _maxDebtToCover,
        uint256 _liquidationFee
    )
        external
        view
        returns (
            uint256 withdrawAssetsFromCollateral,
            uint256 withdrawAssetsFromProtected,
            uint256 repayDebtAssets,
            bytes4 customError
        )
    {
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations({
            _collateralConfig: _collateralConfig,
            _debtConfig: _debtConfig,
            _borrower: _user,
            _oracleType: ISilo.OracleType.Solvency,
            _accrueInMemory: ISilo.AccrueInterestInMemory.No,
            _debtShareBalanceCached:0 
        });
        uint256 borrowerCollateralToLiquidate;
        (
            borrowerCollateralToLiquidate, repayDebtAssets, customError
        ) = liquidationPreview(
            ltvData,
            PartialLiquidationLib.LiquidationPreviewParams({
                collateralLt: _collateralConfig.lt,
                collateralConfigAsset: _collateralConfig.token,
                debtConfigAsset: _debtConfig.token,
                maxDebtToCover: _maxDebtToCover,
                liquidationTargetLtv: _collateralConfig.liquidationTargetLtv,
                liquidationFee: _liquidationFee
            })
        );
        (
            withdrawAssetsFromCollateral, withdrawAssetsFromProtected
        ) = PartialLiquidationLib.splitReceiveCollateralToLiquidate(
            borrowerCollateralToLiquidate, ltvData.borrowerProtectedAssets
        );
    }
    function maxLiquidation(ISiloConfig _siloConfig, address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired)
    {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _siloConfig.getConfigsForSolvency(_borrower);
        if (debtConfig.silo == address(0)) {
            return (0, 0, false);
        }
        SiloSolvencyLib.LtvData memory ltvData = SiloSolvencyLib.getAssetsDataForLtvCalculations(
            collateralConfig,
            debtConfig,
            _borrower,
            ISilo.OracleType.Solvency,
            ISilo.AccrueInterestInMemory.Yes,
            0 
        );
        if (ltvData.borrowerDebtAssets == 0) return (0, 0, false);
        (
            uint256 sumOfCollateralValue, uint256 debtValue
        ) = SiloSolvencyLib.getPositionValues(ltvData, collateralConfig.token, debtConfig.token);
        uint256 sumOfCollateralAssets = ltvData.borrowerProtectedAssets + ltvData.borrowerCollateralAssets;
        if (sumOfCollateralValue == 0) return (sumOfCollateralAssets, ltvData.borrowerDebtAssets, false);
        uint256 ltvInDp = SiloSolvencyLib.ltvMath(debtValue, sumOfCollateralValue);
        if (ltvInDp <= collateralConfig.lt) return (0, 0, false); 
        (collateralToLiquidate, debtToRepay) = PartialLiquidationLib.maxLiquidation(
            sumOfCollateralAssets,
            sumOfCollateralValue,
            ltvData.borrowerDebtAssets,
            debtValue,
            collateralConfig.liquidationTargetLtv,
            collateralConfig.liquidationFee
        );
        unchecked {
            uint256 overestimatedCollateral = collateralToLiquidate + PartialLiquidationLib._UNDERESTIMATION;
            sTokenRequired = overestimatedCollateral > ISilo(collateralConfig.silo).getLiquidity();
        }
    }
    function liquidationPreview( 
        SiloSolvencyLib.LtvData memory _ltvData,
        PartialLiquidationLib.LiquidationPreviewParams memory _params
    )
        internal
        view
        returns (uint256 receiveCollateralAssets, uint256 repayDebtAssets, bytes4 customError)
    {
        uint256 sumOfCollateralAssets = _ltvData.borrowerCollateralAssets + _ltvData.borrowerProtectedAssets;
        if (_ltvData.borrowerDebtAssets == 0 || _params.maxDebtToCover == 0) {
            return (0, 0, IPartialLiquidation.NoDebtToCover.selector);
        }
        if (sumOfCollateralAssets == 0) {
            return (
                0,
                _params.maxDebtToCover > _ltvData.borrowerDebtAssets
                    ? _ltvData.borrowerDebtAssets
                    : _params.maxDebtToCover,
                bytes4(0) 
            );
        }
        (
            uint256 sumOfBorrowerCollateralValue, uint256 totalBorrowerDebtValue, uint256 ltvBefore
        ) = SiloSolvencyLib.calculateLtv(_ltvData, _params.collateralConfigAsset, _params.debtConfigAsset);
        if (_params.collateralLt >= ltvBefore) return (0, 0, IPartialLiquidation.UserIsSolvent.selector);
        uint256 ltvAfter;
        (receiveCollateralAssets, repayDebtAssets, ltvAfter) = PartialLiquidationLib.liquidationPreview(
            ltvBefore,
            sumOfCollateralAssets,
            sumOfBorrowerCollateralValue,
            _ltvData.borrowerDebtAssets,
            totalBorrowerDebtValue,
            _params
        );
        if (receiveCollateralAssets == 0 || repayDebtAssets == 0) {
            return (0, 0, IPartialLiquidation.NoRepayAssets.selector);
        }
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationExecLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationLib.sol ---
pragma solidity 0.8.28;
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";
library PartialLiquidationLib {
    using Math for uint256;
    struct LiquidationPreviewParams {
        uint256 collateralLt;
        address collateralConfigAsset;
        address debtConfigAsset;
        uint256 maxDebtToCover;
        uint256 liquidationFee;
        uint256 liquidationTargetLtv;
    }
    uint256 internal constant _BAD_DEBT = 1e18;
    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _UNDERESTIMATION = 2;
    uint256 internal constant _DEBT_DUST_LEVEL = 0.9e18; 
    function maxLiquidation(
        uint256 _sumOfCollateralAssets,
        uint256 _sumOfCollateralValue,
        uint256 _borrowerDebtAssets,
        uint256 _borrowerDebtValue,
        uint256 _liquidationTargetLTV,
        uint256 _liquidationFee
    )
        internal
        pure
        returns (uint256 collateralToLiquidate, uint256 debtToRepay)
    {
        (
            uint256 collateralValueToLiquidate, uint256 repayValue
        ) = maxLiquidationPreview(
            _sumOfCollateralValue,
            _borrowerDebtValue,
            _liquidationTargetLTV,
            _liquidationFee
        );
        collateralToLiquidate = valueToAssetsByRatio(
            collateralValueToLiquidate,
            _sumOfCollateralAssets,
            _sumOfCollateralValue
        );
        if (collateralToLiquidate > _UNDERESTIMATION) {
            unchecked { collateralToLiquidate -= _UNDERESTIMATION; }
        } else {
            collateralToLiquidate = 0;
        }
        debtToRepay = valueToAssetsByRatio(repayValue, _borrowerDebtAssets, _borrowerDebtValue);
    }
    function liquidationPreview( 
        uint256 _ltvBefore,
        uint256 _sumOfCollateralAssets,
        uint256 _sumOfCollateralValue,
        uint256 _borrowerDebtAssets,
        uint256 _borrowerDebtValue,
        LiquidationPreviewParams memory _params
    )
        internal
        pure
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, uint256 ltvAfter)
    {
        uint256 collateralValueToLiquidate;
        uint256 debtValueToRepay;
        if (_ltvBefore >= _BAD_DEBT) {
            debtToRepay = _params.maxDebtToCover > _borrowerDebtAssets ? _borrowerDebtAssets : _params.maxDebtToCover;
            debtValueToRepay = valueToAssetsByRatio(debtToRepay, _borrowerDebtValue, _borrowerDebtAssets);
        } else {
            uint256 maxRepayValue = estimateMaxRepayValue(
                _borrowerDebtValue,
                _sumOfCollateralValue,
                _params.liquidationTargetLtv,
                _params.liquidationFee
            );
            if (maxRepayValue == _borrowerDebtValue) {
                debtToRepay = _borrowerDebtAssets;
                debtValueToRepay = _borrowerDebtValue;
            } else {
                uint256 maxDebtToRepay = valueToAssetsByRatio(maxRepayValue, _borrowerDebtAssets, _borrowerDebtValue);
                debtToRepay = _params.maxDebtToCover > maxDebtToRepay ? maxDebtToRepay : _params.maxDebtToCover;
                debtValueToRepay = valueToAssetsByRatio(debtToRepay, _borrowerDebtValue, _borrowerDebtAssets);
            }
        }
        collateralValueToLiquidate = calculateCollateralToLiquidate(
            debtValueToRepay, _sumOfCollateralValue, _params.liquidationFee
        );
        collateralToLiquidate = valueToAssetsByRatio(
            collateralValueToLiquidate,
            _sumOfCollateralAssets,
            _sumOfCollateralValue
        );
        ltvAfter = _calculateLtvAfter(
            _sumOfCollateralValue, _borrowerDebtValue, collateralValueToLiquidate, debtValueToRepay
        );
    }
    function valueToAssetsByRatio(uint256 _value, uint256 _totalAssets, uint256 _totalValue)
        internal
        pure
        returns (uint256 assets)
    {
        require(_totalValue != 0, IPartialLiquidation.UnknownRatio());
        assets = _value * _totalAssets / _totalValue;
    }
    function calculateCollateralsToLiquidate(
        uint256 _debtValueToCover,
        uint256 _totalBorrowerCollateralValue,
        uint256 _totalBorrowerCollateralAssets,
        uint256 _liquidationFee
    ) internal pure returns (uint256 collateralAssetsToLiquidate, uint256 collateralValueToLiquidate) {
        collateralValueToLiquidate = calculateCollateralToLiquidate(
            _debtValueToCover, _totalBorrowerCollateralValue, _liquidationFee
        );
        if (collateralValueToLiquidate == _totalBorrowerCollateralValue) {
            return (_totalBorrowerCollateralAssets, _totalBorrowerCollateralValue);
        }
        collateralAssetsToLiquidate = valueToAssetsByRatio(
            collateralValueToLiquidate, _totalBorrowerCollateralAssets, _totalBorrowerCollateralValue
        );
    }
    function maxLiquidationPreview(
        uint256 _totalBorrowerCollateralValue,
        uint256 _totalBorrowerDebtValue,
        uint256 _ltvAfterLiquidation,
        uint256 _liquidationFee
    ) internal pure returns (uint256 collateralValueToLiquidate, uint256 repayValue) {
        repayValue = estimateMaxRepayValue(
            _totalBorrowerDebtValue, _totalBorrowerCollateralValue, _ltvAfterLiquidation, _liquidationFee
        );
        collateralValueToLiquidate = calculateCollateralToLiquidate(
            repayValue, _totalBorrowerCollateralValue, _liquidationFee
        );
    }
    function calculateCollateralToLiquidate(uint256 _maxDebtToCover, uint256 _sumOfCollateral, uint256 _liquidationFee)
        internal
        pure
        returns (uint256 toLiquidate)
    {
        uint256 fee = _maxDebtToCover * _liquidationFee / _PRECISION_DECIMALS;
        toLiquidate = _maxDebtToCover + fee;
        if (toLiquidate > _sumOfCollateral) {
            toLiquidate = _sumOfCollateral;
        }
    }
    function estimateMaxRepayValue( 
        uint256 _totalBorrowerDebtValue,
        uint256 _totalBorrowerCollateralValue,
        uint256 _ltvAfterLiquidation,
        uint256 _liquidationFee
    ) internal pure returns (uint256 repayValue) {
        if (_totalBorrowerDebtValue == 0) return 0;
        if (_liquidationFee >= _PRECISION_DECIMALS) return 0;
        if (_totalBorrowerDebtValue >= _totalBorrowerCollateralValue) return _totalBorrowerDebtValue;
        if (_ltvAfterLiquidation == 0) return _totalBorrowerDebtValue; 
        uint256 ltCv = _ltvAfterLiquidation * _totalBorrowerCollateralValue;
        _totalBorrowerDebtValue *= _PRECISION_DECIMALS;
        if (ltCv >= _totalBorrowerDebtValue) return 0;
        uint256 dividerR; 
        unchecked {
            repayValue = _totalBorrowerDebtValue - ltCv;
            dividerR = _ltvAfterLiquidation + _ltvAfterLiquidation * _liquidationFee / _PRECISION_DECIMALS;
        }
        unchecked { _totalBorrowerDebtValue /= _PRECISION_DECIMALS; }
        if (dividerR >= _PRECISION_DECIMALS) {
             return _totalBorrowerDebtValue;
        }
        unchecked { repayValue /= (_PRECISION_DECIMALS - dividerR); }
        if (repayValue > _totalBorrowerDebtValue) return _totalBorrowerDebtValue;
        return repayValue * _PRECISION_DECIMALS / _totalBorrowerDebtValue > _DEBT_DUST_LEVEL
            ? _totalBorrowerDebtValue
            : repayValue;
    }
    function splitReceiveCollateralToLiquidate(uint256 _collateralToLiquidate, uint256 _borrowerProtectedAssets)
        internal
        pure
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected)
    {
        if (_collateralToLiquidate == 0) return (0, 0);
        unchecked {
            (
                withdrawAssetsFromCollateral, withdrawAssetsFromProtected
            ) = _collateralToLiquidate > _borrowerProtectedAssets
                ? (_collateralToLiquidate - _borrowerProtectedAssets, _borrowerProtectedAssets)
                : (0, _collateralToLiquidate);
        }
    }
    function _calculateLtvAfter(
        uint256 _sumOfCollateralValue,
        uint256 _totalDebtValue,
        uint256 _collateralValueToLiquidate,
        uint256 _debtValueToCover
    )
        private
        pure
        returns (uint256 ltvAfterLiquidation)
    {
        if (_sumOfCollateralValue <= _collateralValueToLiquidate || _totalDebtValue <= _debtValueToCover) {
            return 0;
        }
        unchecked { 
            ltvAfterLiquidation = _ltvAfter(
                _sumOfCollateralValue - _collateralValueToLiquidate,
                _totalDebtValue - _debtValueToCover
            );
        }
    }
    function _ltvAfter(uint256 _collateral, uint256 _debt) private pure returns (uint256 ltv) {
        ltv = _debt * _PRECISION_DECIMALS;
        ltv = Math.ceilDiv(ltv, _collateral); 
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationLib.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol ---
pragma solidity 0.8.28;
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {PartialLiquidation} from "../liquidation/PartialLiquidation.sol";
import {IGaugeLike as IGauge} from "../../../interfaces/IGaugeLike.sol";
import {IGaugeHookReceiver, IHookReceiver} from "../../../interfaces/IGaugeHookReceiver.sol";
import {SiloHookReceiver} from "../_common/SiloHookReceiver.sol";
contract GaugeHookReceiver is PartialLiquidation, IGaugeHookReceiver, SiloHookReceiver, Ownable2Step, Initializable {
    using Hook for uint256;
    using Hook for bytes;
    uint24 internal constant _HOOKS_BEFORE_NOT_CONFIGURED = 0;
    IShareToken public shareToken;
    mapping(IShareToken => IGauge) public configuredGauges;
    constructor() Ownable(msg.sender) {
        _disableInitializers();
        _transferOwnership(address(0));
    }
    function initialize(ISiloConfig _siloConfig, bytes calldata _data)
        external
        virtual
        initializer
        override(IHookReceiver, PartialLiquidation)
    {
        (address owner) = abi.decode(_data, (address));
        require(owner != address(0), OwnerIsZeroAddress());
        _initialize(_siloConfig);
        _transferOwnership(owner);
    }
    function setGauge(IGauge _gauge, IShareToken _shareToken) external virtual onlyOwner {
        require(address(_gauge) != address(0), EmptyGaugeAddress());
        require(_gauge.share_token() == address(_shareToken), WrongGaugeShareToken());
        address configuredGauge = address(configuredGauges[_shareToken]);
        require(configuredGauge == address(0), GaugeAlreadyConfigured());
        address silo = address(_shareToken.silo());
        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);
        uint256 action = tokenType | Hook.SHARE_TOKEN_TRANSFER;
        hooksAfter = hooksAfter.addAction(action);
        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);
        configuredGauges[_shareToken] = _gauge;
        emit GaugeConfigured(address(_gauge), address(_shareToken));
    }
    function removeGauge(IShareToken _shareToken) external virtual onlyOwner {
        IGauge configuredGauge = configuredGauges[_shareToken];
        require(address(configuredGauge) != address(0), GaugeIsNotConfigured());
        require(configuredGauge.is_killed(), CantRemoveActiveGauge());
        address silo = address(_shareToken.silo());
        uint256 tokenType = _getTokenType(silo, address(_shareToken));
        uint256 hooksAfter = _getHooksAfter(silo);
        hooksAfter = hooksAfter.removeAction(tokenType);
        _setHookConfig(silo, _HOOKS_BEFORE_NOT_CONFIGURED, hooksAfter);
        delete configuredGauges[_shareToken];
        emit GaugeRemoved(address(_shareToken));
    }
    function beforeAction(address, uint256, bytes calldata)
        external
        virtual
        override(IHookReceiver, PartialLiquidation)
    {
        revert RequestNotSupported();
    }
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput)
        external
        virtual
        override(IHookReceiver, PartialLiquidation)
    {
        IGauge theGauge = configuredGauges[IShareToken(msg.sender)];
        require(theGauge != IGauge(address(0)), GaugeIsNotConfigured());
        if (theGauge.is_killed()) return; 
        if (!_getHooksAfter(_silo).matchAction(_action)) return; 
        Hook.AfterTokenTransfer memory input = _inputAndOutput.afterTokenTransferDecode();
        theGauge.afterTokenTransfer(
            input.sender,
            input.senderBalance,
            input.recipient,
            input.recipientBalance,
            input.totalSupply,
            input.amount
        );
    }
    function hookReceiverConfig(address _silo)
        external
        view
        virtual
        override(PartialLiquidation, IHookReceiver)
        returns (uint24 hooksBefore, uint24 hooksAfter)
    {
        return _hookReceiverConfig(_silo);
    }
    function _getTokenType(address _silo, address _shareToken) internal view virtual returns (uint256) {
        (
            address protectedShareToken,
            address collateralShareToken,
            address debtShareToken
        ) = siloConfig.getShareTokens(_silo);
        if (_shareToken == collateralShareToken) return Hook.COLLATERAL_TOKEN;
        if (_shareToken == protectedShareToken) return Hook.PROTECTED_TOKEN;
        if (_shareToken == debtShareToken) return Hook.DEBT_TOKEN;
        revert InvalidShareToken();
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/utils/hook-receivers/gauge/GaugeHookReceiver.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol ---
pragma solidity 0.8.28;
import {Clones} from "openzeppelin5/proxy/Clones.sol";
import {InterestRateModelV2} from "./InterestRateModelV2.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Factory} from "../interfaces/IInterestRateModelV2Factory.sol";
import {InterestRateModelV2Config} from "./InterestRateModelV2Config.sol";
contract InterestRateModelV2Factory is IInterestRateModelV2Factory {
    uint256 public constant DP = 1e18;
    address public immutable IRM;
    mapping(bytes32 configHash => IInterestRateModelV2) public irmByConfigHash;
    constructor() {
        IRM = address(new InterestRateModelV2());
    }
    function create(IInterestRateModelV2.Config calldata _config)
        external
        virtual
        returns (bytes32 configHash, IInterestRateModelV2 irm)
    {
        configHash = hashConfig(_config);
        irm = irmByConfigHash[configHash];
        if (address(irm) != address(0)) {
            return (configHash, irm);
        }
        verifyConfig(_config);
        address configContract = address(new InterestRateModelV2Config(_config));
        irm = IInterestRateModelV2(Clones.clone(IRM));
        IInterestRateModel(address(irm)).initialize(configContract);
        irmByConfigHash[configHash] = irm;
        emit NewInterestRateModelV2(configHash, irm);
    }
    function verifyConfig(IInterestRateModelV2.Config calldata _config) public view virtual {
        int256 dp = int256(DP);
        require(_config.uopt > 0 && _config.uopt < dp, IInterestRateModelV2.InvalidUopt());
        require(_config.ucrit > _config.uopt && _config.ucrit < dp, IInterestRateModelV2.InvalidUcrit());
        require(_config.ulow > 0 && _config.ulow < _config.uopt, IInterestRateModelV2.InvalidUlow());
        require(_config.ki >= 0, IInterestRateModelV2.InvalidKi());
        require(_config.kcrit >= 0, IInterestRateModelV2.InvalidKcrit());
        require(_config.klow >= 0, IInterestRateModelV2.InvalidKlow());
        require(_config.klin >= 0, IInterestRateModelV2.InvalidKlin());
        require(_config.beta >= 0, IInterestRateModelV2.InvalidBeta());
        require(_config.ri >= 0, IInterestRateModelV2.InvalidRi());
        require(_config.Tcrit >= 0, IInterestRateModelV2.InvalidTcrit());
        InterestRateModelV2(IRM).configOverflowCheck(_config);
    }
    function hashConfig(IInterestRateModelV2.Config calldata _config)
        public
        pure
        virtual
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2Factory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2.sol ---
pragma solidity 0.8.28;
import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";
import {PRBMathSD59x18} from "../lib/PRBMathSD59x18.sol";
import {SiloMathLib} from "../lib/SiloMathLib.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
import {IInterestRateModelV2Config} from "../interfaces/IInterestRateModelV2Config.sol";
contract InterestRateModelV2 is IInterestRateModel, IInterestRateModelV2 {
    using PRBMathSD59x18 for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    struct LocalVarsRCur {
        int256 T;
        int256 u;
        int256 DP;
        int256 rp;
        int256 rlin;
        int256 ri;
        bool overflow;
    }
    struct LocalVarsRComp {
        int256 T;
        int256 slopei;
        int256 rp;
        int256 slope;
        int256 r0;
        int256 rlin;
        int256 r1;
        int256 x;
        int256 rlin1;
        int256 u;
    }
    uint256 internal constant _DP = 1e18;
    uint256 public constant RCOMP_MAX = (2**16) * 1e18;
    int256 public constant X_MAX = 11090370147631773313;
    uint256 public constant ASSET_DATA_OVERFLOW_LIMIT = type(uint256).max / RCOMP_MAX;
    mapping (address silo => Setup) public getSetup;
    IInterestRateModelV2Config public irmConfig;
    event Initialized(address indexed config);
    function initialize(address _irmConfig) external virtual {
        require(_irmConfig != address(0), AddressZero());
        require(address(irmConfig) == address(0), AlreadyInitialized());
        irmConfig = IInterestRateModelV2Config(_irmConfig);
        emit Initialized(_irmConfig);
    }
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        virtual
        override
        returns (uint256 rcomp)
    {
        address silo = msg.sender;
        Setup storage currentSetup = getSetup[silo];
        int256 ri;
        int256 Tcrit;
        (rcomp, ri, Tcrit) = calculateCompoundInterestRate(
            getConfig(silo),
            _collateralAssets,
            _debtAssets,
            _interestRateTimestamp,
            block.timestamp
        );
        currentSetup.initialized = true;
        currentSetup.ri = ri > type(int112).max
            ? type(int112).max
            : ri < type(int112).min ? type(int112).min : int112(ri);
        currentSetup.Tcrit = Tcrit > type(int112).max
            ? type(int112).max
            : Tcrit < type(int112).min ? type(int112).min : int112(Tcrit);
    }
    function decimals() external view virtual returns (uint256) {
        return 18;
    }
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        override
        returns (uint256 rcomp)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        (rcomp,,) = calculateCompoundInterestRate(
            getConfig(_silo),
            data.collateralAssets,
            data.debtAssets,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }
    function overflowDetected(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        override
        returns (bool overflow)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        (,,,overflow) = calculateCompoundInterestRateWithOverflowDetection(
            getConfig(_silo),
            data.collateralAssets,
            data.debtAssets,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        override
        returns (uint256 rcur)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();
        rcur = calculateCurrentInterestRate(
            getConfig(_silo),
            data.collateralAssets,
            data.debtAssets,
            data.interestRateTimestamp,
            _blockTimestamp
        );
    }
    function getConfig(address _silo) public view virtual returns (Config memory fullConfig) {
        Setup memory siloSetup = getSetup[_silo];
        fullConfig = irmConfig.getConfig();
        if (siloSetup.initialized) {
            fullConfig.ri = siloSetup.ri;
            fullConfig.Tcrit = siloSetup.Tcrit;
        }
    }
    function calculateCurrentInterestRate(
        Config memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual returns (uint256 rcur) {
        require(_interestRateTimestamp <= _blockTimestamp, InvalidTimestamps());
        LocalVarsRCur memory _l = LocalVarsRCur(0,0,0,0,0,0,false); 
        (,,,_l.overflow) = calculateCompoundInterestRateWithOverflowDetection(
            _c,
            _totalDeposits,
            _totalBorrowAmount,
            _interestRateTimestamp,
            _blockTimestamp
        );
        if (_l.overflow) {
            return 0;
        }
        unchecked {
            _l.T = (_blockTimestamp - _interestRateTimestamp).toInt256();
        }
        _l.u = SiloMathLib.calculateUtilization(_DP, _totalDeposits, _totalBorrowAmount).toInt256();
        _l.DP = int256(_DP);
        if (_l.u > _c.ucrit) {
            _l.rp = _c.kcrit * (_l.DP + _c.Tcrit + _c.beta * _l.T) / _l.DP * (_l.u - _c.ucrit) / _l.DP;
        } else {
            _l.rp = _min(0, _c.klow * (_l.u - _c.ulow) / _l.DP);
        }
        _l.rlin = _c.klin * _l.u / _l.DP;
        _l.ri = _max(_c.ri, _l.rlin);
        _l.ri = _max(_l.ri + _c.ki * (_l.u - _c.uopt) * _l.T / _l.DP, _l.rlin);
        rcur = (_max(_l.ri + _l.rp, _l.rlin)).toUint256();
        rcur *= 365 days;
        return _currentInterestRateCAP(rcur);
    }
    function calculateCompoundInterestRate(
        Config memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual override returns (
        uint256 rcomp,
        int256 ri,
        int256 Tcrit
    ) {
        (rcomp, ri, Tcrit,) = calculateCompoundInterestRateWithOverflowDetection(
            _c,
            _totalDeposits,
            _totalBorrowAmount,
            _interestRateTimestamp,
            _blockTimestamp
        );
    }
    function calculateCompoundInterestRateWithOverflowDetection( 
        Config memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) public pure virtual returns (
        uint256 rcomp,
        int256 ri,
        int256 Tcrit,
        bool overflow
    ) {
        ri = _c.ri;
        Tcrit = _c.Tcrit;
        LocalVarsRComp memory _l = LocalVarsRComp(0,0,0,0,0,0,0,0,0,0);
        require(_interestRateTimestamp <= _blockTimestamp, InvalidTimestamps());
        unchecked {
            _l.T = (_blockTimestamp - _interestRateTimestamp).toInt256();
        }
        int256 decimalPoints = int256(_DP);
        _l.u = SiloMathLib.calculateUtilization(_DP, _totalDeposits, _totalBorrowAmount).toInt256();
        _l.slopei = _c.ki * (_l.u - _c.uopt) / decimalPoints;
        if (_l.u > _c.ucrit) {
            _l.rp = _c.kcrit * (decimalPoints + Tcrit) / decimalPoints * (_l.u - _c.ucrit) / decimalPoints;
            _l.slope = _l.slopei + _c.kcrit * _c.beta / decimalPoints * (_l.u - _c.ucrit) / decimalPoints;
            Tcrit = Tcrit + _c.beta * _l.T;
        } else {
            _l.rp = _min(0, _c.klow * (_l.u - _c.ulow) / decimalPoints);
            _l.slope = _l.slopei;
            Tcrit = _max(0, Tcrit - _c.beta * _l.T);
        }
        _l.rlin = _c.klin * _l.u / decimalPoints;
        ri = _max(ri , _l.rlin);
        _l.r0 = ri + _l.rp;
        _l.r1 = _l.r0 + _l.slope * _l.T;
        if (_l.r0 >= _l.rlin && _l.r1 >= _l.rlin) {
            _l.x = (_l.r0 + _l.r1) * _l.T / 2;
        } else if (_l.r0 < _l.rlin && _l.r1 < _l.rlin) {
            _l.x = _l.rlin * _l.T;
        } else if (_l.r0 >= _l.rlin && _l.r1 < _l.rlin) {
            _l.x = _l.rlin * _l.T - (_l.r0 - _l.rlin)**2 / _l.slope / 2;
        } else {
            _l.x = _l.rlin * _l.T + (_l.r1 - _l.rlin)**2 / _l.slope / 2;
        }
        ri = _max(ri + _l.slopei * _l.T, _l.rlin);
        (rcomp, overflow) = _calculateRComp(_totalDeposits, _totalBorrowAmount, _l.x);
        bool capApplied;
        (rcomp, capApplied) = _compoundInterestRateCAP(rcomp, _l.T.toUint256());
        if (overflow || capApplied) {
            ri = 0;
            Tcrit = 0;
        }
    }
    function configOverflowCheck(IInterestRateModelV2.Config calldata _config) external pure virtual {
        int256 YEAR = 365 days;
        int256 MAX_TIME = 50 * 365 days;
        int256 DP = int256(_DP);
        int256 rcur_max;
        {
            int256 Tcrit_max = _config.Tcrit + _config.beta * MAX_TIME;
            int256 rp_max = _config.kcrit * (DP + Tcrit_max) / DP * (DP - _config.ucrit) / DP;
            int256 rp_min = -_config.klow * _config.ulow / DP;
            int256 rlin_max = _config.klin * DP / DP;
            int256 ri_max = _max(_config.ri, rlin_max) +_config.ki * (DP - _config.uopt) * MAX_TIME / DP;
            int256 ri_min = -_config.ki * _config.uopt * MAX_TIME / DP;
            rcur_max = ri_max + rp_max;
            int256 rcur_min = ri_min + rp_min;
            int256 rcur_ann_max = rcur_max * YEAR;
        }
        {
            int256 slopei_max = _config.ki * (DP - _config.uopt) / DP;
            int256 slopei_min = - _config.ki * _config.uopt / DP;
            int256 slope_max = slopei_max + _config.kcrit * _config.beta / DP * (DP - _config.ucrit) / DP;
            int256 slope_min = slopei_min;
            int256 x_max = rcur_max * 2 * MAX_TIME / 2 + (_max(slope_max, -slope_min) * MAX_TIME)**2 / 2;
        }
    }
    function _calculateRComp(
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        int256 _x
    ) internal pure virtual returns (uint256 rcomp, bool overflow) {
        int256 rcompSigned;
        if (_x >= X_MAX) {
            rcomp = RCOMP_MAX;
            overflow = true;
        } else {
            rcompSigned = _x.exp() - int256(_DP);
            rcomp = rcompSigned > 0 ? rcompSigned.toUint256() : 0;
        }
        unchecked {
            uint256 maxAmount = _totalDeposits > _totalBorrowAmount ? _totalDeposits : _totalBorrowAmount;
            if (maxAmount >= ASSET_DATA_OVERFLOW_LIMIT) {
                return (0, true);
            }
            uint256 rcompMulTBA = rcomp * _totalBorrowAmount;
            if (rcompMulTBA == 0) {
                return (rcomp, overflow);
            }
            if (
                rcompMulTBA / rcomp != _totalBorrowAmount ||
                rcompMulTBA / _DP > ASSET_DATA_OVERFLOW_LIMIT - maxAmount
            ) {
                rcomp = (ASSET_DATA_OVERFLOW_LIMIT - maxAmount) * _DP / _totalBorrowAmount;
                return (rcomp, true);
            }
        }
    }
    function _max(int256 a, int256 b) internal pure virtual returns (int256) {
        return a > b ? a : b;
    }
    function _min(int256 a, int256 b) internal pure virtual returns (int256) {
        return a < b ? a : b;
    }
    function _compoundInterestRateCAP(uint256 _rcomp, uint256 _t)
        internal
        pure
        virtual
        returns (uint256 updatedRcomp, bool capApplied)
    {
        uint256 cap = 3170979198376 * _t;
        return _rcomp > cap ? (cap, true) : (_rcomp, false);
    }
    function _currentInterestRateCAP(uint256 _rcur) internal pure virtual returns (uint256) {
        uint256 cap = 1e20; 
        return _rcur > cap ? cap : _rcur;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol ---
pragma solidity 0.8.28;
import {IInterestRateModelV2Config} from "../interfaces/IInterestRateModelV2Config.sol";
import {IInterestRateModelV2} from "../interfaces/IInterestRateModelV2.sol";
contract InterestRateModelV2Config is IInterestRateModelV2Config {
    int256 internal immutable _UOPT;
    int256 internal immutable _UCRIT;
    int256 internal immutable _ULOW;
    int256 internal immutable _KI;
    int256 internal immutable _KCRIT;
    int256 internal immutable _KLOW;
    int256 internal immutable _KLIN;
    int256 internal immutable _BETA;
    int112 internal immutable _RI;
    int112 internal immutable _TCRIT;
    constructor(IInterestRateModelV2.Config memory _config) {
        _UOPT = _config.uopt;
        _UCRIT = _config.ucrit;
        _ULOW = _config.ulow;
        _KI = _config.ki;
        _KCRIT = _config.kcrit;
        _KLOW = _config.klow;
        _KLIN = _config.klin;
        _BETA = _config.beta;
        _RI = _config.ri;
        _TCRIT = _config.Tcrit;
    }
    function getConfig() external view virtual returns (IInterestRateModelV2.Config memory config) {
        config.uopt = _UOPT;
        config.ucrit = _UCRIT;
        config.ulow = _ULOW;
        config.ki = _KI;
        config.kcrit = _KCRIT;
        config.klow = _KLOW;
        config.klin = _KLIN;
        config.beta = _BETA;
        config.ri = _RI;
        config.Tcrit = _TCRIT;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interestRateModel/InterestRateModelV2Config.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol ---
pragma solidity >=0.5.0;
import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
interface IInterestRateModelV2Factory {
    event NewInterestRateModelV2(bytes32 indexed configHash, IInterestRateModelV2 indexed irm);
    function create(IInterestRateModelV2.Config calldata _config)
        external
        returns (bytes32 configHash, IInterestRateModelV2 irm);
    function DP() external view returns (uint256);
    function verifyConfig(IInterestRateModelV2.Config calldata _config) external view;
    function hashConfig(IInterestRateModelV2.Config calldata _config) external pure returns (bytes32 configId);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IShareTokenInitializable.sol ---
pragma solidity >=0.5.0;
import {ISilo} from "./ISilo.sol";
interface IShareTokenInitializable {
    function callOnBehalfOfShareToken(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        external
        payable
        returns (bool success, bytes memory result);
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external;
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IShareTokenInitializable.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IWrappedNativeToken.sol ---
pragma solidity >=0.5.0;
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
interface IWrappedNativeToken is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IWrappedNativeToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloFactory.sol ---
pragma solidity >=0.5.0;
import {IERC721} from "openzeppelin5/interfaces/IERC721.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
interface ISiloFactory is IERC721 {
    struct Range {
        uint128 min;
        uint128 max;
    }
    event NewSilo(
        address indexed implementation,
        address indexed token0,
        address indexed token1,
        address silo0,
        address silo1,
        address siloConfig
    );
    event BaseURI(string newBaseURI);
    event DaoFeeChanged(uint128 minDaoFee, uint128 maxDaoFee);
    event MaxDeployerFeeChanged(uint256 maxDeployerFee);
    event MaxFlashloanFeeChanged(uint256 maxFlashloanFee);
    event MaxLiquidationFeeChanged(uint256 maxLiquidationFee);
    event DaoFeeReceiverChanged(address daoFeeReceiver);
    error MissingHookReceiver();
    error ZeroAddress();
    error DaoFeeReceiverZeroAddress();
    error EmptyToken0();
    error EmptyToken1();
    error MaxFeeExceeded();
    error InvalidFeeRange();
    error SameAsset();
    error SameRange();
    error InvalidIrm();
    error InvalidMaxLtv();
    error InvalidLt();
    error InvalidDeployer();
    error DaoMinRangeExceeded();
    error DaoMaxRangeExceeded();
    error MaxDeployerFeeExceeded();
    error MaxFlashloanFeeExceeded();
    error MaxLiquidationFeeExceeded();
    error InvalidCallBeforeQuote();
    error OracleMisconfiguration();
    error InvalidQuoteToken();
    error HookIsZeroAddress();
    error LiquidationTargetLtvTooHigh();
    function createSilo(
        ISiloConfig.InitData memory _initData,
        ISiloConfig _siloConfig,
        address _siloImpl,
        address _shareProtectedCollateralTokenImpl,
        address _shareDebtTokenImpl
    )
        external;
    function burn(uint256 _siloIdToBurn) external;
    function setDaoFee(uint128 _minFee, uint128 _maxFee) external;
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external;
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external;
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external;
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external;
    function setBaseURI(string calldata _newBaseURI) external;
    function daoFeeRange() external view returns (Range memory);
    function maxDeployerFee() external view returns (uint256);
    function maxFlashloanFee() external view returns (uint256);
    function maxLiquidationFee() external view returns (uint256);
    function daoFeeReceiver() external view returns (address);
    function idToSiloConfig(uint256 _id) external view returns (address);
    function isSilo(address _silo) external view returns (bool);
    function getNextSiloId() external view returns (uint256);
    function getFeeReceivers(address _silo) external view returns (address dao, address deployer);
    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view returns (bool);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloFactory.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModel.sol ---
pragma solidity >=0.5.0;
interface IInterestRateModel {
    event InterestRateModelError();
    function initialize(address _irmConfig) external;
    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        returns (uint256 rcomp);
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcomp);
    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur);
    function decimals() external view returns (uint256);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModel.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloOracle.sol ---
pragma solidity >=0.5.0;
interface ISiloOracle {
    function beforeQuote(address _baseToken) external;
    function quote(uint256 _baseAmount, address _baseToken) external view returns (uint256 quoteAmount);
    function quoteToken() external view returns (address);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloOracle.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2Config.sol ---
pragma solidity >=0.5.0;
import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
interface IInterestRateModelV2Config {
    function getConfig() external view returns (IInterestRateModelV2.Config memory config);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2Config.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IHookReceiver.sol ---
pragma solidity >=0.5.0;
import {ISiloConfig} from "./ISiloConfig.sol";
interface IHookReceiver {
    struct HookConfig {
        uint24 hooksBefore;
        uint24 hooksAfter;
    }
    event HookConfigured(address silo, uint24 hooksBefore, uint24 hooksAfter);
    function initialize(ISiloConfig _siloConfig, bytes calldata _data) external;
    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external;
    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external;
    function hookReceiverConfig(address _silo) external view returns (uint24 hooksBefore, uint24 hooksAfter);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IHookReceiver.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ILiquidationHelper.sol ---
pragma solidity >=0.5.0;
import {ISilo} from "./ISilo.sol";
import {IPartialLiquidation} from "./IPartialLiquidation.sol";
interface ILiquidationHelper {
    error UnableToRepayFlashloan();
    struct DexSwapInput {
        address sellToken;
        address allowanceTarget;
        bytes swapCallData;
    }
    struct LiquidationData {
        IPartialLiquidation hook;
        address collateralAsset;
        address user;
    }
    function executeLiquidation(
        ISilo _flashLoanFrom,
        address _debtAsset,
        uint256 _maxDebtToCover,
        LiquidationData calldata _liquidation,
        DexSwapInput[] calldata _dexSwapInput
    ) external returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ILiquidationHelper.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2.sol ---
pragma solidity >=0.5.0;
import {IInterestRateModelV2Config} from "./IInterestRateModelV2Config.sol";
interface IInterestRateModelV2 {
    struct Config {
        int256 uopt;
        int256 ucrit;
        int256 ulow;
        int256 ki;
        int256 kcrit;
        int256 klow;
        int256 klin;
        int256 beta;
        int112 ri;
        int112 Tcrit;
    }
    struct Setup {
        int112 ri;
        int112 Tcrit;
        bool initialized;
    }
    error AddressZero();
    error DeployConfigFirst();
    error AlreadyInitialized();
    error InvalidBeta();
    error InvalidKcrit();
    error InvalidKi();
    error InvalidKlin();
    error InvalidKlow();
    error InvalidTcrit();
    error InvalidTimestamps();
    error InvalidUcrit();
    error InvalidUlow();
    error InvalidUopt();
    error InvalidRi();
    function getConfig(address _silo) external view returns (Config memory);
    function overflowDetected(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (bool overflow);
    function calculateCurrentInterestRate(
        Config calldata _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) external pure returns (uint256 rcur);
    function calculateCompoundInterestRateWithOverflowDetection(
        Config memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    )
        external
        pure
        returns (
            uint256 rcomp,
            int256 ri,
            int256 Tcrit,
            bool overflow
        );
    function calculateCompoundInterestRate(
        Config memory _c,
        uint256 _totalDeposits,
        uint256 _totalBorrowAmount,
        uint256 _interestRateTimestamp,
        uint256 _blockTimestamp
    ) external pure returns (uint256 rcomp, int256 ri, int256 Tcrit);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IInterestRateModelV2.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC20R.sol ---
pragma solidity >=0.5.0;
interface IERC20R {
    struct Storage {
        mapping(address owner => mapping(address recipient => uint256 allowance)) _receiveAllowances;
    }
    event ReceiveApproval(address indexed _owner, address indexed _receiver, uint256 _value);
    function decreaseReceiveAllowance(address _owner, uint256 _subtractedValue) external;
    function increaseReceiveAllowance(address _owner, uint256 _addedValue) external;
    function setReceiveApproval(address _owner, uint256 _amount) external;
    function receiveAllowance(address _owner, address _receiver) external view returns (uint256);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC20R.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloConfig.sol ---
pragma solidity >=0.5.0;
import {ISilo} from "./ISilo.sol";
import {ICrossReentrancyGuard} from "./ICrossReentrancyGuard.sol";
interface ISiloConfig is ICrossReentrancyGuard {
    struct InitData {
        address deployer;
        address hookReceiver;
        uint256 deployerFee;
        uint256 daoFee;
        address token0;
        address solvencyOracle0;
        address maxLtvOracle0;
        address interestRateModel0;
        uint256 maxLtv0;
        uint256 lt0;
        uint256 liquidationTargetLtv0;
        uint256 liquidationFee0;
        uint256 flashloanFee0;
        bool callBeforeQuote0;
        address token1;
        address solvencyOracle1;
        address maxLtvOracle1;
        address interestRateModel1;
        uint256 maxLtv1;
        uint256 lt1;
        uint256 liquidationTargetLtv1;
        uint256 liquidationFee1;
        uint256 flashloanFee1;
        bool callBeforeQuote1;
    }
    struct ConfigData {
        uint256 daoFee;
        uint256 deployerFee;
        address silo;
        address token;
        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;
        address solvencyOracle;
        address maxLtvOracle;
        address interestRateModel;
        uint256 maxLtv;
        uint256 lt;
        uint256 liquidationTargetLtv;
        uint256 liquidationFee;
        uint256 flashloanFee;
        address hookReceiver;
        bool callBeforeQuote;
    }
    struct DepositConfig {
        address silo;
        address token;
        address collateralShareToken;
        address protectedShareToken;
        uint256 daoFee;
        uint256 deployerFee;
        address interestRateModel;
    }
    error OnlySilo();
    error OnlySiloOrTokenOrHookReceiver();
    error WrongSilo();
    error OnlyDebtShareToken();
    error DebtExistInOtherSilo();
    error FeeTooHigh();
    function onDebtTransfer(address _sender, address _recipient) external;
    function setThisSiloAsCollateralSilo(address _borrower) external;
    function setOtherSiloAsCollateralSilo(address _borrower) external;
    function accrueInterestForSilo(address _silo) external;
    function accrueInterestForBothSilos() external;
    function borrowerCollateralSilo(address _borrower) external view returns (address collateralSilo);
    function SILO_ID() external view returns (uint256 siloId); 
    function getSilos() external view returns (address silo0, address silo1);
    function getAssetForSilo(address _silo) external view returns (address asset);
    function hasDebtInOtherSilo(address _thisSilo, address _borrower) external view returns (bool hasDebt);
    function getDebtSilo(address _borrower) external view returns (address debtSilo);
    function getConfigsForSolvency(address borrower)
        external
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig);
    function getConfig(address _silo) external view returns (ConfigData memory config);
    function getConfigsForWithdraw(address _silo, address _borrower) external view returns (
        DepositConfig memory depositConfig,
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    );
    function getConfigsForBorrow(address _debtSilo)
        external
        view
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig);
    function getFeesWithAsset(address _silo)
        external
        view
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset);
    function getShareTokens(address _silo)
        external
        view
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken);
    function getCollateralShareTokenAndAsset(address _silo, ISilo.CollateralType _collateralType)
        external
        view
        returns (address shareToken, address asset);
    function getDebtShareTokenAndAsset(address _silo)
        external
        view
        returns (address shareToken, address asset);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloConfig.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IPartialLiquidation.sol ---
pragma solidity >=0.5.0;
interface IPartialLiquidation {
    struct HookSetup {
        address hookReceiver;
        uint24 hooksBefore;
        uint24 hooksAfter;
    }
    event LiquidationCall(
        address indexed liquidator,
        address indexed silo,
        address indexed borrower,
        uint256 repayDebtAssets,
        uint256 withdrawCollateral,
        bool receiveSToken
    );
    error EmptySiloConfig();
    error AlreadyConfigured();
    error UnexpectedCollateralToken();
    error UnexpectedDebtToken();
    error NoDebtToCover();
    error FullLiquidationRequired();
    error UserIsSolvent();
    error UnknownRatio();
    error NoRepayAssets();
    function liquidationCall(
        address _collateralAsset,
        address _debtAsset,
        address _user,
        uint256 _maxDebtToCover,
        bool _receiveSToken
    )
        external
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets);
    function maxLiquidation(address _borrower)
        external
        view
        returns (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IPartialLiquidation.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IGaugeHookReceiver.sol ---
pragma solidity >=0.5.0;
import {IShareToken} from "./IShareToken.sol";
import {IHookReceiver} from "./IHookReceiver.sol";
import {IGaugeLike as IGauge} from "./IGaugeLike.sol";
interface IGaugeHookReceiver is IHookReceiver {
    event GaugeConfigured(address gauge, address shareToken);
    event GaugeRemoved(address shareToken);
    error OwnerIsZeroAddress();
    error InvalidShareToken();
    error WrongGaugeShareToken();
    error CantRemoveActiveGauge();
    error EmptyGaugeAddress();
    error RequestNotSupported();
    error GaugeIsNotConfigured();
    error GaugeAlreadyConfigured();
    function setGauge(IGauge _gauge, IShareToken _shareToken) external;
    function removeGauge(IShareToken _shareToken) external;
    function shareToken() external view returns (IShareToken);
    function configuredGauges(IShareToken _shareToken) external view returns (IGauge);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IGaugeHookReceiver.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IShareToken.sol ---
pragma solidity >=0.5.0;
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISilo} from "./ISilo.sol";
interface IShareToken is IERC20Metadata {
    struct HookSetup {
        address hookReceiver;
        uint24 hooksBefore;
        uint24 hooksAfter;
        uint24 tokenType;
    }
    struct ShareTokenStorage {
        ISilo silo;
        ISiloConfig siloConfig;
        HookSetup hookSetup;
        bool transferWithChecks;
    }
    event NotificationSent(address indexed notificationReceiver, bool success);
    error OnlySilo();
    error OnlySiloConfig();
    error OwnerIsZero();
    error RecipientIsZero();
    error AmountExceedsAllowance();
    error RecipientNotSolventAfterTransfer();
    error SenderNotSolventAfterTransfer();
    error ZeroTransfer();
    function synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external;
    function mint(address _owner, address _spender, uint256 _amount) external;
    function burn(address _owner, address _spender, uint256 _amount) external;
    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount) external;
    function balanceOfAndTotalSupply(address _account) external view returns (uint256 balance, uint256 totalSupply);
    function silo() external view returns (ISilo silo);
    function siloConfig() external view returns (ISiloConfig silo);
    function hookSetup() external view returns (HookSetup memory);
    function hookReceiver() external view returns (address);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IShareToken.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IGaugeLike.sol ---
pragma solidity >=0.5.0;
interface IGaugeLike {
    event GaugeKilled();
    event GaugeUnKilled();
    error EmptyShareToken();
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;
    function killGauge() external;
    function unkillGauge() external;
    function share_token() external view returns (address);
    function is_killed() external view returns (bool);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IGaugeLike.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloDeployer.sol ---
pragma solidity >=0.8.0;
import {IInterestRateModelV2} from "./IInterestRateModelV2.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
interface ISiloDeployer {
    struct OracleCreationTxData {
        address deployed; 
        address factory; 
        bytes txInput; 
    }
    struct ClonableHookReceiver {
        address implementation;
        bytes initializationData;
    }
    struct Oracles {
        OracleCreationTxData solvencyOracle0;
        OracleCreationTxData maxLtvOracle0;
        OracleCreationTxData solvencyOracle1;
        OracleCreationTxData maxLtvOracle1;
    }
    event SiloCreated(ISiloConfig siloConfig);
    error FailedToCreateAnOracle(address _factory);
    error HookReceiverMisconfigured();
    function deploy(
        Oracles calldata _oracles,
        IInterestRateModelV2.Config calldata _irmConfigData0,
        IInterestRateModelV2.Config calldata _irmConfigData1,
        ClonableHookReceiver calldata _clonableHookReceiver,
        ISiloConfig.InitData memory _siloInitData
    )
        external
        returns (ISiloConfig siloConfig);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloDeployer.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloERC20.sol ---
pragma solidity ^0.8.0;
interface ISiloERC20 {
    struct ERC20Storage {
        mapping(address account => uint256) _balances;
        mapping(address account => mapping(address spender => uint256)) _allowances;
        uint256 _totalSupply;
        string _name;
        string _symbol;
    }
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloERC20.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC3156FlashLender.sol ---
pragma solidity >=0.5.0;
import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";
interface IERC3156FlashLender {
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        returns (bool);
    function maxFlashLoan(address _token) external view returns (uint256);
    function flashFee(address _token, uint256 _amount) external view returns (uint256);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC3156FlashLender.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISilo.sol ---
pragma solidity >=0.5.0;
import {IERC4626, IERC20, IERC20Metadata} from "openzeppelin5/interfaces/IERC4626.sol";
import {IERC3156FlashLender} from "./IERC3156FlashLender.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";
import {IHookReceiver} from "./IHookReceiver.sol";
interface ISilo is IERC20, IERC4626, IERC3156FlashLender {
    enum AccrueInterestInMemory {
        No,
        Yes
    }
    enum OracleType {
        Solvency,
        MaxLtv
    }
    enum AssetType {
        Protected, 
        Collateral,
        Debt
    }
    enum CollateralType {
        Protected, 
        Collateral
    }
    enum CallType {
        Call, 
        Delegatecall
    }
    struct WithdrawArgs {
        uint256 assets;
        uint256 shares;
        address receiver;
        address owner;
        address spender;
        ISilo.CollateralType collateralType;
    }
    struct BorrowArgs {
        uint256 assets;
        uint256 shares;
        address receiver;
        address borrower;
    }
    struct TransitionCollateralArgs {
        uint256 shares;
        address owner;
        ISilo.CollateralType transitionFrom;
    }
    struct UtilizationData {
        uint256 collateralAssets;
        uint256 debtAssets;
        uint64 interestRateTimestamp;
    }
    struct SiloStorage {
        uint192 daoAndDeployerRevenue;
        uint64 interestRateTimestamp;
        mapping(AssetType assetType => uint256 assets) totalAssets;
    }
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event WithdrawProtected(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event Borrow(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event Repay(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event CollateralTypeChanged(address indexed borrower);
    event HooksUpdated(uint24 hooksBefore, uint24 hooksAfter);
    event AccruedInterest(uint256 hooksBefore);
    event FlashLoan(uint256 amount);
    event WithdrawnFeed(uint256 daoFees, uint256 deployerFees);
    error UnsupportedFlashloanToken();
    error FlashloanAmountTooBig();
    error NothingToWithdraw();
    error NotEnoughLiquidity();
    error NotSolvent();
    error BorrowNotPossible();
    error EarnedZero();
    error FlashloanFailed();
    error AboveMaxLtv();
    error SiloInitialized();
    error OnlyHookReceiver();
    error NoLiquidity();
    error InputCanBeAssetsOrShares();
    error CollateralSiloAlreadySet();
    error RepayTooHigh();
    error ZeroAmount();
    error InputZeroShares();
    error ReturnZeroAssets();
    error ReturnZeroShares();
    function factory() external view returns (ISiloFactory siloFactory);
    function callOnBehalfOfSilo(address _target, uint256 _value, CallType _callType, bytes calldata _input)
        external
        payable
        returns (bool success, bytes memory result);
    function initialize(ISiloConfig _siloConfig) external;
    function updateHooks() external;
    function config() external view returns (ISiloConfig siloConfig);
    function utilizationData() external view returns (UtilizationData memory utilizationData);
    function getLiquidity() external view returns (uint256 liquidity);
    function isSolvent(address _borrower) external view returns (bool);
    function getTotalAssetsStorage(AssetType _assetType) external view returns (uint256);
    function getSiloStorage()
        external
        view
        returns (
            uint192 daoAndDeployerRevenue,
            uint64 interestRateTimestamp,
            uint256 protectedAssets,
            uint256 collateralAssets,
            uint256 debtAssets
        );
    function getCollateralAssets() external view returns (uint256 totalCollateralAssets);
    function getDebtAssets() external view returns (uint256 totalDebtAssets);
    function getCollateralAndProtectedTotalsStorage()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalProtectedAssets);
    function getCollateralAndDebtTotalsStorage()
        external
        view
        returns (uint256 totalCollateralAssets, uint256 totalDebtAssets);
    function convertToShares(uint256 _assets, AssetType _assetType) external view returns (uint256 shares);
    function convertToAssets(uint256 _shares, AssetType _assetType) external view returns (uint256 assets);
    function previewDeposit(uint256 _assets, CollateralType _collateralType) external view returns (uint256 shares);
    function deposit(uint256 _assets, address _receiver, CollateralType _collateralType)
        external
        returns (uint256 shares);
    function previewMint(uint256 _shares, CollateralType _collateralType) external view returns (uint256 assets);
    function mint(uint256 _shares, address _receiver, CollateralType _collateralType) external returns (uint256 assets);
    function maxWithdraw(address _owner, CollateralType _collateralType) external view returns (uint256 maxAssets);
    function previewWithdraw(uint256 _assets, CollateralType _collateralType) external view returns (uint256 shares);
    function withdraw(uint256 _assets, address _receiver, address _owner, CollateralType _collateralType)
        external
        returns (uint256 shares);
    function maxRedeem(address _owner, CollateralType _collateralType) external view returns (uint256 maxShares);
    function previewRedeem(uint256 _shares, CollateralType _collateralType) external view returns (uint256 assets);
    function redeem(uint256 _shares, address _receiver, address _owner, CollateralType _collateralType)
        external
        returns (uint256 assets);
    function maxBorrow(address _borrower) external view returns (uint256 maxAssets);
    function previewBorrow(uint256 _assets) external view returns (uint256 shares);
    function borrow(uint256 _assets, address _receiver, address _borrower)
        external returns (uint256 shares);
    function maxBorrowShares(address _borrower) external view returns (uint256 maxShares);
    function previewBorrowShares(uint256 _shares) external view returns (uint256 assets);
    function maxBorrowSameAsset(address _borrower) external view returns (uint256 maxAssets);
    function borrowSameAsset(uint256 _assets, address _receiver, address _borrower)
        external returns (uint256 shares);
    function borrowShares(uint256 _shares, address _receiver, address _borrower)
        external
        returns (uint256 assets);
    function maxRepay(address _borrower) external view returns (uint256 assets);
    function previewRepay(uint256 _assets) external view returns (uint256 shares);
    function repay(uint256 _assets, address _borrower) external returns (uint256 shares);
    function maxRepayShares(address _borrower) external view returns (uint256 shares);
    function previewRepayShares(uint256 _shares) external view returns (uint256 assets);
    function repayShares(uint256 _shares, address _borrower) external returns (uint256 assets);
    function transitionCollateral(uint256 _shares, address _owner, CollateralType _transitionFrom)
        external
        returns (uint256 assets);
    function switchCollateralToThisSilo() external;
    function accrueInterest() external returns (uint256 accruedInterest);
    function accrueInterestForConfig(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee
    ) external;
    function withdrawFees() external;
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISilo.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC3156FlashBorrower.sol ---
pragma solidity >=0.5.0;
interface IERC3156FlashBorrower {
    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/IERC3156FlashBorrower.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloLens.sol ---
pragma solidity >=0.5.0;
import {ISilo} from "./ISilo.sol";
interface ISiloLens {
    function getRawLiquidity(ISilo _silo) external view returns (uint256 liquidity);
    function getMaxLtv(ISilo _silo) external view returns (uint256 maxLtv);
    function getLt(ISilo _silo) external view returns (uint256 lt);
    function getLtv(ISilo _silo, address _borrower) external view returns (uint256 ltv);
    function getFeesAndFeeReceivers(ISilo _silo)
        external
        view
        returns (address daoFeeReceiver, address deployerFeeReceiver, uint256 daoFee, uint256 deployerFee);
    function getInterestRateModel(ISilo _silo) external view returns (address irm);
    function getBorrowAPR(ISilo _silo) external view returns (uint256 borrowAPR);
    function getDepositAPR(ISilo _silo) external view returns (uint256 depositAPR);
    function collateralBalanceOfUnderlying(ISilo _silo, address _borrower)
        external
        view
        returns (uint256);
    function collateralBalanceOfUnderlying(ISilo _silo, address _asset, address _borrower)
        external
        view
        returns (uint256);
    function debtBalanceOfUnderlying(ISilo _silo, address _borrower) external view returns (uint256);
    function debtBalanceOfUnderlying(ISilo _silo, address _asset, address _borrower) external view returns (uint256);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ISiloLens.sol ---
--- START FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ICrossReentrancyGuard.sol ---
pragma solidity >=0.5.0;
interface ICrossReentrancyGuard {
    error CrossReentrantCall();
    error CrossReentrancyNotActive();
    function turnOnReentrancyProtection() external;
    function turnOffReentrancyProtection() external;
    function reentrancyGuardEntered() external view returns (bool entered);
}
--- END FILE: ../silo-contracts-v2/silo-core/contracts/interfaces/ICrossReentrancyGuard.sol ---