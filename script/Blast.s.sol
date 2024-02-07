// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {IDegenBoxBlast} from "mixins/DegenBoxBlast.sol";

contract BlastScript is BaseScript {
    function deploy() public returns (address blastBox) {
        vm.startBroadcast();
        blastBox = deploy("DegenBoxBlast", "DegenBoxBlast.sol:DegenBoxBlast", abi.encode(toolkit.getAddress(ChainId.Blast, "weth")));
        IDegenBoxBlast(blastBox).setTokenYieldEnabled(toolkit.getAddress(ChainId.Blast, "weth"), true);
        IDegenBoxBlast(blastBox).setTokenYieldEnabled(toolkit.getAddress(ChainId.Blast, "usdb"), true);
        vm.stopBroadcast(); 
    }
}
