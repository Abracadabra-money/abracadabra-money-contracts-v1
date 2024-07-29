// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@BoringSolidity/ERC20.sol";
import "utils/BaseScript.sol";
import "/interfaces/IBentoBoxV1.sol";
import "/cauldrons/CauldronV4.sol";

contract CauldronV4Script is BaseScript {
    function deploy() public {
        IBentoBoxV1 degenBox = IBentoBoxV1(toolkit.getAddress(block.chainid, "degenBox"));
        address withdrawer = toolkit.getAddress(block.chainid, "cauldronFeeWithdrawer");
        address cauldronOwner = toolkit.getAddress(ChainId.All, "cauldronOwner");
        ERC20 mim = ERC20(toolkit.getAddress(block.chainid, "mim"));

        vm.startBroadcast();
        CauldronV4 cauldronV4MC = CauldronV4(deploy("CauldronV4", "CauldronV4.sol:CauldronV4", abi.encode(degenBox, mim)));

        if (!testing()) {
            if (cauldronV4MC.owner() == tx.origin) {
                if (cauldronV4MC.feeTo() != withdrawer) {
                    cauldronV4MC.setFeeTo(withdrawer);
                }
                cauldronV4MC.transferOwnership(cauldronOwner);
            }
        }
        vm.stopBroadcast();
    }
}
