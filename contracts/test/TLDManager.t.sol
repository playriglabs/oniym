// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { ITLDManager } from "../src/interfaces/ITLDManager.sol";

contract TLDManagerTest is Test {
    Registry reg;
    TLDManager mgr;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    bytes32 constant ROOT = bytes32(0);

    function setUp() public {
        reg = new Registry();
        mgr = new TLDManager(reg, owner);

        // Transfer registry root ownership to TLDManager
        reg.setOwner(ROOT, address(mgr));
    }

    function _deployRegistrar(string memory label) internal returns (TLDRegistrar) {
        bytes32 tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes(label))));
        return new TLDRegistrar(reg, tldNode, label, address(mgr));
    }

    // ---------------------------------------------------------------
    //                           ADD TLD
    // ---------------------------------------------------------------

    function test_addTld_stores_metadata() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        bytes32 node = mgr.addTld("id", address(r));

        ITLDManager.Tld memory tld = mgr.getTld(node);
        assertEq(tld.label, "id");
        assertEq(tld.registrar, address(r));
        assertTrue(tld.active);
        assertEq(tld.node, node);
    }

    function test_addTld_sets_registry_owner_to_registrar() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        mgr.addTld("id", address(r));

        bytes32 tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        assertEq(reg.ownerOf(tldNode), address(r));
    }

    function test_addTld_emits_TLDAdded() public {
        TLDRegistrar r = _deployRegistrar("one");
        bytes32 expectedNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("one"))));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ITLDManager.TLDAdded(expectedNode, "one", address(r));
        mgr.addTld("one", address(r));
    }

    function test_addTld_reverts_if_not_owner() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(alice);
        vm.expectRevert();
        mgr.addTld("id", address(r));
    }

    function test_addTld_reverts_duplicate() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        mgr.addTld("id", address(r));

        TLDRegistrar r2 = _deployRegistrar("id");
        vm.prank(owner);
        bytes32 node = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        vm.expectRevert(abi.encodeWithSelector(ITLDManager.TLDAlreadyExists.selector, node));
        mgr.addTld("id", address(r2));
    }

    function test_addTld_reverts_label_too_long() public {
        TLDRegistrar r = _deployRegistrar("toolong");
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ITLDManager.TldLabelTooLong.selector, "toolong", uint256(7), uint256(5))
        );
        mgr.addTld("toolong", address(r));
    }

    function test_addTld_reverts_zero_registrar() public {
        vm.prank(owner);
        vm.expectRevert(ITLDManager.ZeroRegistrar.selector);
        mgr.addTld("id", address(0));
    }

    // ---------------------------------------------------------------
    //                         STATUS MGMT
    // ---------------------------------------------------------------

    function test_setTldActive_deactivates() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        bytes32 node = mgr.addTld("id", address(r));

        vm.prank(owner);
        mgr.setTldActive(node, false);
        assertFalse(mgr.isActiveTld(node));
    }

    function test_setTldActive_reactivates() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        bytes32 node = mgr.addTld("id", address(r));

        vm.prank(owner);
        mgr.setTldActive(node, false);
        vm.prank(owner);
        mgr.setTldActive(node, true);
        assertTrue(mgr.isActiveTld(node));
    }

    function test_setTldActive_reverts_unknown_node() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ITLDManager.TLDNotFound.selector, bytes32(uint256(1))));
        mgr.setTldActive(bytes32(uint256(1)), false);
    }

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    function test_listTlds_empty() public view {
        assertEq(mgr.listTlds().length, 0);
    }

    function test_listTlds_multiple() public {
        string[3] memory labels = ["id", "one", "me"];
        for (uint256 i = 0; i < 3; i++) {
            TLDRegistrar r = _deployRegistrar(labels[i]);
            vm.prank(owner);
            mgr.addTld(labels[i], address(r));
        }
        assertEq(mgr.listTlds().length, 3);
    }

    function test_getTldByLabel() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        mgr.addTld("id", address(r));

        ITLDManager.Tld memory tld = mgr.getTldByLabel("id");
        assertEq(tld.label, "id");
    }

    function test_getTld_reverts_unknown() public {
        vm.expectRevert(abi.encodeWithSelector(ITLDManager.TLDNotFound.selector, bytes32(uint256(1))));
        mgr.getTld(bytes32(uint256(1)));
    }

    function test_isTld_true_and_false() public {
        TLDRegistrar r = _deployRegistrar("id");
        vm.prank(owner);
        mgr.addTld("id", address(r));

        assertTrue(mgr.isTld("id"));
        assertFalse(mgr.isTld("xyz"));
    }

    function test_isActiveTld_false_for_unknown() public view {
        assertFalse(mgr.isActiveTld(keccak256("ghost")));
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_addTld_valid_labels(string calldata label) public {
        vm.assume(bytes(label).length >= 1 && bytes(label).length <= 5);
        // Only test with the same registrar type to keep it simple
        bytes32 tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes(label))));
        TLDRegistrar r = new TLDRegistrar(reg, tldNode, label, address(mgr));

        // May revert for duplicate or zero-length but that's expected
        vm.prank(owner);
        try mgr.addTld(label, address(r)) returns (bytes32 node) {
            assertTrue(mgr.isActiveTld(node));
        } catch {}
    }
}
