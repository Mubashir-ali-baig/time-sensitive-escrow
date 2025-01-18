// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {EscrowV1} from "../src/EscrowV1.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEscrowV1 is Script {
    function run(uint256 _escrowInterval, address _owner) public returns (ERC1967Proxy) {
        ERC1967Proxy proxy = deployEscrowV1(_escrowInterval, _owner);
        return proxy;
    }

    function deployEscrowV1(uint256 _escrowInterval, address _owner) public returns (ERC1967Proxy) {
        vm.startBroadcast();
        EscrowV1 escrowV1 = new EscrowV1();
        bytes memory initializeData = abi.encodeWithSelector(EscrowV1.initialize.selector, _escrowInterval, _owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(escrowV1), initializeData);
        vm.stopBroadcast();
        return proxy;
    }
}
