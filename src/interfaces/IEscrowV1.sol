// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IEscrowV1 {
    error AmountCannotBeZero();
    error RecipientCannotBeZero();
    error InvalidTxId();
    error ClaimExpired();
    error ClaimNotExpired();

    struct TransactionData {
        address payee;
        address recipient;
        address token;
        uint256 amount;
        uint256 txInitTimestamp;
    }

    function depositERC20(address recipient, address token, uint256 amount) external returns (bytes32);

    function updateEscrowInterval(uint256 _newInterval) external;

    event TokensDeposited(address indexed payee, address indexed recipient, uint256 indexed amount, uint256 timestamp);

    event TokensClaimed(address indexed recipient, address indexed token, uint256 indexed amount);

    event EscrowIntervalUpdated(uint256 indexed oldInterval, uint256 indexed newInterval);
}
