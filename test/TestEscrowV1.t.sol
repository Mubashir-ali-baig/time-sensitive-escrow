// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {Fixtures} from "./utils/Fixtures.sol";

/**
 * @title TestEscrowV1
 * @notice A comprehensive test suite for the EscrowV1 contract, covering deposits, claims, redeems, and ownership functions.
 * @dev Uses Forge's Test library for testing and Fixtures for setup utilities.
 */
contract TestEscrowV1 is Test, Fixtures {
    /// @notice Stores test user accounts.
    address payable[] users;

    /**
     * @notice Sets up the test environment by creating test users and deploying the escrow contract.
     */
    function setUp() public {
        users = createUsers(5); // Create 5 test users
        deployFreshState(30 days); // Deploy the escrow contract with a 30-day interval
    }

    /**
     * @notice Tests that the proxy returns the correct version of the escrow contract.
     */
    function testProxyVersion() public view {
        assertEq(escrow.version(), 1);
    }

    /**
     * @notice Tests a valid ERC20 token deposit into the escrow contract.
     */
    function testValidDeposit() public {
        transferMockTokens(users[0], 100e18); // Transfer mock tokens to user[0]
        assertEq(mockToken.balanceOf(users[0]), 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18); // Approve escrow to transfer tokens
        escrow.depositERC20(users[1], address(mockToken), 10e18); // Deposit tokens into escrow
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(escrow)), 10e18); // Verify escrow balance
    }

    /**
     * @notice Tests that depositing with a zero address recipient reverts with `RecipientCannotBeZero()`.
     */
    function testDepositShoulFailWithRecipientCannotBeZero() public {
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("RecipientCannotBeZero()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector); // Expect revert
        escrow.depositERC20(address(0), address(mockToken), 10e18); // Invalid deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing with zero token amount reverts with `AmountCannotBeZero()`.
     */
    function testDepositShouldFailWithAmountCannotBeZero() public {
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("AmountCannotBeZero()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector); // Expect revert
        escrow.depositERC20(users[1], address(mockToken), 0); // Invalid deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests that redeeming funds before the escrow interval expires reverts with `ClaimNotExpired()`.
     */
    function testRedeemShouldFailWithClaimNotExpired() public {
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("ClaimNotExpired()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.expectRevert(selector); // Expect revert
        escrow.redeem(txId); // Attempt to redeem prematurely
        vm.stopPrank();
    }

    /**
     * @notice Tests a valid claim of deposited ERC20 tokens within the escrow interval.
     */
    function testValidClaim() public {
        bytes32 txId;
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.stopPrank();

        vm.warp(block.timestamp + 3400); // Fast forward time

        vm.startPrank(users[1]);
        escrow.claim(txId); // Claim tokens
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[1]), 10e18); // Verify recipient's balance
    }

    /**
     * @notice Tests that claiming funds after the escrow interval expires reverts with `ClaimExpired()`.
     */
    function testShouldFailWithClaimExpired() public {
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("ClaimExpired()"));
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days); // Fast forward time beyond interval

        vm.startPrank(users[1]);
        vm.expectRevert(selector); // Expect revert
        escrow.claim(txId); // Attempt to claim expired deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests that claiming with an invalid transaction ID reverts with `InvalidTxId()`.
     */
    function testShouldFailWithInvalidTxId() public {
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("InvalidTxId()"));
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.stopPrank();

        vm.warp(block.timestamp + 3400); // Fast forward time

        vm.startPrank(users[1]);
        vm.expectRevert(selector); // Expect revert
        escrow.claim(bytes32(keccak256("Invalid"))); // Invalid claim
        vm.stopPrank();
    }

    /**
     * @notice Tests a valid redemption of funds after the escrow interval has expired.
     */
    function testValidRedeem() public {
        bytes32 txId;
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        uint256 initialBalance = mockToken.balanceOf(users[0]);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days); // Fast forward time beyond interval

        vm.startPrank(users[0]);
        escrow.redeem(txId); // Redeem tokens
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[0]), (initialBalance + 10e18)); // Verify payee's balance
    }

    /**
     * @notice Tests updating the escrow interval by the contract owner.
     */
    function testValidUpdateInterval() public {
        vm.startPrank(deployer);
        escrow.updateEscrowInterval(3700); // Update interval
        vm.stopPrank();
        assertEq(escrow.escrowInterval(), 3700); // Verify updated interval
    }

    /**
     * @notice Tests that only the contract owner can update the escrow interval.
     */
    function testShouldFailWithOnlyOwner() public {
        bytes memory encodedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this));
        vm.expectRevert(encodedError); // Expect revert
        escrow.updateEscrowInterval(3700); // Unauthorized attempt
    }
}
