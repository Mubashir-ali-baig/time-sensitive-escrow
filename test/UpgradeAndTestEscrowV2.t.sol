// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract UpgradeAndTestEscrowV2 is Test, Fixtures {
    address payable[] users;

    function setUp() public {
        users = createUsers(5);
        deployFreshState(30 days);
    }

    function testUpgradedVersion() public {
        deployUpgrade();
        assertEq(upgradedEscrow.version(), 2);
    }

    function testValidDeposit() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18);
        assertEq(mockToken.balanceOf(users[0]), 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();
        assertEq(mockToken.balanceOf(address(upgradedEscrow)), 10e18);
    }

    function testDepositShoulFailWithRecipientCannotBeZero() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("RecipientCannotBeZero()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector);
        upgradedEscrow.depositERC20(address(0), address(mockToken), 10e18);
        vm.stopPrank();
    }

    function testDepositShouldFailWithAmountCannotBeZero() public {
        deployUpgrade();
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("AmountCannotBeZero()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        vm.expectRevert(selector);
        upgradedEscrow.depositERC20(users[1], address(mockToken), 0);
        vm.stopPrank();
    }

    function testRedeemShouldFailWithClaimNotExpired() public {
        deployUpgrade();
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("ClaimNotExpired()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.expectRevert(selector);
        upgradedEscrow.redeem(txId);
        vm.stopPrank();
    }

    function testValidClaim() public {
        deployUpgrade();
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 3400);

        vm.startPrank(users[1]);
        upgradedEscrow.claim(txId);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[1]), 10e18);
    }

    function testShouldFailWithClaimExpired() public {
        deployUpgrade();
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("ClaimExpired()"));
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        vm.startPrank(users[1]);
        vm.expectRevert(selector);
        upgradedEscrow.claim(txId);
        vm.stopPrank();
    }

    function testShouldFailWithInvalidTxId() public {
        deployUpgrade();
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("InvalidTxId()"));
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 3400);

        vm.startPrank(users[1]);
        vm.expectRevert(selector);
        upgradedEscrow.claim(bytes32(keccak256("Invalid")));
        vm.stopPrank();
    }

    function testValidRedeem() public {
        deployUpgrade();
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(upgradedEscrow), 10e18);
        txId = upgradedEscrow.depositERC20(users[1], address(mockToken), 10e18);
        uint256 initialBalance = mockToken.balanceOf(users[0]);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        vm.startPrank(users[0]);
        upgradedEscrow.redeem(txId);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[0]), (initialBalance + 10e18));
    }

    function testValidUpdateInterval() public {
        deployUpgrade();
        vm.startPrank(deployer);
        upgradedEscrow.updateEscrowInterval(3700);
        vm.stopPrank();
        assertEq(upgradedEscrow.escrowInterval(), 3700);
    }

    function testShouldFailWithOnlyOwner() public {
        deployUpgrade();
        bytes memory encodedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this));
        vm.expectRevert(encodedError);
        upgradedEscrow.updateEscrowInterval(3700);
    }

    function testDepositValidEther() public {
        deployUpgrade();
        vm.startPrank(users[0]);
        upgradedEscrow.depositEther{value: 1 ether}(users[1]);
        vm.stopPrank();
        assertEq(address(upgradedEscrow).balance, 1 ether);
    }

    function testValidEtherClaim() public {
        deployUpgrade();
        bytes32 txId;
        uint256 initialBalance = users[1].balance;
        vm.startPrank(users[0]);
        txId = upgradedEscrow.depositEther{value: 1 ether}(users[1]);
        vm.stopPrank();

        vm.warp(3400);

        vm.startPrank(users[1]);
        upgradedEscrow.claim(txId);
        vm.stopPrank();
        assertEq(users[1].balance, initialBalance + 1 ether);
    }

    function testValidEtherRedeem() public {
        deployUpgrade();
        bytes32 txId;
        vm.startPrank(users[0]);
        txId = upgradedEscrow.depositEther{value: 1 ether}(users[1]);
        vm.stopPrank();
        uint256 initialBalance = users[0].balance;

        vm.warp(block.timestamp + 31 days);

        vm.startPrank(users[0]);
        upgradedEscrow.redeem(txId);
        vm.stopPrank();

        assertEq(users[0].balance, initialBalance + 1 ether);
    }
}
