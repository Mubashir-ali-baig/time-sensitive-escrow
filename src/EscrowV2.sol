// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IEscrowV2} from "./interfaces/IEscrowV2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EscrowV2
 * @author Mubashir Ali Baig
 * @notice A UUPS upgradeable escrow contract supporting both ERC20 tokens and Ether deposits.
 * @dev Provides functionality for deposits, claims, and redemptions with time-based constraints.
 */
contract EscrowV2 is IEscrowV2, Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard {
    /// @notice Tracks the number of transactions.
    uint256 private txCount;

    /// @notice Configurable interval for escrow claims in seconds.
    uint256 public escrowInterval;

    /// @notice Stores details of each transaction using a unique identifier.
    mapping(bytes32 => TransactionData) transactions;

    /**
     * @notice Disables initializers to prevent direct deployment without initialization.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the escrow contract with a specific claim interval and owner.
     * @param _escrowInterval The interval in seconds during which claims are allowed.
     * @param _owner The address of the owner.
     */
    function initialize(uint256 _escrowInterval, address _owner) public initializer {
        __Ownable_init(_owner);
        escrowInterval = _escrowInterval;
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Deposits ERC20 tokens into escrow for a specified recipient.
     * @param recipient The address of the token recipient.
     * @param token The address of the ERC20 token to be deposited.
     * @param amount The amount of tokens to deposit.
     * @return The unique identifier of the deposit transaction.
     * @custom:requirements
     * - `amount` must be greater than 0.
     * - `recipient` must not be the zero address.
     */
    function depositERC20(address recipient, address token, uint256 amount)
        external
        override
        nonReentrant
        returns (bytes32)
    {
        if (amount == 0) revert AmountCannotBeZero();
        if (recipient == address(0)) revert RecipientCannotBeZero();

        address payee = msg.sender;
        uint256 timestamp = block.timestamp;

        bytes32 depositId = keccak256(abi.encodePacked(recipient, timestamp, txCount + 1));

        transactions[depositId] = TransactionData({
            payee: payee,
            recipient: recipient,
            token: token,
            amount: amount,
            txInitTimestamp: timestamp
        });

        txCount += 1;

        TransferHelper.safeTransferFrom(token, payee, address(this), amount);

        emit TokensDeposited(payee, recipient, amount, timestamp);

        return depositId;
    }

    /**
     * @notice Deposits Ether into escrow for a specified recipient.
     * @param recipient The address of the Ether recipient.
     * @return The unique identifier of the deposit transaction.
     * @custom:requirements
     * - `msg.value` must be greater than 0.
     * - `recipient` must not be the zero address.
     */
    function depositEther(address recipient) external payable nonReentrant returns (bytes32) {
        if (msg.value == 0) revert AmountCannotBeZero();
        if (recipient == address(0)) revert RecipientCannotBeZero();

        address payee = msg.sender;
        uint256 timestamp = block.timestamp;

        bytes32 depositId = keccak256(abi.encodePacked(recipient, timestamp, txCount + 1));

        transactions[depositId] = TransactionData({
            payee: payee,
            recipient: recipient,
            token: address(0),
            amount: msg.value,
            txInitTimestamp: timestamp
        });

        txCount += 1;

        emit TokensDeposited(payee, recipient, msg.value, timestamp);

        return depositId;
    }

    /**
     * @notice Allows a recipient to claim tokens or Ether within the escrow interval.
     * @param txId The unique identifier of the transaction to be claimed.
     * @custom:requirements
     * - `txId` must exist.
     * - The claim must occur within the escrow interval.
     */
    function claim(bytes32 txId) external override nonReentrant {
        TransactionData memory txData = transactions[txId];

        if (txData.txInitTimestamp == 0) revert InvalidTxId();
        if ((block.timestamp - txData.txInitTimestamp) > escrowInterval) revert ClaimExpired();

        if (txData.token == address(0)) {
            // Ether transfer
            (bool success,) = txData.recipient.call{value: txData.amount}("");
            require(success);
        } else {
            // ERC20 transfer
            TransferHelper.safeTransfer(txData.token, txData.recipient, txData.amount);
        }

        emit TokensClaimed(txData.recipient, txData.token, txData.amount);

        delete transactions[txId];
    }

    /**
     * @notice Allows the payee to redeem tokens or Ether after the escrow interval has expired.
     * @param txId The unique identifier of the transaction to be redeemed.
     * @custom:requirements
     * - `txId` must exist.
     * - Redemption must occur after the escrow interval has expired.
     */
    function redeem(bytes32 txId) external override nonReentrant {
        TransactionData memory txData = transactions[txId];
        if (txData.txInitTimestamp == 0) revert InvalidTxId();
        if ((block.timestamp - txData.txInitTimestamp) <= escrowInterval) revert ClaimNotExpired();

        if (txData.token == address(0)) {
            // Ether transfer
            (bool success,) = txData.payee.call{value: txData.amount}("");
            require(success);
        } else {
            // ERC20 transfer
            TransferHelper.safeTransfer(txData.token, txData.payee, txData.amount);
        }
        delete transactions[txId];
    }

    /**
     * @notice Updates the escrow interval for all future transactions.
     * @param _newInterval The new interval in seconds.
     * @custom:requirements
     * - Only the contract owner can call this function.
     */
    function updateEscrowInterval(uint256 _newInterval) external override onlyOwner {
        uint256 oldInterval = escrowInterval;
        escrowInterval = _newInterval;
        emit EscrowIntervalUpdated(oldInterval, _newInterval);
    }

    /**
     * @notice Returns the version of the escrow contract.
     * @return The version number of the contract.
     */
    function version() external pure returns (uint256) {
        return 2;
    }

    /**
     * @notice Authorizes contract upgrades.
     * @param newImplementation The address of the new implementation contract.
     * @custom:requirements
     * - Only the contract owner can upgrade the contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @notice Fallback function to handle unexpected Ether transfers.
     * @dev Reverts all direct Ether transfers.
     */
    fallback() external payable {
        revert();
    }

    /**
     * @notice Allows the contract to receive Ether and emit an event.
     * @dev This is triggered when Ether is sent without data.
     */
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
}
