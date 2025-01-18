// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IEscrowV1} from "./interfaces/IEscrowV1.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EscrowV1
 * @author Mubashir Ali Baig
 * @notice A UUPS upgradeable escrow contract for securely managing ERC20 token transactions.
 * @dev Implements an escrow mechanism with configurable claim and redeem intervals.
 */
contract EscrowV1 is IEscrowV1, Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard {
    /// @notice Tracks the number of transactions.
    uint256 private txCount;

    /// @notice Configurable interval for escrow claims in seconds.
    uint256 public escrowInterval;

    /// @notice Stores details of each transaction using a unique identifier.
    mapping(bytes32 => TransactionData) public transactions;

    /**
     * @notice Disables initializers to prevent direct contract deployment.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the escrow contract with a specific claim interval and owner.
     * @param _escrowInterval The interval in seconds during which claims are allowed.
     * @param _owner The owner of the contract.
     */
    function initialize(uint256 _escrowInterval, address _owner) public initializer {
        __Ownable_init(_owner);
        escrowInterval = _escrowInterval;
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Deposits ERC20 tokens into escrow for a specific recipient.
     * @dev Emits a `TokensDeposited` event upon successful deposit.
     * @param recipient The address of the token recipient.
     * @param token The address of the ERC20 token.
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
        if (amount == 0) {
            revert AmountCannotBeZero();
        }

        if (recipient == address(0)) {
            revert RecipientCannotBeZero();
        }

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
     * @notice Allows a recipient to claim tokens within the escrow interval.
     * @dev Emits a `TokensClaimed` event upon successful claim.
     * @param txId The unique identifier of the transaction.
     * @custom:requirements
     * - `txId` must exist in the escrow.
     * - Claim must occur within the configured `escrowInterval`.
     */
    function claim(bytes32 txId) external override nonReentrant {
        TransactionData memory txData = transactions[txId];

        if (txData.txInitTimestamp == 0) revert InvalidTxId();

        if ((block.timestamp - txData.txInitTimestamp) > escrowInterval) {
            revert ClaimExpired();
        }

        TransferHelper.safeTransfer(txData.token, txData.recipient, txData.amount);

        emit TokensClaimed(txData.recipient, txData.token, txData.amount);

        delete transactions[txId];
    }

    /**
     * @notice Allows the payee to redeem tokens after the escrow interval has expired.
     * @dev Emits a `TokensClaimed` event upon successful redemption.
     * @param txId The unique identifier of the transaction.
     * @custom:requirements
     * - `txId` must exist in the escrow.
     * - Redemption must occur after the configured `escrowInterval`.
     */
    function redeem(bytes32 txId) external override nonReentrant {
        TransactionData memory txData = transactions[txId];
        if (txData.txInitTimestamp == 0) revert InvalidTxId();
        if ((block.timestamp - txData.txInitTimestamp) <= escrowInterval) {
            revert ClaimNotExpired();
        }
        TransferHelper.safeTransfer(txData.token, txData.payee, txData.amount);
        delete transactions[txId];
    }

    /**
     * @notice Updates the escrow interval for all future transactions.
     * @dev Emits an `EscrowIntervalUpdated` event.
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
        return 1;
    }

    /**
     * @notice Authorizes contract upgrades.
     * @dev Implements access control for upgrades.
     * @param newImplementation The address of the new implementation contract.
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
