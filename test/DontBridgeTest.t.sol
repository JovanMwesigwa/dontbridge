// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

import {DeployDontBridge} from "../script/DeployDontBridge.s.sol";
import {DontBridge} from "../src/DontBridge.sol";

contract DontBridgeTest is Test {
    DontBridge public dontBridge;

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant USER_STARTING_BALANCE = 10 ether;

    address public targetAddress = address(0x123);
    uint256 public targetChainId = 2567;
    string public targetTicker = "ETH/SOL";

    address public USER;

    function setUp() external {
        USER = address(0x123);
        DeployDontBridge deployer = new DeployDontBridge();

        dontBridge = deployer.deploy();

        vm.deal(USER, USER_STARTING_BALANCE);
    }

    function testDepositFundsFailsWhenAmountIsZero() external {
        vm.expectRevert(DontBridge.DontBridge__NotEnoughFunds.selector);

        vm.startPrank(USER);
        dontBridge.depositFunds{value: 0}(
            targetAddress,
            targetTicker,
            targetChainId
        );
        vm.stopPrank();
    }

    function testDepositFundsSuccessfully() external {
        vm.startPrank(USER);
        dontBridge.depositFunds{value: DEPOSIT_AMOUNT}(
            targetAddress,
            targetTicker,
            targetChainId
        );
        vm.stopPrank();

        // Check that the user's deposit has been updated
        uint256 userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            DEPOSIT_AMOUNT,
            "User deposit balance should be equal to the deposit amount"
        );
    }

    function testWithdrawFundsFailsWhenUserHasNotDeposited() external {
        vm.expectRevert(DontBridge.DontBridge__UserNotFound.selector);

        vm.startPrank(USER);
        dontBridge.withdrawFunds();
        vm.stopPrank();
    }

    function testWithdrawFundsSuccessfully() external {
        vm.startPrank(USER);
        dontBridge.depositFunds{value: DEPOSIT_AMOUNT}(
            targetAddress,
            targetTicker,
            targetChainId
        );
        vm.stopPrank();

        vm.startPrank(USER);
        dontBridge.withdrawFunds();
        vm.stopPrank();

        // Check that the user's deposit has been updated
        uint256 userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            0,
            "User deposit balance should be equal to 0 after withdrawal"
        );
    }
}
