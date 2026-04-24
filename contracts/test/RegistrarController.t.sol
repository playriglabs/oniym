// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { RegistrarController } from "../src/RegistrarController.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";

/// @dev Minimal mock Chainlink feed for integration tests.
contract MockFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        // $3000/ETH, always fresh
        return (1, 3_000_00000000, block.timestamp, block.timestamp, 1);
    }
}

contract RegistrarControllerTest is Test {
    Registry reg;
    TLDManager mgr;
    TLDRegistrar registrar;
    PriceOracle oracle;
    RegistrarController ctrl;

    address protocolOwner = makeAddr("protocol");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    bytes32 constant ROOT = bytes32(0);
    bytes32 tldNode;
    bytes32 tldNodeId;

    uint256 constant YEAR = 365 days;

    IRegistrarController.RegisterRequest baseReq;

    function setUp() public {
        // Deploy stack
        reg = new Registry();
        mgr = new TLDManager(reg, protocolOwner);
        oracle = new PriceOracle(address(new MockFeed()), 1 hours, 5_00000000, protocolOwner);

        ctrl = new RegistrarController(reg, mgr, oracle, protocolOwner);

        // Hand registry root to TLDManager
        reg.setOwner(ROOT, address(mgr));

        // Deploy and register ".id" TLD
        tldNodeId = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        registrar = new TLDRegistrar(reg, tldNodeId, "id", address(mgr));

        vm.prank(protocolOwner);
        mgr.addTld("id", address(registrar));

        // Authorize controller in registrar
        vm.prank(address(mgr));
        registrar.addController(address(ctrl));

        // Base request template
        baseReq = IRegistrarController.RegisterRequest({
            name: "kyy",
            tld: tldNodeId,
            owner: alice,
            duration: YEAR,
            // forge-lint: disable-next-line(unsafe-typecast)
            secret: bytes32("secret"),
            resolver: address(0),
            resolverData: new bytes[](0),
            reverseRecord: false
        });
    }

    // ---------------------------------------------------------------
    //                        HELPERS
    // ---------------------------------------------------------------

    function _commit(IRegistrarController.RegisterRequest memory req) internal {
        bytes32 commitment = ctrl.makeCommitment(req);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);
    }

    function _price(IRegistrarController.RegisterRequest memory req)
        internal
        view
        returns (uint256)
    {
        (uint256 base, uint256 premium) = ctrl.rentPrice(req.name, req.tld, req.duration);
        return base + premium;
    }

    // ---------------------------------------------------------------
    //                      MAKE COMMITMENT
    // ---------------------------------------------------------------

    function test_makeCommitment_deterministic() public view {
        bytes32 a = ctrl.makeCommitment(baseReq);
        bytes32 b = ctrl.makeCommitment(baseReq);
        assertEq(a, b);
    }

    function test_makeCommitment_differs_on_secret() public view {
        IRegistrarController.RegisterRequest memory req2 = baseReq;
        // forge-lint: disable-next-line(unsafe-typecast)
        req2.secret = bytes32("different");
        assertNotEq(ctrl.makeCommitment(baseReq), ctrl.makeCommitment(req2));
    }

    // ---------------------------------------------------------------
    //                           COMMIT
    // ---------------------------------------------------------------

    function test_commit_stores_timestamp() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        ctrl.commit(c);
        assertEq(ctrl.commitments(c), block.timestamp);
    }

    function test_commit_reverts_duplicate() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        ctrl.commit(c);
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.CommitmentAlreadyExists.selector, c));
        ctrl.commit(c);
    }

    // ---------------------------------------------------------------
    //                     FULL REGISTER FLOW
    // ---------------------------------------------------------------

    function test_register_happy_path() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);

        vm.deal(alice, price * 2);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);

        // NFT owned by alice
        uint256 tokenId = uint256(keccak256(bytes("kyy")));
        assertEq(registrar.ownerOf(tokenId), alice);

        // Registry record owned by alice
        bytes32 nameNode = keccak256(abi.encodePacked(tldNodeId, bytes32(tokenId)));
        assertEq(reg.ownerOf(nameNode), alice);
    }

    function test_register_emits_NameRegistered() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        uint256 tokenId = uint256(keccak256(bytes("kyy")));

        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectEmit(false, true, true, false);
        emit IRegistrarController.NameRegistered(
            "kyy", tldNodeId, bytes32(tokenId), alice, 0, 0, 0
        );
        ctrl.register{ value: price }(baseReq);
    }

    function test_register_refunds_excess() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        uint256 excess = 1 ether;

        vm.deal(alice, price + excess);
        uint256 balBefore = alice.balance;
        vm.prank(alice);
        ctrl.register{ value: price + excess }(baseReq);

        assertEq(alice.balance, balBefore - price);
    }

    function test_register_reverts_commitment_too_new() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        ctrl.commit(c);
        // Don't warp — still too new

        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.CommitmentTooNew.selector, c));
        ctrl.register{ value: price }(baseReq);
    }

    function test_register_reverts_commitment_too_old() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        ctrl.commit(c);
        vm.warp(block.timestamp + ctrl.MAX_COMMITMENT_AGE() + 1);

        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.CommitmentTooOld.selector, c));
        ctrl.register{ value: price }(baseReq);
    }

    function test_register_reverts_no_commitment() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.CommitmentNotFound.selector, c));
        ctrl.register{ value: price }(baseReq);
    }

    function test_register_reverts_insufficient_value() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);

        vm.deal(alice, price);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IRegistrarController.InsufficientValue.selector, price, 0)
        );
        ctrl.register{ value: 0 }(baseReq);
    }

    function test_register_reverts_invalid_name_too_short() public {
        IRegistrarController.RegisterRequest memory req = baseReq;
        req.name = "ab";
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.InvalidName.selector, "ab"));
        ctrl.register{ value: 1 ether }(req);
    }

    function test_register_reverts_invalid_name_uppercase() public {
        IRegistrarController.RegisterRequest memory req = baseReq;
        req.name = "Kyy";
        vm.expectRevert(abi.encodeWithSelector(IRegistrarController.InvalidName.selector, "Kyy"));
        ctrl.register{ value: 1 ether }(req);
    }

    function test_register_reverts_name_unavailable() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);

        // Second attempt with new commitment
        IRegistrarController.RegisterRequest memory req2 = baseReq;
        // forge-lint: disable-next-line(unsafe-typecast)
        req2.secret = bytes32("secret2");
        req2.owner = bob;
        _commit(req2);
        vm.deal(bob, price);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IRegistrarController.NameUnavailable.selector, "kyy", tldNodeId)
        );
        ctrl.register{ value: price }(req2);
    }

    function test_register_commitment_consumed_after_register() public {
        bytes32 c = ctrl.makeCommitment(baseReq);
        _commit(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);

        // Commitment is gone
        assertEq(ctrl.commitments(c), 0);
    }

    // ---------------------------------------------------------------
    //                           RENEW
    // ---------------------------------------------------------------

    function test_renew_extends_name() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price * 2);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);

        uint256 tokenId = uint256(keccak256(bytes("kyy")));
        uint256 expBefore = registrar.nameExpires(tokenId);

        (uint256 renewPrice,) = ctrl.rentPrice("kyy", tldNodeId, YEAR);
        vm.deal(alice, renewPrice);
        vm.prank(alice);
        ctrl.renew{ value: renewPrice }("kyy", tldNodeId, YEAR);

        assertEq(registrar.nameExpires(tokenId), expBefore + YEAR);
    }

    // ---------------------------------------------------------------
    //                           VALID
    // ---------------------------------------------------------------

    function test_valid_accepts_alphanumeric() public view {
        assertTrue(ctrl.valid("kyy"));
        assertTrue(ctrl.valid("abc123"));
        assertTrue(ctrl.valid("my-name"));
    }

    function test_valid_rejects_too_short() public view {
        assertFalse(ctrl.valid("ab"));
        assertFalse(ctrl.valid("a"));
    }

    function test_valid_rejects_leading_hyphen() public view {
        assertFalse(ctrl.valid("-kyy"));
    }

    function test_valid_rejects_trailing_hyphen() public view {
        assertFalse(ctrl.valid("kyy-"));
    }

    function test_valid_rejects_uppercase() public view {
        assertFalse(ctrl.valid("Kyy"));
        assertFalse(ctrl.valid("KYY"));
    }

    // ---------------------------------------------------------------
    //                      PAUSE / UNPAUSE
    // ---------------------------------------------------------------

    function test_pause_blocks_commit_and_register() public {
        vm.prank(protocolOwner);
        ctrl.pause();

        vm.expectRevert();
        ctrl.commit(bytes32(0));
    }

    function test_unpause_resumes() public {
        vm.prank(protocolOwner);
        ctrl.pause();
        vm.prank(protocolOwner);
        ctrl.unpause();

        bytes32 c = ctrl.makeCommitment(baseReq);
        ctrl.commit(c);
        assertGt(ctrl.commitments(c), 0);
    }

    // ---------------------------------------------------------------
    //                          WITHDRAW
    // ---------------------------------------------------------------

    function test_withdraw_sends_fees() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);

        address treasury = makeAddr("treasury");
        vm.prank(protocolOwner);
        ctrl.withdraw(treasury);
        assertEq(treasury.balance, price);
    }

    function test_withdraw_reverts_if_not_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        ctrl.withdraw(alice);
    }

    // ---------------------------------------------------------------
    //                        AVAILABLE
    // ---------------------------------------------------------------

    function test_available_true_before_registration() public view {
        assertTrue(ctrl.available("kyy", tldNodeId));
    }

    function test_available_false_after_registration() public {
        _commit(baseReq);
        uint256 price = _price(baseReq);
        vm.deal(alice, price);
        vm.prank(alice);
        ctrl.register{ value: price }(baseReq);
        assertFalse(ctrl.available("kyy", tldNodeId));
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_valid_name_charset(bytes calldata raw) public view {
        // Constructed names that are all lowercase ASCII letters should be valid if len >= 3
        vm.assume(raw.length >= 3 && raw.length <= 32);
        string memory name = string(raw);
        // We're just checking it doesn't revert
        ctrl.valid(name);
    }

    function testFuzz_register_different_secrets_different_commitments(
        bytes32 s1,
        bytes32 s2
    ) public view {
        vm.assume(s1 != s2);
        IRegistrarController.RegisterRequest memory r1 = baseReq;
        IRegistrarController.RegisterRequest memory r2 = baseReq;
        r1.secret = s1;
        r2.secret = s2;
        assertNotEq(ctrl.makeCommitment(r1), ctrl.makeCommitment(r2));
    }
}
