// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { RegistrarController } from "../src/RegistrarController.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { PublicResolver } from "../src/PublicResolver.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";

/// @notice ENS mainnet gas reference (from public benchmarks, Solidity 0.8.17):
///   ETHRegistrarController.register  ~280 000 gas
///   ETHRegistrarController.renew     ~ 60 000 gas
///   PublicResolver.setAddr            ~ 45 000 gas
///   PublicResolver.setText            ~ 46 000 gas

contract MockFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 3_000_00000000, block.timestamp, block.timestamp, 1);
    }
}

contract GasBenchmarkTest is Test {
    Registry reg;
    TLDManager mgr;
    TLDRegistrar registrar;
    PriceOracle oracle;
    RegistrarController ctrl;
    PublicResolver resolver;

    address protocolOwner = makeAddr("protocol");
    address alice = makeAddr("alice");

    bytes32 constant ROOT = bytes32(0);
    bytes32 tldNode;
    bytes32 nameNode;
    uint256 tokenId;

    uint256 constant YEAR = 365 days;
    uint256 constant COIN_ETH = 60;
    uint256 constant COIN_SOL = 501;

    IRegistrarController.RegisterRequest baseReq;

    function setUp() public {
        reg = new Registry();
        mgr = new TLDManager(reg, protocolOwner);
        oracle = new PriceOracle(address(new MockFeed()), 1 hours, 5_00000000, protocolOwner);
        ctrl = new RegistrarController(reg, mgr, oracle, protocolOwner);
        resolver = new PublicResolver(reg);

        reg.setOwner(ROOT, address(mgr));

        tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        registrar = new TLDRegistrar(reg, tldNode, "id", address(mgr));

        vm.prank(protocolOwner);
        mgr.addTld("id", address(registrar));
        vm.prank(address(mgr));
        registrar.addController(address(ctrl));

        tokenId = uint256(keccak256(bytes("kyy")));
        nameNode = keccak256(abi.encodePacked(tldNode, bytes32(tokenId)));

        baseReq = IRegistrarController.RegisterRequest({
            name: "kyy",
            tld: tldNode,
            owner: alice,
            duration: YEAR,
            secret: bytes32("secret"),
            resolver: address(0),
            resolverData: new bytes[](0),
            reverseRecord: false
        });
    }

    // ---------------------------------------------------------------
    //                    REGISTRATION GAS
    // ---------------------------------------------------------------

    /// @dev Measures commit() gas — first step of commit-reveal.
    function test_gas_commit() public {
        bytes32 commitment = ctrl.makeCommitment(baseReq);
        uint256 gasBefore = gasleft();
        ctrl.commit(commitment);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("commit() gas", gasUsed);
        // ENS reference: ~47 000. Expect similar.
        assertLt(gasUsed, 60_000, "commit() regression");
    }

    /// @dev Measures register() gas — full registration with no resolver data.
    function test_gas_register_no_resolver() public {
        bytes32 commitment = ctrl.makeCommitment(baseReq);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);

        (uint256 base, uint256 premium) = ctrl.rentPrice("kyy", tldNode, YEAR);
        vm.deal(alice, base + premium);

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        ctrl.register{ value: base + premium }(baseReq);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("register() no resolver gas", gasUsed);
        // ENS reference: ~280 000. Multi-TLD adds overhead; target <350 000.
        assertLt(gasUsed, 350_000, "register() regression");
    }

    /// @dev Measures register() gas when a resolver and ETH address record are set atomically.
    function test_gas_register_with_resolver_and_addr() public {
        bytes memory ethAddrData = abi.encodeWithSignature(
            "setAddr(bytes32,uint256,bytes)", nameNode, COIN_ETH, abi.encodePacked(alice)
        );
        bytes[] memory resolverData = new bytes[](1);
        resolverData[0] = ethAddrData;

        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: "kyy",
            tld: tldNode,
            owner: alice,
            duration: YEAR,
            secret: bytes32("secret"),
            resolver: address(resolver),
            resolverData: resolverData,
            reverseRecord: false
        });

        bytes32 commitment = ctrl.makeCommitment(req);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);

        (uint256 base, uint256 premium) = ctrl.rentPrice("kyy", tldNode, YEAR);
        vm.deal(alice, base + premium);

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        ctrl.register{ value: base + premium }(req);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("register() + setAddr gas", gasUsed);
        assertLt(gasUsed, 420_000, "register()+addr regression");
    }

    // ---------------------------------------------------------------
    //                      RENEWAL GAS
    // ---------------------------------------------------------------

    /// @dev Measures renew() gas.
    function test_gas_renew() public {
        // Register first
        bytes32 commitment = ctrl.makeCommitment(baseReq);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);
        (uint256 base, uint256 premium) = ctrl.rentPrice("kyy", tldNode, YEAR);
        vm.deal(alice, (base + premium) * 2);
        vm.prank(alice);
        ctrl.register{ value: base + premium }(baseReq);

        // Renew
        (uint256 renewBase, uint256 renewPremium) = ctrl.rentPrice("kyy", tldNode, YEAR);
        uint256 renewPrice = renewBase + renewPremium;
        vm.deal(alice, renewPrice);

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        ctrl.renew{ value: renewPrice }("kyy", tldNode, YEAR);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("renew() gas", gasUsed);
        // ENS reference: ~60 000. Expect similar.
        assertLt(gasUsed, 80_000, "renew() regression");
    }

    // ---------------------------------------------------------------
    //                      RESOLVER GAS
    // ---------------------------------------------------------------

    function _registerAndGetNameNode() internal {
        bytes32 commitment = ctrl.makeCommitment(baseReq);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);
        (uint256 base, uint256 premium) = ctrl.rentPrice("kyy", tldNode, YEAR);
        vm.deal(alice, base + premium);
        vm.prank(alice);
        ctrl.register{ value: base + premium }(baseReq);

        // Set resolver
        vm.prank(alice);
        reg.setResolver(nameNode, address(resolver));
    }

    /// @dev setAddr() first write (cold storage)
    function test_gas_setAddr_cold() public {
        _registerAndGetNameNode();

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(alice));
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("setAddr() cold gas", gasUsed);
        // ENS reference: ~45 000. Expect similar.
        assertLt(gasUsed, 65_000, "setAddr() cold regression");
    }

    /// @dev setAddr() second write (warm storage — updating existing value)
    function test_gas_setAddr_warm() public {
        _registerAndGetNameNode();
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(alice));

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(bob));
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("setAddr() warm gas", gasUsed);
        assertLt(gasUsed, 40_000, "setAddr() warm regression");
    }

    /// @dev setText() cold write
    function test_gas_setText_cold() public {
        _registerAndGetNameNode();

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        resolver.setText(nameNode, "twitter", "@kyy");
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("setText() cold gas", gasUsed);
        // ENS reference: ~46 000. Expect similar.
        assertLt(gasUsed, 65_000, "setText() cold regression");
    }

    /// @dev setAddr() for a second coin type (Solana) — independent slot
    function test_gas_setAddr_solana() public {
        _registerAndGetNameNode();

        bytes memory solAddr = bytes("SoL1111111111111111111111111111111111111112");
        uint256 gasBefore = gasleft();
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_SOL, solAddr);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("setAddr() SOL cold gas", gasUsed);
        assertLt(gasUsed, 100_000, "setAddr() SOL regression");
    }

    // ---------------------------------------------------------------
    //                      REGISTRY GAS
    // ---------------------------------------------------------------

    /// @dev setSubnodeOwner() — used heavily during registration
    function test_gas_registry_setSubnodeOwner() public {
        // Root is owned by TLDManager; test the subnode write cost directly via registrar
        _registerAndGetNameNode();

        uint256 gasBefore = gasleft();
        vm.prank(alice);
        registrar.reclaim(tokenId, alice);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("reclaim() (setSubnodeOwner) gas", gasUsed);
        assertLt(gasUsed, 40_000, "reclaim() regression");
    }

    address bob = makeAddr("bob");
}
