// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseTest.sol";
import "script/GmxV2.s.sol";
import "solady/utils/SafeTransferLib.sol";
import "./utils/CauldronTestLib.sol";
import "./mocks/ExchangeRouterMock.sol";

contract GmxV2Test is BaseTest {
    using SafeTransferLib for address;

    IGmCauldronOrderAgent orderAgent;
    GmxV2Script.MarketDeployment gmETHDeployment;
    GmxV2Script.MarketDeployment gmBTCDeployment;
    GmxV2Script.MarketDeployment gmARBDeployment;

    address constant GM_BTC_WHALE = 0x8d16D32f785D0B11fDa5E443FCC39610f91a50A8;
    address constant GM_ETH_WHALE = 0xA329Ac2efFFea563159897d7828866CFaeD42167;
    address constant GM_ARB_WHALE = 0x8E52cA5A7a9249431F03d60D79DDA5EAB4930178;
    address constant MIM_WHALE = 0x27807dD7ADF218e1f4d885d54eD51C70eFb9dE50;

    address gmBTC;
    address gmETH;
    address gmARB;
    address usdc;
    address mim;
    address masterContract;
    IBentoBoxV1 box;
    ExchangeRouterMock exchange;

    function setUp() public override {
        fork(ChainId.Arbitrum, 139685420);
        super.setUp();

        GmxV2Script script = new GmxV2Script();
        script.setTesting(true);

        (masterContract, orderAgent, gmETHDeployment, gmBTCDeployment, gmARBDeployment) = script.deploy();

        box = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        mim = toolkit.getAddress(block.chainid, "mim");
        gmBTC = toolkit.getAddress(block.chainid, "gmx.v2.gmBTC");
        gmETH = toolkit.getAddress(block.chainid, "gmx.v2.gmETH");
        gmARB = toolkit.getAddress(block.chainid, "gmx.v2.gmARB");
        usdc = toolkit.getAddress(block.chainid, "usdc");

        exchange = new ExchangeRouterMock(ERC20(address(0)), ERC20(address(0)));
        
        // Alice just made it
        deal(usdc, alice, 100_000e6);
        pushPrank(GM_BTC_WHALE);
        gmBTC.safeTransfer(alice, 100_000 ether);
        popPrank();
        pushPrank(GM_ETH_WHALE);
        gmETH.safeTransfer(alice, 100_000 ether);
        popPrank();
        pushPrank(GM_ARB_WHALE);
        gmARB.safeTransfer(alice, 100_000 ether);
        popPrank();

        // put 1m mim inside the cauldrons
        pushPrank(MIM_WHALE);
        mim.safeTransfer(address(box), 3_000_000e18);
        popPrank();

        box.deposit(IERC20(mim), address(box), address(gmETHDeployment.cauldron), 1_000_000e18, 0);
        box.deposit(IERC20(mim), address(box), address(gmBTCDeployment.cauldron), 1_000_000e18, 0);
        box.deposit(IERC20(mim), address(box), address(gmARBDeployment.cauldron), 1_000_000e18, 0);

        pushPrank(box.owner());
        box.whitelistMasterContract(masterContract, true);
        popPrank();
    }

    function testOracles() public {
        uint256 price;

        console2.log("=== gmETH OraclePrice ===");
        (, price) = gmETHDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1089611872333813650);

        console2.log("=== gmBTC OraclePrice ===");
        (, price) = gmBTCDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1008339991773323838);

        console2.log("=== gmARB OraclePrice ===");
        (, price) = gmARBDeployment.oracle.peek(bytes(""));
        console2.log("price", price);
        assertEq(price, 1189214556682150869);
    }

    /// Borrow: GM token --> MIM
    function testUnleveragedBorrow() public {
        vm.startPrank(alice);
        CauldronTestLib.depositAndBorrow(box, gmETHDeployment.cauldron, masterContract, IERC20(gmETH), alice, 10_000 ether, 50);
        vm.stopPrank();
    }

    /// LeveragedBorrow: GMToken -> MIM -> USDC (using levSwapper) -> ACTION_CREATE_ORDER(using USDC) -> (⌛️ GMX Callback) -> GMToken
    function testLeverageBorrow() public {
        //exchange.setTokens(IERC20(mim), IERC20(usdc));
        
        vm.startPrank(alice);
       // CauldronTestLib.depositAndLeverage(box, gmETHDeployment.cauldron, masterContract, leverageSwapper, IERC20(gmETH), alice, 10_000 ether, 50);
        vm.stopPrank();
    }
}
