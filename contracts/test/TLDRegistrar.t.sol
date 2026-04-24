// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { ITLDRegistrar } from "../src/interfaces/ITLDRegistrar.sol";

contract TLDRegistrarTest is Test {
    Registry reg;
    TLDRegistrar registrar;

    address owner = makeAddr("owner");
    address controller = makeAddr("controller");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    bytes32 constant ROOT = bytes32(0);
    bytes32 constant LABEL_ID = keccak256("id");
    bytes32 tldNode;

    uint256 tokenId; // uint256(keccak256("kyy"))
    bytes32 nameLabel;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant GRACE = 90 days;

    function setUp() public {
        reg = new Registry();
        tldNode = keccak256(abi.encodePacked(ROOT, LABEL_ID));

        // Deploy registrar; owner will be set as TLDManager later — use `owner` here
        registrar = new TLDRegistrar(reg, tldNode, "id", owner);

        // Give registrar ownership of the TLD root in the registry
        reg.setSubnodeOwner(ROOT, LABEL_ID, address(registrar));

        // Authorise controller
        vm.prank(owner);
        registrar.addController(controller);

        nameLabel = keccak256("kyy");
        tokenId = uint256(nameLabel);
    }

    // ---------------------------------------------------------------
    //                         METADATA
    // ---------------------------------------------------------------

    function test_tldLabel() public view {
        assertEq(registrar.tldLabel(), "id");
    }

    function test_baseNode() public view {
        assertEq(registrar.baseNode(), tldNode);
    }

    function test_nft_name_and_symbol() public view {
        assertEq(registrar.name(), "Oniym .id");
        assertEq(registrar.symbol(), "ONM.id");
    }

    // ---------------------------------------------------------------
    //                        CONTROLLER MGMT
    // ---------------------------------------------------------------

    function test_addController() public {
        address newCtrl = makeAddr("ctrl2");
        vm.prank(owner);
        registrar.addController(newCtrl);
        assertTrue(registrar.isController(newCtrl));
    }

    function test_removeController() public {
        vm.prank(owner);
        registrar.removeController(controller);
        assertFalse(registrar.isController(controller));
    }

    function test_register_reverts_if_not_controller() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITLDRegistrar.NotController.selector, alice));
        registrar.register(tokenId, alice, ONE_YEAR);
    }

    // ---------------------------------------------------------------
    //                          REGISTER
    // ---------------------------------------------------------------

    function test_register_mints_nft_and_sets_registry() public {
        vm.prank(controller);
        uint256 expires = registrar.register(tokenId, alice, ONE_YEAR);

        // NFT minted to alice
        assertEq(registrar.ownerOf(tokenId), alice);
        // Registry subnode set
        bytes32 nameNode = keccak256(abi.encodePacked(tldNode, nameLabel));
        assertEq(reg.ownerOf(nameNode), alice);
        // Expiry stored correctly
        assertEq(registrar.nameExpires(tokenId), expires);
        assertEq(expires, block.timestamp + ONE_YEAR);
    }

    function test_register_emits_NameRegistered() public {
        vm.prank(controller);
        vm.expectEmit(true, true, false, true);
        emit ITLDRegistrar.NameRegistered(tokenId, alice, block.timestamp + ONE_YEAR);
        registrar.register(tokenId, alice, ONE_YEAR);
    }

    function test_register_reverts_if_name_taken() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);

        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(ITLDRegistrar.NameUnavailable.selector, tokenId));
        registrar.register(tokenId, bob, ONE_YEAR);
    }

    function test_register_reverts_below_min_duration() public {
        vm.prank(controller);
        vm.expectRevert(
            abi.encodeWithSelector(ITLDRegistrar.InvalidDuration.selector, 1 days)
        );
        registrar.register(tokenId, alice, 1 days);
    }

    function test_register_available_after_grace_period() public {
        vm.prank(controller);
        uint256 expires = registrar.register(tokenId, alice, ONE_YEAR);

        // Still in grace period
        vm.warp(expires + GRACE - 1);
        assertFalse(registrar.available(tokenId));

        // Past grace period
        vm.warp(expires + GRACE + 1);
        assertTrue(registrar.available(tokenId));

        // Re-register works
        vm.prank(controller);
        registrar.register(tokenId, bob, ONE_YEAR);
        assertEq(registrar.ownerOf(tokenId), bob);
    }

    // ---------------------------------------------------------------
    //                           RENEW
    // ---------------------------------------------------------------

    function test_renew_extends_expiry() public {
        vm.prank(controller);
        uint256 expires = registrar.register(tokenId, alice, ONE_YEAR);

        vm.prank(controller);
        uint256 newExpires = registrar.renew(tokenId, ONE_YEAR);

        assertEq(newExpires, expires + ONE_YEAR);
        assertEq(registrar.nameExpires(tokenId), newExpires);
    }

    function test_renew_emits_NameRenewed() public {
        vm.prank(controller);
        uint256 expires = registrar.register(tokenId, alice, ONE_YEAR);

        vm.prank(controller);
        vm.expectEmit(true, false, false, true);
        emit ITLDRegistrar.NameRenewed(tokenId, expires + ONE_YEAR);
        registrar.renew(tokenId, ONE_YEAR);
    }

    function test_renew_reverts_if_never_registered() public {
        vm.prank(controller);
        vm.expectRevert(abi.encodeWithSelector(ITLDRegistrar.NameUnavailable.selector, tokenId));
        registrar.renew(tokenId, ONE_YEAR);
    }

    function test_renew_reverts_below_min_duration() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);

        vm.prank(controller);
        vm.expectRevert(
            abi.encodeWithSelector(ITLDRegistrar.InvalidDuration.selector, 1 days)
        );
        registrar.renew(tokenId, 1 days);
    }

    // ---------------------------------------------------------------
    //                           RECLAIM
    // ---------------------------------------------------------------

    function test_reclaim_syncs_registry_to_new_nft_owner() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);

        // Transfer NFT to bob
        vm.prank(alice);
        registrar.transferFrom(alice, bob, tokenId);

        bytes32 nameNode = keccak256(abi.encodePacked(tldNode, nameLabel));
        // _update hook auto-synced registry
        assertEq(reg.ownerOf(nameNode), bob);
    }

    function test_reclaim_manual_by_nft_owner() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);

        bytes32 nameNode = keccak256(abi.encodePacked(tldNode, nameLabel));

        // Alice manually reclaims to carol
        vm.prank(alice);
        registrar.reclaim(tokenId, makeAddr("carol"));
        assertEq(reg.ownerOf(nameNode), makeAddr("carol"));
    }

    function test_reclaim_reverts_if_not_nft_owner() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ITLDRegistrar.NotTokenOwner.selector, tokenId, bob));
        registrar.reclaim(tokenId, bob);
    }

    // ---------------------------------------------------------------
    //                        AVAILABILITY
    // ---------------------------------------------------------------

    function test_available_true_for_unregistered() public view {
        assertTrue(registrar.available(tokenId));
    }

    function test_available_false_during_active_registration() public {
        vm.prank(controller);
        registrar.register(tokenId, alice, ONE_YEAR);
        assertFalse(registrar.available(tokenId));
    }

    // ---------------------------------------------------------------
    //                         FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_register_and_renew(uint256 duration1, uint256 duration2) public {
        uint256 min = registrar.minRegistrationDuration();
        duration1 = bound(duration1, min, 10 * 365 days);
        duration2 = bound(duration2, min, 10 * 365 days);

        vm.prank(controller);
        uint256 exp1 = registrar.register(tokenId, alice, duration1);
        assertEq(exp1, block.timestamp + duration1);

        vm.prank(controller);
        uint256 exp2 = registrar.renew(tokenId, duration2);
        assertEq(exp2, exp1 + duration2);
    }
}
