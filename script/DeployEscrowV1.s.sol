// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {EscrowV1} from "../src/EscrowV1.sol";

contract DeployEscrowV1 is Script {
    function run(
        uint256 _escrowInterval,
        address _owner
    ) public returns (EscrowV1) {
        EscrowV1 escrowV1 = deployEscrowV1(_escrowInterval, _owner);
        return escrowV1;
    }

    function deployEscrowV1(
        uint256 _escrowInterval,
        address _owner
    ) public returns (EscrowV1) {
        vm.startBroadcast();
        EscrowV1 escrowV1 = new EscrowV1(_escrowInterval, _owner);
        vm.stopBroadcast();
        return escrowV1;
    }
}
