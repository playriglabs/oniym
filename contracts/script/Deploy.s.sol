// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { RegistrarController } from "../src/RegistrarController.sol";
import { PriceOracle } from "../src/PriceOracle.sol";

/// @dev Base Sepolia Chainlink ETH/USD feed (8 decimals)
address constant BASE_SEPOLIA_ETH_USD_FEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;

/// @dev $7.00/month ($84.00/year) in Chainlink's 1e8 USD units
uint256 constant BASE_PRICE_USD = 84_00000000;

/// @dev 1 hour staleness window
uint256 constant MAX_STALENESS = 1 hours;

contract Deploy is Script {
    // Initial TLDs to register
    string[] internal _tldLabels;

    function setUp() public {
        // General identity
        _tldLabels.push("id");
        _tldLabels.push("one");
        _tldLabels.push("me");
        _tldLabels.push("co");
        // Web3 / tech signals
        _tldLabels.push("xyz");
        _tldLabels.push("web3");
        _tldLabels.push("io");
        _tldLabels.push("pro");
        _tldLabels.push("app");
        _tldLabels.push("dev");
        _tldLabels.push("onm");
        _tldLabels.push("go");
        // Crypto culture
        _tldLabels.push("ape");
        _tldLabels.push("fud");
        _tldLabels.push("hodl");
        _tldLabels.push("fomo");
        _tldLabels.push("moon");
        _tldLabels.push("rekt");
        _tldLabels.push("wagmi");
        _tldLabels.push("ngmi");
        _tldLabels.push("degen");
        _tldLabels.push("whale");
        _tldLabels.push("buidl");
        _tldLabels.push("dyor");
        _tldLabels.push("pump");
        _tldLabels.push("alpha");
        _tldLabels.push("safu");
        _tldLabels.push("l2");
        _tldLabels.push("gm");
        _tldLabels.push("lfg");
        _tldLabels.push("ser");
        _tldLabels.push("fren");
        _tldLabels.push("goat");
        _tldLabels.push("cope");
        _tldLabels.push("pepe");
        _tldLabels.push("wen");
        // Finance / DeFi
        _tldLabels.push("mint");
        _tldLabels.push("bear");
        _tldLabels.push("gas");
        _tldLabels.push("dao");
        _tldLabels.push("ath");
        _tldLabels.push("dex");
        _tldLabels.push("cex");
        _tldLabels.push("burn");
        _tldLabels.push("node");
        _tldLabels.push("swap");
        _tldLabels.push("yield");
        _tldLabels.push("bag");
        _tldLabels.push("bags");
        _tldLabels.push("seed");
        _tldLabels.push("drop");
        _tldLabels.push("stake");
        _tldLabels.push("pool");
        _tldLabels.push("wrap");
        _tldLabels.push("farm");
        _tldLabels.push("shill");
        // Misc
        _tldLabels.push("xxx");
        _tldLabels.push("regs");
        _tldLabels.push("main");
        _tldLabels.push("test");
        _tldLabels.push("exit");
        _tldLabels.push("fair");
        _tldLabels.push("guh");
        _tldLabels.push("bots");
        _tldLabels.push("keys");
    }

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // Allow overriding the price feed via env (e.g. for forks or other networks)
        address feed = vm.envOr("CHAINLINK_ETH_USD_FEED", BASE_SEPOLIA_ETH_USD_FEED);

        vm.startBroadcast(pk);

        // 1. Core registry
        Registry registry = new Registry();
        console.log("Registry:             ", address(registry));

        // 2. TLD manager (owns the registry root after step 3)
        TLDManager tldManager = new TLDManager(registry, deployer);
        console.log("TLDManager:           ", address(tldManager));

        // 3. Hand root node to TLDManager
        registry.setOwner(bytes32(0), address(tldManager));

        // 4. Price oracle
        PriceOracle priceOracle = new PriceOracle(feed, MAX_STALENESS, BASE_PRICE_USD, deployer);
        console.log("PriceOracle:          ", address(priceOracle));

        // 5. Registrar controller
        RegistrarController controller = new RegistrarController(
            registry,
            tldManager,
            priceOracle,
            deployer
        );
        console.log("RegistrarController:  ", address(controller));

        // 6. Deploy TLDs and wire up controller
        for (uint256 i = 0; i < _tldLabels.length; i++) {
            string memory label = _tldLabels[i];

            bytes32 labelHash = keccak256(bytes(label));
            bytes32 tldNode = keccak256(abi.encodePacked(bytes32(0), labelHash));

            TLDRegistrar registrar = new TLDRegistrar(
                registry,
                tldNode,
                label,
                address(tldManager)
            );
            console.log(string.concat("TLDRegistrar .", label, ":"), address(registrar));

            tldManager.addTld(label, address(registrar));
            tldManager.addControllerToRegistrar(tldNode, address(controller));
        }

        vm.stopBroadcast();

        // Summary
        console.log("\n=== Deployment complete ===");
        console.log("Network:              Base Sepolia");
        console.log("Deployer:             ", deployer);
        console.log("ETH/USD feed:         ", feed);
    }
}
