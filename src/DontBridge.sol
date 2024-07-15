// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWormholeRelayer} from "@wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import {IWormholeReceiver} from "@wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import {DontBridgeGetters} from "./DontBridgeGetters.sol";
import {IWormhole} from "@wormhole-solidity-sdk/interfaces/IWormhole.sol";

/**
 * @title DontBridge
 * @dev This contract is a simple contract that allows users to deposit and lock funds into it,
 * then emit a message to the target chain using wormhole confirming the deposit, which will then
 * unlock the equivalent amount of funds on the target chain from the pool.
 * @author github.com/JovanMwesigwa
 */
contract DontBridge is DontBridgeGetters, IWormholeReceiver {
    error DontBridge__NotEnoughFunds();
    error DontBridge__UserNotFound();
    error DontBridge__UserExists();
    error DontBridge__InvalidArguments();
    error DontBridge__NotAllowed();

    event DepositedFunds(address indexed userAddress, uint256 indexed amount);

    event SentFunds(
        address indexed userAddress,
        uint256 indexed amount,
        uint256 indexed targetChainId,
        uint16 sourceChain
    );

    event RepaidFunds(
        address indexed userAddress,
        uint256 indexed amount,
        uint256 indexed targetChainId
    );

    event WithdrawnFunds(address indexed userAddress, uint256 indexed amount);

    event GasUsage(string message, uint256 gasLeft);

    IWormholeRelayer public immutable i_wormholeRelayer;

    // Wormhole variables
    uint256 constant GAS_LIMIT = 100_000; // Increase this value
    address public s_owner;

    string public latestMessage;

    constructor(address wormholeRelayerAddress) {
        i_wormholeRelayer = IWormholeRelayer(wormholeRelayerAddress);
        s_owner = msg.sender;
    }

    struct UserAccount {
        address userAddress;
        address targetAccountAddress;
        uint256 amount;
    }

    struct DestinationMessage {
        address userAddress;
        uint256 amount;
        string ticker;
    }

    mapping(address user => UserAccount) private userAccounts;

    // mapping(address user => Ticker) private tickers;

    //  ########################################################################################
    //  ###############               SOURCE CHAIN FUNCTIONS                    ################
    //  ########################################################################################

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
        uint16 _refundChainId,
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
            amount: msg.value
        });

        // Emit a message to the target chain using wormhole confirming the deposit.
        // This will unlock the equivalent amount of funds on the target chain from the pool.
        // Encode / Hide the message which is an instance of the userAccount struct
        // bytes memory payload = abi.encode(userAccounts[msg.sender], msg.sender);

        DestinationMessage memory destinationMessage = DestinationMessage({
            userAddress: _targetAccountAddress,
            amount: msg.value,
            ticker: _ticker
        });
        bytes memory payload = abi.encode(destinationMessage, msg.sender);

        // uint16 refundChain = 10005; // Todo: Make it dynamic to come from the source chain it's deployed to
        uint16 refundChain = _refundChainId; // Todo: Make it dynamic to come from the source chain it's deployed to

        address refundAddress = msg.sender;

        // Todo: Change, Instead of using the sendPayloadToEvm function, use the specialised relayer to publish the message to non-EVM chains
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

    //  ########################################################################################
    //  ###############               TARGET CHAIN FUNCTIONS                    ################
    //  ########################################################################################

    /**
     *
     * @dev This is the receive function receives the message from the wormhole relayer on the source chain confirming the deposit.
        // Todo: Change, Instead of using the receiveWormholeMessage function, use the specialised relayer to receive messages from non-EVM chains
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32,
        uint16 sourceChain,
        bytes32
    ) public payable override {
        address relayerAddress = address(i_wormholeRelayer);

        if (msg.sender != relayerAddress) {
            revert DontBridge__NotAllowed();
        }

        (DestinationMessage memory destinationMessage, address sender) = abi
            .decode(payload, (DestinationMessage, address));

        uint256 amount = destinationMessage.amount;

        if (amount > address(this).balance) {
            revert DontBridge__NotEnoughFunds();
        }

        address targetAccount = destinationMessage.userAddress;

        (bool success, ) = targetAccount.call{value: amount}("");

        if (!success) {
            revert DontBridge__NotEnoughFunds();
        }

        // Save the user's account to the userAccounts mapping
        userAccounts[targetAccount] = UserAccount({
            userAddress: targetAccount,
            targetAccountAddress: sender,
            amount: amount
        });

        emit SentFunds(targetAccount, amount, 0, sourceChain);
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

        emit RepaidFunds(userAccount.userAddress, amount, 0);
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

    modifier onlyOwner() {
        if (msg.sender != s_owner) {
            revert DontBridge__NotAllowed();
        }
        _;
    }

    // Add a temporary function that withdraws the contract's balance
    function withdrawContractBalance() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {
        emit DepositedFunds(msg.sender, msg.value);
    }

    // View / Pure functions

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
