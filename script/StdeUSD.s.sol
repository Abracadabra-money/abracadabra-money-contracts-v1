// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from "@BoringSolidity/interfaces/IERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import "utils/BaseScript.sol";

import {CauldronDeployLib} from "utils/CauldronDeployLib.sol";
import {IAggregator} from "/interfaces/IAggregator.sol";
import {IBentoBoxV1} from "/interfaces/IBentoBoxV1.sol";
import {ProxyOracle} from "/oracles/ProxyOracle.sol";
import {IOracle} from "/interfaces/IOracle.sol";
import {ISwapperV2} from "/interfaces/ISwapperV2.sol";
import {ILevSwapperV2} from "/interfaces/ILevSwapperV2.sol";
import {ChainlinkOracle} from "/oracles/ChainlinkOracle.sol";
import {InverseOracle} from "/oracles/InverseOracle.sol";

contract StdeUSDScript is BaseScript {
    address collateral;
    address mim;
    address box;
    address safe;
    address masterContract;
    address zeroXExchangeProxy;

    function deploy() public {
        mim = toolkit.getAddress("mim");
        box = toolkit.getAddress("degenBox");
        collateral = 0x5C5b196aBE0d54485975D1Ec29617D42D9198326;
        safe = toolkit.getAddress("safe.ops");
        masterContract = toolkit.getAddress("cauldronV4");
        zeroXExchangeProxy = toolkit.getAddress("aggregators.zeroXExchangeProxy");

        vm.startBroadcast();
        _deploy(
            "StdeUSD",
            18,
            0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9,
            8500, // 85% LTV
            690, // 6.9% Interests
            50, // 0.5% Opening Fee
            750 // 7.5% Liquidation Fee
        );

        vm.stopBroadcast();
    }

    function _deploy(
        string memory name,
        uint8 /*collateralDecimals*/,
        address chainlinkAggregator,
        uint256 ltv,
        uint256 interests,
        uint256 openingFee,
        uint256 liquidationFee
    ) private {
        ProxyOracle oracle = ProxyOracle(deploy(string.concat(name, "_ProxyOracle"), "ProxyOracle.sol:ProxyOracle"));
        IOracle impl = IOracle(
            deploy(
                string.concat(name, "_ERC4626_ChainlinkOracle"),
                "ERC4626Oracle.sol:ERC4626Oracle",
                abi.encode(string.concat(name, "/USD"), collateral, chainlinkAggregator)
            )
        );

        if (oracle.oracleImplementation() != impl) {
            oracle.changeOracleImplementation(impl);
        }

        CauldronDeployLib.deployCauldronV4(
            string.concat("Cauldron_", name),
            IBentoBoxV1(box),
            masterContract,
            IERC20(collateral),
            IOracle(address(oracle)),
            "",
            ltv,
            interests,
            openingFee,
            liquidationFee
        );

        if (!testing()) {
            if (Owned(address(oracle)).owner() != safe) {
                Owned(address(oracle)).transferOwnership(safe);
            }
        }
    }
}
