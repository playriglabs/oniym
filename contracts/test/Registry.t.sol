// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";

contract RegistryTest is Test {
    Registry reg;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    bytes32 constant ROOT = bytes32(0);
    bytes32 constant LABEL_ID = keccak256("id");
    bytes32 constant LABEL_KYY = keccak256("kyy");

    // namehash("id") = keccak256(ROOT ++ keccak256("id"))
    bytes32 tldNode;
    // namehash("kyy.id")
    bytes32 nameNode;

    function setUp() public {
        reg = new Registry();
        // root is owned by test contract (deployer)
        tldNode = keccak256(abi.encodePacked(ROOT, LABEL_ID));
        nameNode = keccak256(abi.encodePacked(tldNode, LABEL_KYY));
    }

    // ---------------------------------------------------------------
    //                        ROOT SETUP
    // ---------------------------------------------------------------

    function test_deployer_owns_root() public view {
        assertEq(reg.ownerOf(ROOT), address(this));
    }

    function test_setOwner_root_to_alice() public {
        reg.setOwner(ROOT, alice);
        assertEq(reg.ownerOf(ROOT), alice);
    }

    function test_setOwner_reverts_if_not_authorised() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector, ROOT, alice));
        reg.setOwner(ROOT, alice);
    }

    // ---------------------------------------------------------------
    //                      SUBNODE CREATION
    // ---------------------------------------------------------------

    function test_setSubnodeOwner_creates_tld() public {
        bytes32 node = reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        assertEq(node, tldNode);
        assertEq(reg.ownerOf(tldNode), alice);
    }

    function test_setSubnodeOwner_emits_NewOwner() public {
        vm.expectEmit(true, true, false, true);
        emit IRegistry.NewOwner(ROOT, LABEL_ID, alice);
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
    }

    function test_setSubnodeOwner_reverts_if_not_authorised() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector, ROOT, bob));
        reg.setSubnodeOwner(ROOT, LABEL_ID, bob);
    }

    function test_setSubnodeRecord_creates_name() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        bytes32 node = reg.setSubnodeRecord(
            tldNode, LABEL_KYY, bob, carol, uint64(block.timestamp + 365 days)
        );
        assertEq(node, nameNode);
        assertEq(reg.ownerOf(nameNode), bob);
        assertEq(reg.resolverOf(nameNode), carol);
        assertEq(reg.expiresAt(nameNode), uint64(block.timestamp + 365 days));
    }

    // ---------------------------------------------------------------
    //                          RESOLVER
    // ---------------------------------------------------------------

    function test_setResolver() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setResolver(tldNode, carol);
        assertEq(reg.resolverOf(tldNode), carol);
    }

    function test_setResolver_reverts_if_not_authorised() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector, tldNode, bob));
        reg.setResolver(tldNode, carol);
    }

    // ---------------------------------------------------------------
    //                           EXPIRY
    // ---------------------------------------------------------------

    function test_setExpiry_by_parent_owner() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), uint64(block.timestamp + 365 days));

        uint64 newExpiry = uint64(block.timestamp + 730 days);
        vm.prank(alice);
        reg.setExpiry(nameNode, newExpiry);
        assertEq(reg.expiresAt(nameNode), newExpiry);
    }

    function test_setExpiry_reverts_if_not_parent_owner() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), uint64(block.timestamp + 365 days));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector, nameNode, bob));
        reg.setExpiry(nameNode, uint64(block.timestamp + 730 days));
    }

    function test_setExpiry_reverts_zero() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), uint64(block.timestamp + 365 days));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.InvalidExpiry.selector, uint64(0)));
        reg.setExpiry(nameNode, 0);
    }

    function test_ownerOf_returns_zero_after_expiry() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        uint64 exp = uint64(block.timestamp + 100);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), exp);

        assertEq(reg.ownerOf(nameNode), bob);
        vm.warp(block.timestamp + 101);
        assertEq(reg.ownerOf(nameNode), address(0));
    }

    function test_permanent_node_never_expires() public {
        // TLD root nodes use expires == 0 (permanent)
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        assertEq(reg.expiresAt(tldNode), 0);

        vm.warp(block.timestamp + 365 days * 100);
        assertEq(reg.ownerOf(tldNode), alice);
    }

    // ---------------------------------------------------------------
    //                     APPROVAL FOR ALL
    // ---------------------------------------------------------------

    function test_operator_can_act_on_behalf() public {
        reg.setApprovalForAll(alice, true);
        assertTrue(reg.isApprovedForAll(address(this), alice));

        vm.prank(alice);
        reg.setSubnodeOwner(ROOT, LABEL_ID, bob);
        assertEq(reg.ownerOf(tldNode), bob);
    }

    function test_revoke_operator() public {
        reg.setApprovalForAll(alice, true);
        reg.setApprovalForAll(alice, false);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistry.Unauthorized.selector, ROOT, alice));
        reg.setSubnodeOwner(ROOT, LABEL_ID, bob);
    }

    // ---------------------------------------------------------------
    //                       RECORD EXISTS
    // ---------------------------------------------------------------

    function test_recordExists_false_for_unknown_node() public view {
        assertFalse(reg.recordExists(keccak256("unknown")));
    }

    function test_recordExists_true_after_subnode_created() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        assertTrue(reg.recordExists(tldNode));
    }

    function test_recordExists_true_even_after_expiry() public {
        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), uint64(block.timestamp + 1));
        vm.warp(block.timestamp + 2);
        // ownerOf returns 0 but recordExists stays true
        assertEq(reg.ownerOf(nameNode), address(0));
        assertTrue(reg.recordExists(nameNode));
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_subnode_is_deterministic(bytes32 parent, bytes32 label) public view {
        bytes32 a = keccak256(abi.encodePacked(parent, label));
        bytes32 b = keccak256(abi.encodePacked(parent, label));
        assertEq(a, b);
    }

    function testFuzz_ownership_transfer(address owner1, address owner2) public {
        vm.assume(owner1 != address(0) && owner2 != address(0));
        vm.assume(owner1 != owner2);

        reg.setSubnodeOwner(ROOT, LABEL_ID, owner1);
        assertEq(reg.ownerOf(tldNode), owner1);

        vm.prank(owner1);
        reg.setOwner(tldNode, owner2);
        assertEq(reg.ownerOf(tldNode), owner2);
    }

    function testFuzz_expiry_after_warp(uint64 expiry, uint64 warpTo) public {
        vm.assume(expiry > block.timestamp && expiry < type(uint64).max - 1);

        reg.setSubnodeOwner(ROOT, LABEL_ID, alice);
        vm.prank(alice);
        reg.setSubnodeRecord(tldNode, LABEL_KYY, bob, address(0), expiry);

        vm.warp(warpTo);
        if (warpTo > expiry) {
            assertEq(reg.ownerOf(nameNode), address(0));
        } else {
            assertEq(reg.ownerOf(nameNode), bob);
        }
    }
}
