// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IEscrowV1} from "./interfaces/IEscrowV1.sol";

contract EscrowV1 is IEscrowV1, Ownable {
    uint256 private txCount = 0;

    uint256 public escrowInterval;

    mapping(bytes32 => TransactionData) transactions;

    constructor(uint256 _escrowInterval, address _owner) Ownable(_owner) {
        escrowInterval = _escrowInterval;
    }

    function depositERC20(
        address recipient,
        address token,
        uint256 amount
    ) external override returns (bytes32) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }

        if (recipient == address(0)) {
            revert RecipientCannotBeZero();
        }

        address payee = msg.sender;
        uint256 timestamp = block.timestamp;

        bytes32 depositId = keccak256(
            abi.encode(recipient, timestamp, txCount + 1)
        );

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

    function claim(bytes32 txId) external {
        TransactionData storage txData = transactions[txId];

        if (txData.txInitTimestamp == 0) revert InvalidTxId();

        if ((block.timestamp - txData.txInitTimestamp) > escrowInterval)
            revert ClaimExpired();

        address token = txData.token;
        address recipient = txData.recipient;
        uint256 amount = txData.amount;

        delete transactions[txId];

        TransferHelper.safeTransfer(token, recipient, amount);

        emit TokensClaimed(recipient, token, amount);
    }

    function redeemERC20(bytes32 txId) external {
        TransactionData storage txData = transactions[txId];
        if (txData.txInitTimestamp == 0) revert InvalidTxId();
        if ((block.timestamp - txData.txInitTimestamp) <= escrowInterval)
            revert ClaimNotExpired();
        address payee = txData.payee;
        uint256 amount = txData.amount;
        address token = txData.token;
        delete transactions[txId];
        TransferHelper.safeTransfer(token, payee, amount);
    }

    function updateEscrowInterval(
        uint256 _newInterval
    ) external override onlyOwner {
        uint256 oldInterval = escrowInterval;
        escrowInterval = _newInterval;
        emit EscrowIntervalUpdated(oldInterval, _newInterval);
    }

}
