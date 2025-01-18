// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {EscrowV1} from "../../src/EscrowV1.sol";
import {TransferHelper} from "../../src/libraries/TransferHelper.sol";
import {DeployEscrowV1} from "../../script/DeployEscrowV1.s.sol";
import {Test} from "forge-std/Test.sol";

contract Fixtures is Test{
    DeployEscrowV1 public escrowDeployer;
    ERC20Mock public mockToken;
    EscrowV1 public escrow;
    address public deployer;

    constructor(){
        deployer = msg.sender;
    }

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));
    function deployMockToken(
        uint256 totalSupply
    ) public {
        mockToken = new ERC20Mock();
        mockToken.mint(address(this), totalSupply);
    }

    function deployFreshState(uint256 escrowInterval) public {
        escrowDeployer = new DeployEscrowV1();
        deployMockToken(10000e18);
        escrow = escrowDeployer.run(escrowInterval, msg.sender);
    }

    function getNextUserAddress() public returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    //create users with 100 ether balance
    function createUsers(uint256 userNum) public returns (address payable[] memory) {
        address payable[] memory users = new address payable[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            address payable user = this.getNextUserAddress();
            vm.deal(user, 100 ether);
            users[i] = user;
        }
        return users;
    }

    function transferMockTokens(address user, uint256 amount) public{
        TransferHelper.safeTransfer(address(mockToken), user, amount);
    }
}
