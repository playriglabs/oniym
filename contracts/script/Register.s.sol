// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";

contract Register is Script {
    address constant REGISTRAR_CONTROLLER = 0xF14E154633EFf408a99d3E6c9b01f918F93Ba5b1;
    address constant PUBLIC_RESOLVER     = 0xA37eD413181537c60586317a70f612a304EB0681;

    // keccak256(abi.encodePacked(bytes32(0), keccak256("web3")))
    bytes32 constant TLD_WEB3 = 0x587d09fe5fa45354680537d38145a28b772971e0f293af3ee0c536fc919710fb;

    function run() external {
        address owner = vm.envOr("REGISTER_OWNER", vm.envAddress("DEPLOYER_ADDRESS"));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory label = vm.envOr("REGISTER_LABEL", string("kyy"));
        uint256 duration = vm.envOr("REGISTER_DURATION", uint256(365 days));
        bytes32 secret = keccak256(abi.encodePacked("oniym-secret", owner, label));

        IRegistrarController ctrl = IRegistrarController(REGISTRAR_CONTROLLER);

        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: label,
            tld: TLD_WEB3,
            owner: owner,
            duration: duration,
            secret: secret,
            resolver: PUBLIC_RESOLVER,
            resolverData: new bytes[](0),
            reverseRecord: true
        });

        (uint256 base, uint256 premium) = ctrl.rentPrice(label, TLD_WEB3, duration);
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
                console.log("Registered:", label, ".web3");
            }
        }
    }
}
