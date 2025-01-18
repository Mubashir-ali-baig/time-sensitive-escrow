// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {Fixtures} from "./utils/Fixtures.sol";
contract TestEscrowV1 is Test, Fixtures{
    address payable[] users;
    function setUp() public {  
        users=createUsers(5);
        deployFreshState(1 hours);
    }

    function testValidDeposit() public {
        transferMockTokens(users[0], 100e18);
        assertEq(mockToken.balanceOf(users[0]), 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        escrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();
        assertEq(mockToken.balanceOf(address(escrow)), 10e18);
    }

    function testDepositShoulFailWithRecipientCannotBeZero() public{
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("RecipientCannotBeZero()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector);
        escrow.depositERC20(address(0), address(mockToken), 10e18);
        vm.stopPrank();
    }

    function testDepositShouldFailWithAmountCannotBeZero() public {
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("AmountCannotBeZero()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        vm.expectRevert(selector);
        escrow.depositERC20(users[1], address(mockToken), 0);
        vm.stopPrank();
    }

    function testRedeemShouldFailWithClaimNotExpired()public{
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        bytes4 selector = bytes4(keccak256("ClaimNotExpired()"));
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.expectRevert(selector);
        escrow.redeemERC20(txId);
        vm.stopPrank();
    }

    function testValidClaim()public{
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3400);
        
        vm.startPrank(users[1]);
        escrow.claim(txId);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[1]), 10e18);
    }

    function testShouldFailWithClaimExpired()public{
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("ClaimExpired()"));
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3700);
        
        vm.startPrank(users[1]);
        vm.expectRevert(selector);
        escrow.claim(txId);
        vm.stopPrank();
    }

    function testShouldFailWithInvalidTxId()public{
        bytes32 txId;
        bytes4 selector = bytes4(keccak256("InvalidTxId()"));
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3400);
        
        vm.startPrank(users[1]);
        vm.expectRevert(selector);
        escrow.claim(bytes32(keccak256("Invalid")));
        vm.stopPrank();
    }

    function testValidRedeem()public{
        bytes32 txId;
        transferMockTokens(users[0], 100e18);
        vm.startPrank(users[0]);
        mockToken.approve(address(escrow), 10e18);
        txId = escrow.depositERC20(users[1], address(mockToken), 10e18);
        uint256 initialBalance = mockToken.balanceOf(users[0]);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3700);
        
        vm.startPrank(users[0]);
        escrow.redeemERC20(txId);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(users[0]),(initialBalance + 10e18));
    }

    function testValidUpdateInterval()public{
        vm.startPrank(deployer);
        escrow.updateEscrowInterval(3700);
        vm.stopPrank();
        assertEq(escrow.escrowInterval(), 3700);
    }

    function testShouldFailWithOnlyOwner()public{ 
        bytes memory encodedError = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this));
        vm.expectRevert(encodedError);
        escrow.updateEscrowInterval(3700);
    }
    
}