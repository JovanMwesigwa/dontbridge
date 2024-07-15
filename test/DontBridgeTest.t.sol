// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {DeployDontBridge} from "../script/DeployDontBridge.s.sol";
import {DontBridge} from "../src/DontBridge.sol";

contract DontBridgeTest is Test {
    DontBridge public dontBridge;

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant USER_STARTING_BALANCE = 10 ether;

    address public targetAccountAddress = address(2);
    uint256 public targetChainId = 2567;
    uint16 wormeholeTargetChainId = 10005;

    // Optimism vars
    uint16 public wormholeTargetChainId = 10005;
    address public targetChainAddress = address(3);
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
        dontBridge.sourceChainDeposit{value: 0}(
            targetAccountAddress,
            targetTicker,
            10005,
            wormholeTargetChainId,
            targetChainAddress
        );
        vm.stopPrank();
    }

    function testDepositFundsSuccessfully() external {
        vm.startPrank(USER);
        dontBridge.sourceChainDeposit{value: DEPOSIT_AMOUNT}(
            targetAccountAddress,
            targetTicker,
            wormeholeTargetChainId,
            wormholeTargetChainId,
            targetChainAddress
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
        dontBridge.sourceChainWithdraw();
        vm.stopPrank();
    }

    function testWithdrawFundsSuccessfully() external {
        vm.startPrank(USER);
        dontBridge.sourceChainDeposit{value: DEPOSIT_AMOUNT}(
            targetAccountAddress,
            targetTicker,
            wormeholeTargetChainId,
            wormholeTargetChainId,
            targetChainAddress
        );
        vm.stopPrank();

        vm.startPrank(USER);
        dontBridge.sourceChainWithdraw();
        vm.stopPrank();

        // Check that the user's deposit has been updated
        uint256 userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            0,
            "User deposit balance should be equal to 0 after withdrawal"
        );
    }

    function testTargetChainWithdraw() external {
        vm.startPrank(USER);
        dontBridge.sourceChainDeposit{value: DEPOSIT_AMOUNT}(
            targetAccountAddress,
            targetTicker,
            wormeholeTargetChainId,
            wormholeTargetChainId,
            targetChainAddress
        );
        vm.stopPrank();

        // Check that the user's deposit has been updated
        uint256 userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            DEPOSIT_AMOUNT,
            "User deposit balance should be equal to the deposit amount"
        );

        // Withdraw funds from the funds to the user on the target chain
        // dontBridge.targetChainSendFunds(
        //     address(USER),
        //     targetAccountAddress,
        //     DEPOSIT_AMOUNT,
        //     targetTicker,
        //     targetChainId
        // );

        // Check that the user's deposit has been updated
        userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            0,
            "User deposit balance should be equal to 0 after withdrawal"
        );
    }

    function testTargetChainRepayFunds() external {
        vm.startPrank(USER);
        dontBridge.sourceChainDeposit{value: DEPOSIT_AMOUNT}(
            targetAccountAddress,
            targetTicker,
            wormeholeTargetChainId,
            wormholeTargetChainId,
            targetChainAddress
        );
        vm.stopPrank();

        // Check that the user's deposit has been updated
        uint256 userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            DEPOSIT_AMOUNT,
            "User deposit balance should be equal to the deposit amount"
        );

        vm.startPrank(USER);
        // Repay funds to the user on the target chain
        dontBridge.targetChainRepayFunds{value: DEPOSIT_AMOUNT}();
        vm.stopPrank();

        // Check that the user's deposit has been updated
        userDepositBalance = dontBridge.getUserDeposits(address(USER));

        assertEq(
            userDepositBalance,
            0,
            "User deposit balance should be equal to 0 after repayment"
        );
    }
}
