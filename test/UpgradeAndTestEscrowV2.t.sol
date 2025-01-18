// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {Fixtures} from "./utils/Fixtures.sol";

/**
 * @title UpgradeAndTestEscrowV2
 * @notice A comprehensive test suite for the upgraded EscrowV2 contract, verifying both ERC20 and Ether functionality.
 * @dev Utilizes Forge's Test library and Fixtures for setup and utility methods.
 */
contract UpgradeAndTestEscrowV2 is Test, Fixtures {
    /// @notice Stores test user accounts.
    address payable[] users;

    /**
     * @notice Sets up the test environment by creating test users and deploying the initial state of the escrow contract.
     */
    function setUp() public {
        users = createUsers(5); // Create 5 test users
        deployFreshState(30 days); // Deploy the initial version of the escrow contract
    }

    /**
     * @notice Tests that the upgraded contract returns the correct version number.
     */
    function testUpgradedVersion() public {
        deployUpgrade(); // Upgrade to EscrowV2
        assertEq(upgradedEscrow.version(), 2); // Verify version
    }

    /**
     * @notice Tests a valid ERC20 token deposit into the upgraded escrow contract.
     */
    function testValidDeposit() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18); // Transfer mock tokens to user[0]
        assertEq(mockToken.balanceOf(users[0]), 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18); // Approve escrow to transfer tokens
        upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18); // Deposit tokens into escrow
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(upgradedEscrow)), 10e18); // Verify escrow balance
    }

    /**
     * @notice Tests that depositing with a zero address recipient reverts with `RecipientCannotBeZero()`.
     */
    function testDepositShoulFailWithRecipientCannotBeZero() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("RecipientCannotBeZero()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector); // Expect revert
        upgradedEscrow.depositERC20(address(0), address(mockToken), 10e18); // Invalid deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing with zero token amount reverts with `AmountCannotBeZero()`.
     */
    function testDepositShouldFailWithAmountCannotBeZero() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("AmountCannotBeZero()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        vm.expectRevert(selector); // Expect revert
        upgradedEscrow.depositERC20(users[1], address(mockToken), 0); // Invalid deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests that redeeming funds before the escrow interval expires reverts with `ClaimNotExpired()`.
     */
    function testRedeemShouldFailWithClaimNotExpired() public {
        deployUpgrade();
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("ClaimNotExpired()"));

        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.expectRevert(selector); // Expect revert
        upgradedEscrow.redeem(txId); // Attempt to redeem prematurely
        vm.stopPrank();
    }

    /**
     * @notice Tests a valid claim of deposited ERC20 tokens within the escrow interval.
     */
    function testValidClaim() public {
        deployUpgrade();
        bytes32 txId;
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.stopPrank();

        vm.warp(block.timestamp + 3400); // Fast forward time

        vm.startPrank(users[1]);
        upgradedEscrow.claim(txId); // Claim tokens
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[1]), 10e18); // Verify recipient's balance
    }

    /**
     * @notice Tests that claiming funds after the escrow interval expires reverts with `ClaimExpired()`.
     */
    function testShouldFailWithClaimExpired() public {
        deployUpgrade();
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("ClaimExpired()"));
        transferMockTokens(users[0], 100e18);

        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18); // Valid deposit
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days); // Fast forward time beyond interval

        vm.startPrank(users[1]);
        vm.expectRevert(selector); // Expect revert
        upgradedEscrow.claim(txId); // Attempt to claim expired deposit
        vm.stopPrank();
    }

    /**
     * @notice Tests a valid Ether deposit into the upgraded escrow contract.
     */
    function testDepositValidEther() public {
        deployUpgrade();
        vm.startPrank(users[0]);
        upgradedEscrow.depositEther{value: 1 ether}(users[1]); // Deposit Ether
        vm.stopPrank();
        assertEq(address(upgradedEscrow).balance, 1 ether); // Verify contract balance
    }

    /**
     * @notice Tests a valid claim of deposited Ether within the escrow interval.
     */
    function testValidEtherClaim() public {
        deployUpgrade();
        bytes32 txId;
        uint256 initialBalance = users[1].balance;

        vm.startPrank(users[0]);
        txId = upgradedEscrow.depositEther{value: 1 ether}(users[1]); // Deposit Ether
        vm.stopPrank();

        vm.warp(3400); // Fast forward time

        vm.startPrank(users[1]);
        upgradedEscrow.claim(txId); // Claim Ether
        vm.stopPrank();

        assertEq(users[1].balance, initialBalance + 1 ether); // Verify recipient's balance
    }

    /**
     * @notice Tests a valid redemption of Ether after the escrow interval has expired.
     */
    function testValidEtherRedeem() public {
        deployUpgrade();
        bytes32 txId;
        vm.startPrank(users[0]);
        txId = upgradedEscrow.depositEther{value: 1 ether}(users[1]); // Deposit Ether
        vm.stopPrank();
        uint256 initialBalance = users[0].balance;

        vm.warp(block.timestamp + 31 days); // Fast forward time beyond interval

        vm.startPrank(users[0]);
        upgradedEscrow.redeem(txId); // Redeem Ether
        vm.stopPrank();

        assertEq(users[0].balance, initialBalance + 1 ether); // Verify payee's balance
    }
}
