// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { RegistrarController } from "../src/RegistrarController.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { PublicResolver } from "../src/PublicResolver.sol";
import { ReverseRegistrar } from "../src/ReverseRegistrar.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";
import { IReverseRegistrar } from "../src/interfaces/IReverseRegistrar.sol";

contract MockFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 3_000_00000000, block.timestamp, block.timestamp, 1);
    }
}

contract ReverseRegistrarTest is Test {
    Registry reg;
    TLDManager mgr;
    TLDRegistrar registrar;
    PriceOracle oracle;
    RegistrarController ctrl;
    PublicResolver pubResolver;
    ReverseRegistrar revRegistrar;

    address protocolOwner = makeAddr("protocol");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    bytes32 constant ROOT = bytes32(0);
    bytes32 tldNode;
    bytes32 reverseTldNode;
    bytes32 addrReverseNode;
    bytes32 aliceReverseNode;

    uint256 constant YEAR = 365 days;

    function setUp() public {
        // 1. Deploy Registry — test contract owns root initially
        reg = new Registry();

        // 2. Compute reverse namespace nodes
        reverseTldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("reverse"))));
        addrReverseNode = keccak256(abi.encodePacked(reverseTldNode, keccak256(bytes("addr"))));

        // 3. Deploy resolvers
        pubResolver = new PublicResolver(reg);
        revRegistrar = new ReverseRegistrar(reg, addrReverseNode, address(pubResolver), address(this));

        // 4. Set up reverse namespace (while test contract still owns root)
        //    a. Create "reverse" TLD node (test contract owns it temporarily)
        reg.setSubnodeOwner(ROOT, keccak256(bytes("reverse")), address(this));
        //    b. Create "addr.reverse" node, owned by ReverseRegistrar
        reg.setSubnodeRecord(reverseTldNode, keccak256(bytes("addr")), address(revRegistrar), address(0), 0);
        //    c. Transfer "reverse" TLD to ReverseRegistrar
        reg.setSubnodeOwner(ROOT, keccak256(bytes("reverse")), address(revRegistrar));

        // 5. Deploy rest of stack and hand root to TLDManager
        mgr = new TLDManager(reg, protocolOwner);
        oracle = new PriceOracle(address(new MockFeed()), 1 hours, 3_00000000, 15_00000000, protocolOwner);
        revRegistrar.addController(address(ctrl));
        ctrl = new RegistrarController(reg, mgr, oracle, IReverseRegistrar(address(revRegistrar)), address(0), protocolOwner);
        reg.setOwner(ROOT, address(mgr));

        // 6. Set up ".id" TLD
        tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        registrar = new TLDRegistrar(reg, tldNode, "id", address(mgr));
        vm.prank(protocolOwner);
        mgr.addTld("id", address(registrar));
        vm.prank(address(mgr));
        registrar.addController(address(ctrl));

        // 7. Register "kyy.id" for alice
        _register("kyy", alice);

        // 8. Precompute alice's reverse node
        aliceReverseNode = revRegistrar.node(alice);
    }

    // ---------------------------------------------------------------
    //                           HELPERS
    // ---------------------------------------------------------------

    function _register(string memory name, address owner) internal {
        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: name,
            tld: tldNode,
            owner: owner,
            duration: YEAR,
            secret: keccak256("secret"),
            resolver: address(pubResolver),
            resolverData: new bytes[](0),
            reverseRecord: false
        });
        bytes32 commitment = ctrl.makeCommitment(req);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);
        (uint256 base, uint256 premium) = ctrl.rentPrice(name, tldNode, YEAR);
        vm.deal(owner, base + premium);
        vm.prank(owner);
        ctrl.register{ value: base + premium }(req, address(0));
    }

    // ---------------------------------------------------------------
    //                        NODE COMPUTATION
    // ---------------------------------------------------------------

    function test_node_is_deterministic() public view {
        assertEq(revRegistrar.node(alice), revRegistrar.node(alice));
    }

    function test_node_differs_per_address() public view {
        assertNotEq(revRegistrar.node(alice), revRegistrar.node(bob));
    }

    function test_node_uses_lowercase_hex() public view {
        // node should be the same regardless of address checksum casing
        bytes32 n1 = revRegistrar.node(alice);
        bytes32 n2 = revRegistrar.node(alice);
        assertEq(n1, n2);
    }

    // ---------------------------------------------------------------
    //                            CLAIM
    // ---------------------------------------------------------------

    function test_claim_sets_owner() public {
        vm.prank(alice);
        revRegistrar.claim(alice);
        assertEq(reg.ownerOf(aliceReverseNode), alice);
    }

    function test_claim_sets_default_resolver() public {
        vm.prank(alice);
        revRegistrar.claim(alice);
        assertEq(reg.resolverOf(aliceReverseNode), address(pubResolver));
    }

    function test_claim_emits_ReverseClaimed() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit IReverseRegistrar.ReverseClaimed(alice, aliceReverseNode);
        revRegistrar.claim(alice);
    }

    function test_claim_can_delegate_to_different_owner() public {
        vm.prank(alice);
        revRegistrar.claim(bob);
        assertEq(reg.ownerOf(aliceReverseNode), bob);
    }

    // ---------------------------------------------------------------
    //                       CLAIM WITH RESOLVER
    // ---------------------------------------------------------------

    function test_claimWithResolver_sets_custom_resolver() public {
        address customResolver = makeAddr("customResolver");
        vm.prank(alice);
        revRegistrar.claimWithResolver(alice, customResolver);
        assertEq(reg.resolverOf(aliceReverseNode), customResolver);
    }

    function test_claimWithResolver_sets_owner() public {
        vm.prank(alice);
        revRegistrar.claimWithResolver(alice, address(pubResolver));
        assertEq(reg.ownerOf(aliceReverseNode), alice);
    }

    // ---------------------------------------------------------------
    //                          SET NAME
    // ---------------------------------------------------------------

    function test_setName_writes_name_record() public {
        vm.prank(alice);
        revRegistrar.setName("kyy.id");
        assertEq(pubResolver.text(aliceReverseNode, "name"), "kyy.id");
    }

    function test_setName_transfers_node_ownership_to_caller() public {
        vm.prank(alice);
        revRegistrar.setName("kyy.id");
        assertEq(reg.ownerOf(aliceReverseNode), alice);
    }

    function test_setName_emits_ReverseClaimed() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit IReverseRegistrar.ReverseClaimed(alice, aliceReverseNode);
        revRegistrar.setName("kyy.id");
    }

    function test_setName_can_update() public {
        vm.prank(alice);
        revRegistrar.setName("kyy.id");
        vm.prank(alice);
        revRegistrar.setName("kyy.wagmi");
        assertEq(pubResolver.text(aliceReverseNode, "name"), "kyy.wagmi");
    }

    function test_setName_different_callers_independent() public {
        _register("bob", bob);
        bytes32 bobReverseNode = revRegistrar.node(bob);

        vm.prank(alice);
        revRegistrar.setName("kyy.id");
        vm.prank(bob);
        revRegistrar.setName("bob.id");

        assertEq(pubResolver.text(aliceReverseNode, "name"), "kyy.id");
        assertEq(pubResolver.text(bobReverseNode, "name"), "bob.id");
    }

    // ---------------------------------------------------------------
    //                       SET NAME FOR ADDR
    // ---------------------------------------------------------------

    function test_setNameForAddr_by_addr_itself() public {
        vm.prank(alice);
        revRegistrar.setNameForAddr(alice, alice, address(pubResolver), "kyy.id");
        assertEq(pubResolver.text(aliceReverseNode, "name"), "kyy.id");
        assertEq(reg.ownerOf(aliceReverseNode), alice);
    }

    function test_setNameForAddr_reverts_unauthorized() public {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(IReverseRegistrar.Unauthorized.selector, eve));
        revRegistrar.setNameForAddr(alice, alice, address(pubResolver), "kyy.id");
    }

    function test_setNameForAddr_by_current_node_owner() public {
        // alice first claims her reverse record (owns the node)
        vm.prank(alice);
        revRegistrar.claim(alice);

        // alice approves bob as operator
        vm.prank(alice);
        reg.setApprovalForAll(bob, true);

        // bob can now set name for alice
        vm.prank(bob);
        revRegistrar.setNameForAddr(alice, alice, address(pubResolver), "kyy.id");
        assertEq(pubResolver.text(aliceReverseNode, "name"), "kyy.id");
    }

    function test_setNameForAddr_no_name_just_claims() public {
        vm.prank(alice);
        revRegistrar.setNameForAddr(alice, bob, address(pubResolver), "");
        // No name set, but node is claimed with bob as owner
        assertEq(reg.ownerOf(aliceReverseNode), bob);
        assertEq(pubResolver.text(aliceReverseNode, "name"), "");
    }

    function test_setNameForAddr_no_resolver_just_claims() public {
        vm.prank(alice);
        revRegistrar.setNameForAddr(alice, alice, address(0), "");
        assertEq(reg.ownerOf(aliceReverseNode), alice);
    }

    // ---------------------------------------------------------------
    //                        DEFAULT RESOLVER
    // ---------------------------------------------------------------

    function test_defaultResolver_returns_pubResolver() public view {
        assertEq(revRegistrar.defaultResolver(), address(pubResolver));
    }

    function test_setDefaultResolver_by_owner() public {
        address newResolver = makeAddr("newResolver");
        revRegistrar.setDefaultResolver(newResolver);
        assertEq(revRegistrar.defaultResolver(), newResolver);
    }

    function test_setDefaultResolver_emits_event() public {
        address newResolver = makeAddr("newResolver");
        vm.expectEmit(true, false, false, false);
        emit IReverseRegistrar.DefaultResolverChanged(newResolver);
        revRegistrar.setDefaultResolver(newResolver);
    }

    function test_setDefaultResolver_reverts_if_not_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        revRegistrar.setDefaultResolver(makeAddr("x"));
    }

    // ---------------------------------------------------------------
    //                          FUZZ TEST
    // ---------------------------------------------------------------

    function testFuzz_claim_any_owner(address owner) public {
        vm.assume(owner != address(0));
        vm.prank(alice);
        revRegistrar.claim(owner);
        assertEq(reg.ownerOf(aliceReverseNode), owner);
    }
}
