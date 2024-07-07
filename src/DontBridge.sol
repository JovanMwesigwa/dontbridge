// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

    event DepositedFunds(address indexed userAddress, uint256 indexed amount);

    event SentFunds(
        address indexed userAddress,
        uint256 indexed amount,
        uint256 indexed targetChainId
    );

    event WithdrawnFunds(address indexed userAddress, uint256 indexed amount);

    struct UserAccount {
        address userAddress;
        address targetAccountAddress;
        uint256 targetChainId;
        uint256 amount;
        string tiker; // Will be changed to a struct of the token details and prices
    }

    mapping(address user => UserAccount) private userAccounts;

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
    function depositFunds(
        address _targetAccountAddress,
        string memory _ticker,
        uint256 _targetChainId
    ) external payable {
        if (msg.value <= 0) {
            revert DontBridge__NotEnoughFunds();
        }

        userAccounts[msg.sender] = UserAccount({
            userAddress: msg.sender,
            targetAccountAddress: _targetAccountAddress,
            targetChainId: _targetChainId,
            amount: msg.value,
            tiker: _ticker
        });

        emit DepositedFunds(msg.sender, msg.value);
    }

    /**
     * @dev Receives the message from the target chain confirming the deposit. and unlocks the equivalent amount of funds on the target chain from the pool.
     * Todo: This function will be called by the wormhole contract on the target chain.
     * So add a modifier to check if the caller is the wormhole contract.
     */
    function sendUserFunds(
        address _sourceUserAccount,
        address targetAccount,
        uint256 amount,
        string memory ticker,
        uint256 sourceChain
    ) external payable {
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

        // Pay the user the amount of funds they deposited
        payable(userAccount.userAddress).transfer(userAccount.amount);

        emit SentFunds(
            userAccount.userAddress,
            userAccount.amount,
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
    function withdrawFunds() external {
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
}
