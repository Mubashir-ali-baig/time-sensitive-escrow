// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @title IEscrowV2
 * @notice Interface for the EscrowV2 contract with enhanced escrow functionalities.
 */
interface IEscrowV2 {
    /**
     * @notice Thrown when the amount provided for a transaction is zero.
     */
    error AmountCannotBeZero();

    /**
     * @notice Thrown when the recipient address provided is the zero address.
     */
    error RecipientCannotBeZero();

    /**
     * @notice Thrown when a transaction ID is invalid or does not exist.
     */
    error InvalidTxId();

    /**
     * @notice Thrown when attempting to claim after the escrow interval has expired.
     */
    error ClaimExpired();

    /**
     * @notice Thrown when attempting to redeem before the escrow interval has expired.
     */
    error ClaimNotExpired();

    /**
     * @notice Represents the details of a transaction in the escrow system.
     * @param payee The address of the sender (payer) who deposited the funds.
     * @param recipient The address of the recipient who can claim the funds.
     * @param token The address of the ERC20 token or `address(0)` for Ether.
     * @param amount The amount of funds deposited in the escrow.
     * @param txInitTimestamp The timestamp when the transaction was initiated.
     */
    struct TransactionData {
        address payee;
        address recipient;
        address token;
        uint256 amount;
        uint256 txInitTimestamp;
    }

    /**
     * @notice Deposits ERC20 tokens into escrow for a specified recipient.
     * @param recipient The address of the token recipient.
     * @param token The address of the ERC20 token to be deposited.
     * @param amount The amount of tokens to be deposited.
     * @return The unique identifier for the deposited transaction.
     * @custom:requirements
     * - `amount` must be greater than 0.
     * - `recipient` must not be the zero address.
     */
    function depositERC20(address recipient, address token, uint256 amount) external returns (bytes32);

    /**
     * @notice Allows a recipient to claim funds within the escrow interval.
     * @param txId The unique identifier of the transaction to be claimed.
     * @custom:requirements
     * - The `txId` must exist.
     * - The claim must occur within the escrow interval.
     */
    function claim(bytes32 txId) external;

    /**
     * @notice Allows the payee to redeem funds after the escrow interval has expired.
     * @param txId The unique identifier of the transaction to be redeemed.
     * @custom:requirements
     * - The `txId` must exist.
     * - The redemption must occur after the escrow interval.
     */
    function redeem(bytes32 txId) external;

    /**
     * @notice Updates the escrow interval for future transactions.
     * @param _newInterval The new interval in seconds.
     * @custom:requirements
     * - Only the contract owner can call this function.
     */
    function updateEscrowInterval(uint256 _newInterval) external;

    /**
     * @notice Emitted when tokens or Ether are deposited into escrow.
     * @param payee The address of the depositor.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens or Ether deposited.
     * @param timestamp The timestamp of the deposit.
     */
    event TokensDeposited(address indexed payee, address indexed recipient, uint256 amount, uint256 timestamp);

    /**
     * @notice Emitted when tokens or Ether are successfully claimed.
     * @param recipient The address of the recipient who claimed the funds.
     * @param token The address of the token claimed, or `address(0)` for Ether.
     * @param amount The amount of tokens or Ether claimed.
     */
    event TokensClaimed(address indexed recipient, address indexed token, uint256 amount);

    /**
     * @notice Emitted when the escrow interval is updated.
     * @param oldInterval The previous interval in seconds.
     * @param newInterval The new interval in seconds.
     */
    event EscrowIntervalUpdated(uint256 indexed oldInterval, uint256 indexed newInterval);

    event EtherReceived(address sender, uint256 value);
}
