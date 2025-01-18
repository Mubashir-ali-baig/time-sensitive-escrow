// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {EscrowV1} from "../../src/EscrowV1.sol";
import {EscrowV2} from "../../src/EscrowV2.sol";
import {TransferHelper} from "../../src/libraries/TransferHelper.sol";
import {DeployEscrowV1} from "../../script/DeployEscrowV1.s.sol";
import {UpgradeEscrowV1} from "../../script/UpgradeEscrowV1.s.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

contract Fixtures is Test {
    DeployEscrowV1 public escrowDeployer;
    UpgradeEscrowV1 public escrowUpgrader;
    ERC20Mock public mockToken;
    EscrowV1 public escrow;
    EscrowV2 public upgradedEscrow;
    address public deployer;
    ERC1967Proxy public proxy;

    constructor() {
        deployer = msg.sender;
    }

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    function deployMockToken(uint256 totalSupply) public {
        mockToken = new ERC20Mock();
        mockToken.mint(address(this), totalSupply);
    }

    function deployFreshState(uint256 escrowInterval) public {
        escrowDeployer = new DeployEscrowV1();
        deployMockToken(10000e18);
        proxy = escrowDeployer.run(escrowInterval, msg.sender);
        escrow = EscrowV1(address(proxy));
    }

    function deployUpgrade() public {
        escrowUpgrader = new UpgradeEscrowV1();
        upgradedEscrow = EscrowV2(escrowUpgrader.run(address(proxy)));
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

    function transferMockTokens(address user, uint256 amount) public {
        TransferHelper.safeTransfer(address(mockToken), user, amount);
    }
}
