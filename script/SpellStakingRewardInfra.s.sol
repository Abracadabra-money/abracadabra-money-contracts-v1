// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "utils/BaseScript.sol";
import "utils/LayerZeroLib.sol";
import "periphery/CauldronFeeWithdrawer.sol";
import "periphery/SpellStakingRewardDistributor.sol";
import "mixins/Create3Factory.sol";
import "solmate/utils/CREATE3.sol";
import "forge-std/console2.sol";

contract SpellStakingRewardInfraScript is BaseScript {
    using DeployerFunctions for Deployer;

    string constant DEFAULT_CAULDRON_FEE_WITHDRAWER_SALT = "CAULDRON_FEE_WITHDRAWER_SALT";
    string constant DEFAULT_SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = "SPELL_STAKING_REWARD_DISTRIBUTOR_SALT";

    // CREATE3 salts
    bytes32 CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes(DEFAULT_CAULDRON_FEE_WITHDRAWER_SALT));
    bytes32 SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = keccak256(bytes(DEFAULT_SPELL_STAKING_REWARD_DISTRIBUTOR_SALT));

    function deploy() public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        // Salt should be set before deployment in .env file and kept secret to avoid front-running futur chain deployments
        if (!testing) {
            CAULDRON_FEE_WITHDRAWER_SALT = keccak256(bytes(vm.envString("CAULDRON_FEE_WITHDRAWER_SALT")));
            SPELL_STAKING_REWARD_DISTRIBUTOR_SALT = keccak256(bytes(vm.envString("SPELL_STAKING_REWARD_DISTRIBUTOR_SALT")));
        }

        deployer.setAutoBroadcast(false);

        Create3Factory factory = Create3Factory(constants.getAddress(block.chainid, "create3Factory"));
        IERC20 mim = IERC20(constants.getAddress(block.chainid, "mim"));
        address safe = constants.getAddress(block.chainid, "safe.ops");
        address mimProvider = constants.getAddress(block.chainid, "safe.main");

        startBroadcast();

        if (block.chainid == ChainId.Mainnet) {
            (withdrawer, distributor) = _deployMainnet(factory, mim, safe, mimProvider);
        } else if (block.chainid == ChainId.Avalanche) {
            withdrawer = _deployAvalanche(factory, mim, safe, mimProvider);
        } else if (block.chainid == ChainId.Arbitrum) {
            //return _deployArbitrum();
        } else if (block.chainid == ChainId.BSC) {
            //return _deployBsc();
        } else if (block.chainid == ChainId.Optimism) {
            //return _deployOptimism();
        } else if (block.chainid == ChainId.Fantom) {
            //return _deployFantom();
        } else {
            revert("SpellStakingStackScript: unsupported chain");
        }

        if (!testing) {
            CauldronInfo[] memory cauldronInfos = constants.getCauldrons(constants.getChainName(block.chainid), true);
            address[] memory cauldrons = new address[](cauldronInfos.length);
            uint8[] memory versions = new uint8[](cauldronInfos.length);
            bool[] memory enabled = new bool[](cauldronInfos.length);

            for (uint256 i = 0; i < cauldronInfos.length; i++) {
                CauldronInfo memory cauldronInfo = cauldronInfos[i];
                cauldrons[i] = cauldronInfo.cauldron;
                versions[i] = cauldronInfo.version;
                enabled[i] = true;
            }

            withdrawer.setCauldrons(cauldrons, versions, enabled);
            withdrawer.transferOwnership(safe);
        }

        stopBroadcast();
    }

    function _deployMainnet(
        Create3Factory factory,
        IERC20 mim,
        address safe,
        address mimProvider
    ) public returns (CauldronFeeWithdrawer withdrawer, SpellStakingRewardDistributor distributor) {
        if (deployer.has("Mainnet_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Mainnet_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                factory.deploy(
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    abi.encodePacked(
                        type(CauldronFeeWithdrawer).creationCode,
                        abi.encode(signer(), mim, ILzOFTV2(constants.getAddress(block.chainid, "oftv2"))) // Mainnet LzOFTV2 Proxy
                    ),
                    0
                )
            );
        }

        if (deployer.has("Mainnet_SpellStakingRewardDistributor")) {
            distributor = SpellStakingRewardDistributor(deployer.getAddress("Mainnet_SpellStakingRewardDistributor"));
        } else {
            distributor = SpellStakingRewardDistributor(
                factory.deploy(
                    SPELL_STAKING_REWARD_DISTRIBUTOR_SALT,
                    abi.encodePacked(type(SpellStakingRewardDistributor).creationCode, abi.encode(signer())),
                    0
                )
            );
        }

        console2.log("deployer.deploy_CauldronFeeWithdrawer", address(withdrawer));
        console2.log("deployer.deploy_SpellStakingRewardDistributor", address(distributor));

        withdrawer.setParameters(mimProvider, address(0), address(distributor), ICauldronFeeWithdrawReporter(address(0)));

        // for gelato web3 functions
        withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);
        distributor.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox")), true);

        // SPELL buyback for sSPELL staking
        distributor.setParameters(0xdFE1a5b757523Ca6F7f049ac02151808E6A52111, safe, 50); // InchSpellSwapper

        // mSpellStaking contracts
        bool active;
        (active, ) = distributor.chainInfo(ChainId.Mainnet);
        if (!active) {
            distributor.addMSpellRecipient(0xbD2fBaf2dc95bD78Cf1cD3c5235B33D1165E6797, ChainId.Mainnet, LayerZeroChainId.Mainnet);
        }
        (active, ) = distributor.chainInfo(ChainId.Avalanche);
        if (!active) {
            distributor.addMSpellRecipient(0xBd84472B31d947314fDFa2ea42460A2727F955Af, ChainId.Avalanche, LayerZeroChainId.Avalanche);
        }
        (active, ) = distributor.chainInfo(ChainId.Arbitrum);
        if (!active) {
            distributor.addMSpellRecipient(0x1DF188958A8674B5177f77667b8D173c3CdD9e51, ChainId.Arbitrum, LayerZeroChainId.Arbitrum);
        }
        (active, ) = distributor.chainInfo(ChainId.Fantom);
        if (!active) {
            distributor.addMSpellRecipient(0xa668762fb20bcd7148Db1bdb402ec06Eb6DAD569, ChainId.Fantom, LayerZeroChainId.Fantom);
        }

        // determinstic addresses, can set before others are added
        if (distributor.mSpellReporter(LayerZeroChainId.Avalanche).length == 0) {
            distributor.addReporter(LayerZeroLib.getRecipient(address(withdrawer), address(distributor)), LayerZeroChainId.Avalanche);
        }
        if (distributor.mSpellReporter(LayerZeroChainId.Arbitrum).length == 0) {
            distributor.addReporter(LayerZeroLib.getRecipient(address(withdrawer), address(distributor)), LayerZeroChainId.Arbitrum);
        }
        if (distributor.mSpellReporter(LayerZeroChainId.Fantom).length == 0) {
            distributor.addReporter(LayerZeroLib.getRecipient(address(withdrawer), address(distributor)), LayerZeroChainId.Fantom);
        }

        if (!testing) {
            // feeTo override
            // Handle the fees independently for these two cauldrons by redirecting to ops safe
            withdrawer.setFeeToOverride(0x7d8dF3E4D06B0e19960c19Ee673c0823BEB90815, safe);
            withdrawer.setFeeToOverride(0x207763511da879a900973A5E092382117C3c1588, safe);

            if (distributor.owner() != safe) {
                distributor.transferOwnership(safe);
            }
        }
    }

    function _deployAvalanche(
        Create3Factory factory,
        IERC20 mim,
        address safe,
        address mimProvider
    ) public returns (CauldronFeeWithdrawer withdrawer) {
        IERC20 spell = IERC20(constants.getAddress(block.chainid, "spell"));
        address mSpell = constants.getAddress(block.chainid, "mSpell");

        if (deployer.has("Avalanche_CauldronFeeWithdrawer")) {
            withdrawer = CauldronFeeWithdrawer(deployer.getAddress("Avalanche_CauldronFeeWithdrawer"));
        } else {
            withdrawer = CauldronFeeWithdrawer(
                factory.deploy(
                    CAULDRON_FEE_WITHDRAWER_SALT,
                    abi.encodePacked(
                        type(CauldronFeeWithdrawer).creationCode,
                        abi.encode(signer(), mim, ILzOFTV2(0xB3a66127cCB143bFB01D3AECd3cE9D17381B130d)) // Avalanche LzOFTV2 IndirectProxy
                    ),
                    0
                )
            );
        }

        console2.log("deployer.deploy_CauldronFeeWithdrawer", address(withdrawer));

        ICauldronFeeWithdrawReporter stakedAmountReporter = ICauldronFeeWithdrawReporter(
            deployer.deploy_DefaultCauldronFeeWithdrawerReporter(
                "Avalanche_MSpellStakedAmountReporter",
                IERC20(constants.getAddress(block.chainid, "spell")),
                constants.getAddress(block.chainid, "mSpell")
            )
        );

        address mainnetDistributor;
        if (!testing) {
            mainnetDistributor = vm.envAddress("MAINNET_DISTRIBUTOR");
            console2.log("Using MAINNET_DISTRIBUTOR", mainnetDistributor);
        }

        withdrawer.setParameters(mimProvider, mainnetDistributor, address(withdrawer), stakedAmountReporter);
        withdrawer.setOperator(constants.getAddress(block.chainid, "safe.devOps.gelatoProxy"), true);

        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox1")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress(block.chainid, "degenBox2")), true);
    }

    /*
    function _deployArbitrum(        Create3Factory factory,
        IERC20 mim,
        address safe,
        address mimProvider) public returns (CauldronFeeWithdrawer withdrawer) {

        withdrawer = new CauldronFeeWithdrawer(mim);
        withdrawer.setBridgeableToken(mim, true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("arbitrum.sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("arbitrum.degenBox")), true);

        AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
            IAnyswapRouter(constants.getAddress("arbitrum.anyswapRouterV4")),
            constants.getAddress("mainnet.cauldronFeeWithdrawer"),
            1
        );
        bridger.setOperator(address(withdrawer), true);
        withdrawer.setParameters(address(0), mimProvider, bridger);

        CauldronInfo[] memory cauldronInfos = constants.getCauldrons("arbitrum", true);
        address[] memory cauldrons = new address[](cauldronInfos.length);
        uint8[] memory versions = new uint8[](cauldronInfos.length);
        bool[] memory enabled = new bool[](cauldronInfos.length);

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo memory cauldronInfo = cauldronInfos[i];

            cauldrons[i] = cauldronInfo.cauldron;
            versions[i] = cauldronInfo.version;
            enabled[i] = true;
        }

        withdrawer.setCauldrons(cauldrons, versions, enabled);

        mSpellReporter reporter = new mSpellReporter(
            ILzEndpoint(constants.getAddress("arbitrum.LZendpoint")),
            IERC20(constants.getAddress("arbitrum.spell")),
            constants.getAddress("arbitrum.mspell"),
            safe
        );

        if (!testing) {
            withdrawer.transferOwnership(safe, true, false);
            bridger.transferOwnership(safe, true, false);
            reporter.transferOwnership(safe, true, false);
        }
    }

    function _deployFantom(        Create3Factory factory,
        IERC20 mim,
        address safe,
        address mimProvider) public returns (CauldronFeeWithdrawer withdrawer) {

        withdrawer = new CauldronFeeWithdrawer(mim);
        withdrawer.setBridgeableToken(mim, true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("fantom.sushiBentoBox")), true);
        withdrawer.setBentoBox(IBentoBoxV1(constants.getAddress("fantom.degenBox")), true);

        AnyswapCauldronFeeBridger bridger = new AnyswapCauldronFeeBridger(
            IAnyswapRouter(constants.getAddress("fantom.anyswapRouterV4")),
            constants.getAddress("mainnet.cauldronFeeWithdrawer"),
            1
        );
        bridger.setOperator(address(withdrawer), true);
        withdrawer.setParameters(address(0), mimProvider, bridger);

        if (!testing) {
            CauldronInfo[] memory cauldronInfos = constants.getCauldrons("fantom", true);
            address[] memory cauldrons = new address[](cauldronInfos.length);
            uint8[] memory versions = new uint8[](cauldronInfos.length);
            bool[] memory enabled = new bool[](cauldronInfos.length);

            for (uint256 i = 0; i < cauldronInfos.length; i++) {
                CauldronInfo memory cauldronInfo = cauldronInfos[i];

                cauldrons[i] = cauldronInfo.cauldron;
                versions[i] = cauldronInfo.version;
                enabled[i] = true;
            }
            withdrawer.setCauldrons(cauldrons, versions, enabled);
        }

        mSpellReporter reporter = new mSpellReporter(
            ILzEndpoint(constants.getAddress("fantom.LZendpoint")),
            IERC20(constants.getAddress("fantom.spell")),
            constants.getAddress("fantom.mspell"),
            safe
        );

        // Only when deploying live
        if (!testing) {
            withdrawer.transferOwnership(safe, true, false);
            bridger.transferOwnership(safe, true, false);
            reporter.transferOwnership(safe, true, false);
        }
    }
*/
}
