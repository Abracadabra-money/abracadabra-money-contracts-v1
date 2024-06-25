// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/Governance.s.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

contract SpellTimelockV2 is TimelockControllerUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) external reinitializer(2) {
        __TimelockController_init(minDelay, proposers, executors, admin);
    }
}

contract GovernanceTest is BaseTest {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    ERC1967Factory factory;
    SpellTimelock timelock;

    function setUp() public override {
        fork(ChainId.Arbitrum, 225241370);
        super.setUp();

        GovernanceScript script = new GovernanceScript();
        script.setTesting(true);

        script.deploy();

        factory = ERC1967Factory(toolkit.getAddress(ChainId.All, "ERC1967Factory"));
        timelock = SpellTimelock(payable(toolkit.getAddress(ChainId.All, "gov.timelock")));

        pushPrank(0xfB3485c2e209A5cfBDC1447674256578f1A80eE3);
        timelock.grantRole(EXECUTOR_ROLE, alice);
        timelock.grantRole(PROPOSER_ROLE, alice);
        popPrank();
    }

    function testUpdateTimelockSettings() public {
        pushPrank(alice);
        assertEq(timelock.getMinDelay(), 2 days);

        timelock.schedule(
            address(timelock),
            0,
            abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days),
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );
        advanceTime(2 days);
        timelock.execute(address(timelock), 0, abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days), bytes32(0), bytes32(0));
        assertEq(timelock.getMinDelay(), 1 days);
        popPrank();
    }

    function testUpdateTimelockUpgrade() public {
        pushPrank(alice);
        SpellTimelockV2 newTimelock = new SpellTimelockV2();

        assertEq(timelock.getMinDelay(), 2 days);
        timelock.schedule(
            address(timelock),
            0,
            abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days),
            bytes32(0),
            bytes32(0),
            timelock.getMinDelay()
        );
        advanceTime(2 days);
        timelock.execute(address(timelock), 0, abi.encodeCall(TimelockControllerUpgradeable.updateDelay, 1 days), bytes32(0), bytes32(0));
        assertEq(timelock.getMinDelay(), 1 days);
        popPrank();

        pushPrank(factory.adminOf(address(timelock)));
        factory.upgradeAndCall(
            address(timelock),
            address(newTimelock),
            abi.encodeWithSelector(SpellTimelock.initialize.selector, 2 days, new address[](0), new address[](0), tx.origin)
        );
        popPrank();
        assertEq(timelock.getMinDelay(), 2 days);
    }
}
