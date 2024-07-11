// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWormholeRelayer} from "@wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";

/**
 * @title DontBridge
 * @dev This contract is a simple contract that allows users to deposit and lock funds into it,
 * then emit a message to the target chain using wormhole confirming the deposit, which will then
 * unlock the equivalent amount of funds on the target chain from the pool.
 * @author github.com/JovanMwesigwa
 */
contract DontBridge {
    error DontBridge__NotEnoughFunds();
    error DontBridge__UserNotFound();
    error DontBridge__UserExists();
    error DontBridge__InvalidArguments();

    event DepositedFunds(address indexed userAddress, uint256 indexed amount);

    event SentFunds(
        address indexed userAddress,
        uint256 indexed amount,
        uint256 indexed targetChainId
    );

    event RepaidFunds(
        address indexed userAddress,
        uint256 indexed amount,
        uint256 indexed targetChainId
    );

    event WithdrawnFunds(address indexed userAddress, uint256 indexed amount);

    IWormholeRelayer public immutable i_wormholeRelayer;

    // Wormhole variables
    uint256 constant GAS_LIMIT = 100_000; // Increase this value

    constructor(address wormholeRelayerAddress) {
        i_wormholeRelayer = IWormholeRelayer(wormholeRelayerAddress);
    }

    // struct Ticker {
    //     string name;
    //     string sourceAsset;
    //     string targetAsset;
    //     uint256 price;
    // }

    struct UserAccount {
        address userAddress;
        address targetAccountAddress;
        uint256 targetChainId;
        uint256 amount;
        string tiker; // Will be changed to a struct of the token details and prices
    }

    mapping(address user => UserAccount) private userAccounts;

    // mapping(address user => Ticker) private tickers;

    /**
     * @dev Deposits Ether into the contract.
     *
     * Emits a {Deposited} event.
     *
     * Requirements:
     *
     * - `msg.value` must be greater than 0.
     *
     * Todo: Emit a message to the target chain using wormhole confirming the deposit.
     */
    function sourceChainDeposit(
        address _targetAccountAddress,
        string memory _ticker,
        uint256 _targetChainId,
        uint16 s_wormholeTargetChain,
        address s_receiverContractAddress
    ) external payable {
        if (msg.value <= 0) {
            revert DontBridge__NotEnoughFunds();
        }

        uint256 cost = getCrossChainQuote(s_wormholeTargetChain);

        // Todo: Check if the user has enough funds to pay for the cross chain message

        // Validate the ticker to make sure dontBridge supports it
        // Todo: Add a ticker struct and validate the ticker

        userAccounts[msg.sender] = UserAccount({
            userAddress: msg.sender,
            targetAccountAddress: _targetAccountAddress,
            targetChainId: _targetChainId,
            amount: msg.value,
            tiker: _ticker
        });

        // Emit a message to the target chain using wormhole confirming the deposit.
        // This will unlock the equivalent amount of funds on the target chain from the pool.
        // Encode / Hide the message which is an instance of the userAccount struct
        bytes memory payload = abi.encode(userAccounts[msg.sender], msg.sender);

        uint16 refundChain = 10005; // Todo: Make it dynamic to come from the source chain it's deployed to

        address refundAddress = address(this);

        i_wormholeRelayer.sendPayloadToEvm{value: cost}(
            s_wormholeTargetChain,
            s_receiverContractAddress,
            payload,
            0,
            GAS_LIMIT,
            refundChain,
            refundAddress
        );

        emit DepositedFunds(msg.sender, msg.value);
    }

    /**
     * @dev Receives the message from the target chain confirming the deposit. and unlocks the equivalent amount of funds on the target chain from the pool.
     * Todo: This function will be called by the wormhole contract on the target chain.
     * So add a modifier to check if the caller is the wormhole contract.
     */
    function targetChainSendFunds(
        address _sourceUserAccount,
        address targetAccount,
        uint256 amount,
        string memory ticker,
        uint256 sourceChain
    ) external payable {
        // // Check if the userAccount exists
        // if (userAccounts[_sourceUserAccount].userAddress == address(0)) {
        //     revert DontBridge__UserExists();
        // }

        // TODO: Validate the ticker to make sure dontBridge supports it

        if (amount <= 0) {
            revert DontBridge__NotEnoughFunds();
        }

        // Pay the user the amount of funds they deposited
        payable(targetAccount).transfer(amount);

        // Create a new UserAccount object to store the user's details
        UserAccount memory userAccount = UserAccount({
            userAddress: _sourceUserAccount,
            targetAccountAddress: targetAccount,
            targetChainId: sourceChain,
            amount: amount,
            tiker: ticker
        });

        // Add the user's account to the userAccounts mapping
        userAccounts[userAccount.userAddress] = userAccount;

        // Update the user's account to reflect the amount of funds they have withdrawn
        userAccounts[userAccount.userAddress].amount = 0;

        emit SentFunds(
            userAccount.userAddress,
            amount,
            userAccount.targetChainId
        );
    }

    /**
     * @dev This function allows the user to repay the funds they have withdrawn from the pool.
     * After the user has repaid the funds, the user's account will be deleted from the userAccounts mapping.
     * And send a message to the source chain confirming the repayment, which will then unlock the equivalent amount of funds on the source chain from the pool.
     */
    function targetChainRepayFunds() external payable {
        UserAccount memory userAccount = userAccounts[msg.sender];

        // Check if the userAccount exists
        if (userAccount.userAddress == address(0)) {
            revert DontBridge__UserNotFound();
        }

        uint256 amount = msg.value;

        // Todo: Validate the ticker to make sure dontBridge supports it

        // Pay the user the amount of funds they deposited
        payable(userAccount.userAddress).transfer(amount);

        // Update the user's account to reflect the amount of funds they have withdrawn
        userAccounts[userAccount.userAddress].amount = amount;

        // Todo: Emit a message to the source chain using wormhole confirming the repayment.

        // Only delete the user's account if the user has repaid the full amount
        if (userAccount.amount == 0) {
            delete userAccounts[userAccount.userAddress];
        }

        emit RepaidFunds(
            userAccount.userAddress,
            amount,
            userAccount.targetChainId
        );
    }

    /**
     * @dev Withdraws Ether from the contract.
     *
     * Requirements:
     *
     * - `amount` must be greater than 0.
     * - `amount` must be less than or equal to the user's deposits.
     *
     * Todo: Emit a message to the target chain using wormhole confirming the withdrawal.
     * Todo: Add a modifier so that only the withdraw happens only if the message is confirmed on the target chain.
     */
    function sourceChainWithdraw() external {
        UserAccount memory userAccount = userAccounts[msg.sender];

        if (userAccount.userAddress == address(0)) {
            revert DontBridge__UserNotFound();
        }

        if (
            userAccount.amount <= 0 ||
            userAccount.amount > address(this).balance
        ) {
            revert DontBridge__NotEnoughFunds();
        }

        payable(msg.sender).transfer(userAccount.amount);

        delete userAccounts[msg.sender];

        emit WithdrawnFunds(msg.sender, userAccount.amount);
    }

    //  WORMHOLE FUNCTIONS
    function getCrossChainQuote(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = i_wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
        return cost;
    }

    // View / Pure functions
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserDeposits(address user) public view returns (uint256) {
        return userAccounts[user].amount;
    }

    function getUserAccount(
        address user
    ) public view returns (UserAccount memory) {
        return userAccounts[user];
    }

    // function getUserTickers(address user) public view returns (Ticker memory) {
    //     return tickers[user];
    // }
}
