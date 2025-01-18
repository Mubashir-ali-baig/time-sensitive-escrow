// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {EscrowV1} from "../src/EscrowV1.sol";
import {EscrowV2} from "../src/EscrowV2.sol";
import {console} from "forge-std/console.sol";

contract UpgradeEscrowV1 is Script {
    function run(address oldEscrow) public returns (address) {
        EscrowV2 upgradedEscrow = new EscrowV2();
        address proxy = upgradeEscrow(oldEscrow, address(upgradedEscrow));

        return proxy;
    }

    function upgradeEscrow(address proxyAddress, address upgradedEscrow) public returns (address) {
        vm.startBroadcast();
        EscrowV1 proxy = EscrowV1(payable(proxyAddress));
        proxy.upgradeToAndCall(upgradedEscrow, "");
        vm.stopBroadcast();
        return address(proxy);
    }
}
