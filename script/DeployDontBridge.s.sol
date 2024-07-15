// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DontBridge} from "../src/DontBridge.sol";

contract DeployDontBridge is Script {
    // address public s_wormholeAddress =
    //     address(0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470); // Arbitrum

    address public s_wormholeAddress =
        address(0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE); // Optimism

    function deploy() public returns (DontBridge) {
        vm.startBroadcast();
        DontBridge dontBridge = new DontBridge(s_wormholeAddress);
        vm.stopBroadcast();

        return dontBridge;
    }

    function run() external returns (DontBridge) {
        return deploy();
    }
}
