// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DontBridge} from "../src/DontBridge.sol";

contract DeployDontBridge is Script {
    function deploy() public returns (DontBridge) {
        vm.startBroadcast();
        DontBridge dontBridge = new DontBridge();
        vm.stopBroadcast();

        return dontBridge;
    }

    function run() external returns (DontBridge) {
        return deploy();
    }
}
