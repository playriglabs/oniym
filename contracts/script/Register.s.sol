// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";
import { IPriceOracle } from "../src/interfaces/IPriceOracle.sol";

contract Register is Script {
    address constant REGISTRAR_CONTROLLER = 0xb0d499a5c8E3Dc9Db30b7c3F685b2D5D8D62F69a;
    address constant PUBLIC_RESOLVER = 0xE951cE73Da1d75730e56Df79844BFA745FA589D3;
    address constant PRICE_ORACLE = 0x7Ff70eA1a39FB0B46e986f6C8AaE5F9Dc9c11E28;

    // keccak256(abi.encodePacked(bytes32(0), keccak256("app")))
    bytes32 constant TLD_APP = 0xf7e1414e83ef17e770a253cedccf6316ed40eab77328b139fc18136b2e1a2ae4;

    function run() external {
        address owner = vm.envOr("REGISTER_OWNER", vm.envAddress("DEPLOYER_ADDRESS"));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory label = vm.envOr("REGISTER_LABEL", string("kite"));
        uint256 duration = vm.envOr("REGISTER_DURATION", uint256(30 days));
        // address(0) = ETH (default), any other address = that ERC-20 token (e.g. USDC)
        address paymentToken = vm.envOr("PAYMENT_TOKEN", address(0));
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

        bytes32 commitment = ctrl.makeCommitment(req);
        console.log("Commitment:");
        console.logBytes32(commitment);

        if (paymentToken == address(0)) {
            (uint256 base, uint256 premium) = ctrl.rentPrice(label, TLD_APP, duration);
            uint256 total = base + premium;
            console.log("Payment: ETH");
            console.log("Price (wei):", total);

            uint256 existing = ctrl.commitments(commitment);
            if (existing == 0) {
                vm.startBroadcast(pk);
                ctrl.commit(commitment);
                vm.stopBroadcast();
                console.log("Committed - wait 60s then run again");
            } else {
                uint256 age = block.timestamp - existing;
                console.log("Commitment age (s):", age);
                if (age < ctrl.MIN_COMMITMENT_AGE()) {
                    console.log("Too early - wait", ctrl.MIN_COMMITMENT_AGE() - age, "more seconds");
                } else {
                    vm.startBroadcast(pk);
                    ctrl.register{ value: total }(req, address(0));
                    vm.stopBroadcast();
                    console.log("Registered:", label, ".app");
                }
            }
        } else {
            uint256 usdcAmount = IPriceOracle(PRICE_ORACLE).priceUsdc(label, 0, duration);
            console.log("Payment: ERC-20", paymentToken);
            console.log("Price (token units):", usdcAmount);

            uint256 existing = ctrl.commitments(commitment);
            if (existing == 0) {
                vm.startBroadcast(pk);
                ctrl.commit(commitment);
                vm.stopBroadcast();
                console.log("Committed - wait 60s then run again");
            } else {
                uint256 age = block.timestamp - existing;
                console.log("Commitment age (s):", age);
                if (age < ctrl.MIN_COMMITMENT_AGE()) {
                    console.log("Too early - wait", ctrl.MIN_COMMITMENT_AGE() - age, "more seconds");
                } else {
                    vm.startBroadcast(pk);
                    IERC20(paymentToken).approve(address(ctrl), usdcAmount);
                    ctrl.register(req, paymentToken);
                    vm.stopBroadcast();
                    console.log("Registered:", label, ".app");
                }
            }
        }
    }
}
