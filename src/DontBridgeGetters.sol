// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DontBridgeGetters {
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
