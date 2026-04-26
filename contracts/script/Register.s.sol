// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";

contract Register is Script {
    address constant REGISTRAR_CONTROLLER = 0x8CaD65fb525D709fF32Ec96b020Eb90e3Cb212F0;
    address constant PUBLIC_RESOLVER = 0xcdE3eD98423FbE098E24Bba9B634dFC3b449AC1C;

    // keccak256(abi.encodePacked(bytes32(0), keccak256("app")))
    bytes32 constant TLD_APP = 0xf7e1414e83ef17e770a253cedccf6316ed40eab77328b139fc18136b2e1a2ae4;

    function run() external {
        address owner = vm.envOr("REGISTER_OWNER", vm.envAddress("DEPLOYER_ADDRESS"));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory label = vm.envOr("REGISTER_LABEL", string("kite"));
        uint256 duration = vm.envOr("REGISTER_DURATION", uint256(30 days));
        bytes32 secret = keccak256(abi.encodePacked("oniym-secret", owner, label));

        IRegistrarController ctrl = IRegistrarController(REGISTRAR_CONTROLLER);

        // Pre-compute nameNode so we can set the ETH address record atomically at registration
        bytes32 labelHash = keccak256(bytes(label));
        bytes32 nameNode = keccak256(abi.encodePacked(TLD_APP, labelHash));

        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = abi.encodeWithSignature(
            "setAddr(bytes32,uint256,bytes)",
            nameNode,
            uint256(60), // SLIP-0044 ETH coin type
            abi.encodePacked(owner)
        );

        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: label,
            tld: TLD_APP,
            owner: owner,
            duration: duration,
            secret: secret,
            resolver: PUBLIC_RESOLVER,
            resolverData: resolverData,
            reverseRecord: true
        });

        (uint256 base, uint256 premium) = ctrl.rentPrice(label, TLD_APP, duration);
        uint256 total = base + premium;
        console.log("Price (wei):", total);

        bytes32 commitment = ctrl.makeCommitment(req);
        console.log("Commitment:");
        console.logBytes32(commitment);

        uint256 existing = ctrl.commitments(commitment);
        if (existing == 0) {
            vm.startBroadcast(pk);
            ctrl.commit(commitment);
            vm.stopBroadcast();
            console.log("Committed - wait 60 s then run the same command again");
        } else {
            uint256 age = block.timestamp - existing;
            console.log("Commitment age (s):", age);
            if (age < ctrl.MIN_COMMITMENT_AGE()) {
                console.log("Too early - wait", ctrl.MIN_COMMITMENT_AGE() - age, "more seconds");
            } else {
                vm.startBroadcast(pk);
                ctrl.register{ value: total }(req);
                vm.stopBroadcast();
                console.log("Registered:", label, ".app");
            }
        }
    }
}
