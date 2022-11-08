// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/CauldronOwner.s.sol";

contract MyTest is BaseTest {
    struct CauldronEntry {
        address cauldron;
        uint8 version;
    }

    CauldronEntry[] entries;
    CauldronOwner public cauldronOwner;

    function setUp() public override {
        forkMainnet(15925886);
        super.setUp();

        CauldronOwnerScript script = new CauldronOwnerScript();
        script.setTesting(true);
        (cauldronOwner) = script.run();

        entries.push(CauldronEntry({cauldron: 0xc1879bf24917ebE531FbAA20b0D05Da027B592ce, version: 2})); // AGLD
        entries.push(CauldronEntry({cauldron: 0x7b7473a76D6ae86CE19f7352A1E89F6C9dc39020, version: 2})); // ALCX
        entries.push(CauldronEntry({cauldron: 0x257101F20cB7243E2c7129773eD5dBBcef8B34E0, version: 2})); // cvx2pool
        entries.push(CauldronEntry({cauldron: 0x35a0Dd182E4bCa59d5931eae13D0A2332fA30321, version: 2})); // cvxRenCRV
        entries.push(CauldronEntry({cauldron: 0x4EAeD76C3A388f4a841E9c765560BBe7B3E4B3A0, version: 2})); // cvxtricrypto2
        entries.push(CauldronEntry({cauldron: 0x806e16ec797c69afa8590A55723CE4CC1b54050E, version: 2})); // Cvx3pool
        entries.push(CauldronEntry({cauldron: 0x6371EfE5CD6e3d2d7C477935b7669401143b7985, version: 2})); // CVX3Pool  new
        entries.push(CauldronEntry({cauldron: 0xC319EEa1e792577C319723b5e60a15dA3857E7da, version: 2})); // sSPELL old
        entries.push(CauldronEntry({cauldron: 0x05500e2Ee779329698DF35760bEdcAAC046e7C27, version: 2})); // FTM
        entries.push(CauldronEntry({cauldron: 0x9617b633EF905860D919b88E1d9d9a6191795341, version: 2})); // FTT bento
        entries.push(CauldronEntry({cauldron: 0x003d5A75d284824Af736df51933be522DE9Eed0f, version: 2})); // wsOHM
        entries.push(CauldronEntry({cauldron: 0x252dCf1B621Cc53bc22C256255d2bE5C8c32EaE4, version: 2})); // Shib
        entries.push(CauldronEntry({cauldron: 0xCfc571f3203756319c231d3Bc643Cee807E74636, version: 2})); // SPELL
        entries.push(CauldronEntry({cauldron: 0x3410297D89dCDAf4072B805EFc1ef701Bb3dd9BF, version: 2})); // sSPELL
        entries.push(CauldronEntry({cauldron: 0x5ec47EE69BEde0b6C2A2fC0D9d094dF16C192498, version: 2})); // wbtc
        entries.push(CauldronEntry({cauldron: 0x390Db10e65b5ab920C19149C919D970ad9d18A41, version: 2})); // weth
        entries.push(CauldronEntry({cauldron: 0x98a84EfF6e008c5ed0289655CcdCa899bcb6B99F, version: 2})); // xSUSHI
        entries.push(CauldronEntry({cauldron: 0xEBfDe87310dc22404d918058FAa4D56DC4E93f0A, version: 2})); // yvcrvIB
        entries.push(CauldronEntry({cauldron: 0x0BCa8ebcB26502b013493Bf8fE53aA2B1ED401C1, version: 2})); // yvstETH
        entries.push(CauldronEntry({cauldron: 0xf179fe36a36B32a4644587B8cdee7A23af98ed37, version: 2})); // yvCVXETH
        entries.push(CauldronEntry({cauldron: 0x920D9BD936Da4eAFb5E25c6bDC9f6CB528953F9f, version: 2})); // yvWETH v2

        entries.push(CauldronEntry({cauldron: 0xd31E19A0574dBF09310c3B06f3416661B4Dc7324, version: 3})); // stargate usdc
        entries.push(CauldronEntry({cauldron: 0xc6B2b3fE7c3D7a6f823D9106E22e66660709001e, version: 3})); // stargate usdt
        entries.push(CauldronEntry({cauldron: 0x7Ce7D9ED62B9A6c5aCe1c6Ec9aeb115FA3064757, version: 3})); // yvDAI
        entries.push(CauldronEntry({cauldron: 0x53375adD9D2dFE19398eD65BAaEFfe622760A9A6, version: 3})); // yvCurve-stETH-WETH
        entries.push(CauldronEntry({cauldron: 0x8227965A7f42956549aFaEc319F4E444aa438Df5, version: 3})); // lusd

        entries.push(CauldronEntry({cauldron: 0x94BFCDBa5C230a7c12F0869b58ccEd6C3415a392, version: 4})); // FTT new

        for (uint256 i = 0; i < entries.length; i++) {
            ICauldronV2 cauldron = ICauldronV2(entries[i].cauldron);
            IBentoBoxV1 box = IBentoBoxV1(cauldron.bentoBox());
            address boxOwner = box.owner();
            address masterContract = address(cauldron.masterContract());
            address masterContractOwner = BoringOwnable(masterContract).owner();

            vm.prank(boxOwner);
            box.whitelistMasterContract(masterContract, true);

            if (masterContractOwner != address(cauldronOwner)) {
                vm.prank(masterContractOwner);
                BoringOwnable(masterContract).transferOwnership(address(cauldronOwner), true, false);
            }
        }
    }

    function testReduceSupply() public {
        vm.startPrank(address(cauldronOwner.owner()));

        for (uint256 i = 0; i < entries.length; i++) {
            ICauldronV2 cauldron = ICauldronV2(entries[i].cauldron);
            cauldronOwner.reduceSupply(cauldron, 0);
        }

        vm.stopPrank();
    }

    function testChangeInterestRate() public {
        vm.startPrank(address(cauldronOwner.owner()));

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].version <= 2) continue;

            ICauldronV3 cauldron = ICauldronV3(entries[i].cauldron);
            (, , uint64 INTEREST_PER_SECOND) = cauldron.accrueInfo();

            assertGe(INTEREST_PER_SECOND, 0);
            cauldronOwner.changeInterestRate(cauldron, 42);

            (, , INTEREST_PER_SECOND) = cauldron.accrueInfo();
            assertEq(INTEREST_PER_SECOND, 42);
        }

        vm.stopPrank();
    }

    function testReduceCompletely() public {
        vm.startPrank(address(cauldronOwner.owner()));

        cauldronOwner.setDeprecated(entries[2].cauldron, true);

        for (uint256 i = 0; i < entries.length; i++) {
            ICauldronV2 cauldron = ICauldronV2(entries[i].cauldron);

            if (i == 2) {
                cauldronOwner.reduceCompletely(cauldron);
            } else {
                vm.expectRevert(abi.encodeWithSignature("ErrNotDeprecated(address)", address(cauldron)));
                cauldronOwner.reduceCompletely(cauldron);
            }
        }

        vm.stopPrank();
    }
}
