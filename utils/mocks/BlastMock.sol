// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";
import {Toolkit, getToolkit, ChainId} from "../Toolkit.sol";
import {IBlast, YieldMode, GasMode, IERC20Rebasing} from "interfaces/IBlast.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

abstract contract BlastTokenMock is IERC20Rebasing {
    event Configure(address indexed account, YieldMode yieldMode);
    event Claim(address indexed account, address indexed recipient, uint256 amount);

    error CannotClaimToSameAccount();
    error NotClaimableAccount();

    mapping(address => YieldMode) private _yieldMode;
    mapping(address account => uint256 amount) claimable;

    function configure(YieldMode newYieldMode) external returns (YieldMode) {
        _yieldMode[msg.sender] = newYieldMode;
        return newYieldMode;
    }

    function addClaimable(address account, uint256 amount) external {
        claimable[account] += amount;
    }

    function getConfiguration(address account) public view returns (YieldMode) {
        return _yieldMode[account];
    }

    function claim(address recipient, uint256 amount) external returns (uint256) {
        address account = msg.sender;

        if (account == recipient) {
            revert CannotClaimToSameAccount();
        }

        if (getConfiguration(account) != YieldMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        emit Claim(msg.sender, recipient, amount);

        claimable[account] -= amount;
        _claim(recipient, amount);

        return amount;
    }

    function getClaimableAmount(address account) external view returns (uint256) {
        if (getConfiguration(account) != YieldMode.CLAIMABLE) {
            revert NotClaimableAccount();
        }

        return claimable[account];
    }

    function _claim(address account, uint256 amount) internal virtual;
}

contract BlastToken is ERC20, BlastTokenMock {
    constructor(uint8 decimals_) ERC20("BlastToken", "BLAST", decimals_) {}

    function _claim(address account, uint256 amount) internal override {
        super._mint(account, amount);
    }
}

contract BlastWETH is WETH, BlastTokenMock {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function _claim(address account, uint256 amount) internal override {
        vm.deal(address(this), amount);
        this.deposit{value: amount}();
        transfer(account, amount);
    }
}

/// @title BlastMock
/// @notice Mock contract for Blast L2, only supports claimable mode.
contract BlastMock is IBlast {
    using SafeTransferLib for address;

    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
    Toolkit internal toolkit = getToolkit();

    mapping(IERC20Rebasing token => bool) tokenEnabled;
    mapping(address account => uint256 amount) claimableAmounts;
    mapping(address account => uint256 amount) claimableGas;
    mapping(address => address) public governorMap;

    constructor() {
        IERC20Rebasing usdbImpl = IERC20Rebasing(address(new BlastToken(6)));
        IERC20Rebasing wethImpl = IERC20Rebasing(address(new BlastWETH()));

        _registerToken(toolkit.getAddress(ChainId.Blast, "weth"), wethImpl);
        _registerToken(toolkit.getAddress(ChainId.Blast, "usdb"), usdbImpl);
    }

    function _registerToken(address tokenAddress, IERC20Rebasing impl) internal {
        tokenEnabled[IERC20Rebasing(tokenAddress)] = true;
        vm.etch(tokenAddress, address(impl).code);
    }

    function isGovernor(address contractAddress) public view returns (bool) {
        return msg.sender == governorMap[contractAddress];
    }

    function governorNotSet(address contractAddress) internal view returns (bool) {
        return governorMap[contractAddress] == address(0);
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return isGovernor(contractAddress) || (governorNotSet(contractAddress) && msg.sender == contractAddress);
    }

    function configure(YieldMode, GasMode, address governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = governor;
    }

    function configureContract(address contractAddress, YieldMode, GasMode, address _newGovernor) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
    }

    function configureClaimableYield() external view {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external view {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
    }

    function configureAutomaticYield() external {}

    function configureAutomaticYieldOnBehalf(address contractAddress) external {}

    function configureVoidYield() external {}

    function configureVoidYieldOnBehalf(address contractAddress) external {}

    function configureClaimableGas() external view {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
    }

    function configureClaimableGasOnBehalf(address contractAddress) external view {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
    }

    function configureVoidGas() external {}

    function configureVoidGasOnBehalf(address contractAddress) external {}

    function configureGovernor(address _governor) external {
        require(isAuthorized(msg.sender), "not authorized to configure contract");
        governorMap[msg.sender] = _governor;
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external {
        require(isAuthorized(contractAddress), "not authorized to configure contract");
        governorMap[contractAddress] = _newGovernor;
    }

    function readClaimableYield(address contractAddress) external view override returns (uint256) {
        return claimableAmounts[contractAddress];
    }

    function addClaimable(address account, uint256 amount) external {
        claimableAmounts[account] += amount;
        vm.deal(address(this), amount);
    }

    function addClaimableGas(address account, uint256 amount) external {
        claimableGas[account] += amount;
        vm.deal(address(this), amount);
    }

    function claimYield(address contractAddress, address recipient, uint256 amount) public override returns (uint256) {
        require(isAuthorized(contractAddress), "Not authorized to claim yield");
        claimableAmounts[contractAddress] -= amount;
        recipient.safeTransferETH(amount);
        return amount;
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256) {
        return claimYield(contractAddress, recipientOfYield, claimableAmounts[contractAddress]);
    }

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 /*gasSecondsToConsume*/
    ) public returns (uint256) {
        require(isAuthorized(contractAddress), "Not allowed to claim gas");
        claimableGas[contractAddress] -= gasToClaim;
        recipientOfGas.safeTransferETH(gasToClaim);
        return gasToClaim;
    }

    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 /*minClaimRateBips*/
    ) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256) {
        return claimGas(contractAddress, recipientOfGas, claimableGas[contractAddress], 0);
    }

    function readYieldConfiguration(address /*contractAddress*/) external pure returns (uint8) {
        return uint8(YieldMode.CLAIMABLE);
    }

    function readGasParams(
        address /*contractAddress*/
    ) external pure returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode) {
        return (0, 0, 0, GasMode.CLAIMABLE);
    }
}
