// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Registry } from "../src/Registry.sol";
import { TLDManager } from "../src/TLDManager.sol";
import { TLDRegistrar } from "../src/TLDRegistrar.sol";
import { RegistrarController } from "../src/RegistrarController.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { PublicResolver } from "../src/PublicResolver.sol";
import { IResolver } from "../src/interfaces/IResolver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract MockFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 3_000_00000000, block.timestamp, block.timestamp, 1);
    }
}

contract PublicResolverTest is Test {
    Registry reg;
    TLDManager mgr;
    TLDRegistrar registrar;
    PriceOracle oracle;
    RegistrarController ctrl;
    PublicResolver resolver;

    address protocolOwner = makeAddr("protocol");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    bytes32 constant ROOT = bytes32(0);
    bytes32 tldNode;
    bytes32 nameNode;
    uint256 tokenId;

    // SLIP-0044 coin types
    uint256 constant COIN_ETH = 60;
    uint256 constant COIN_SOL = 501;
    uint256 constant COIN_BTC = 0;
    uint256 constant COIN_SUI = 784;

    uint256 constant YEAR = 365 days;

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

        // Register "kyy.id" for alice
        tokenId = uint256(keccak256(bytes("kyy")));
        nameNode = keccak256(abi.encodePacked(tldNode, bytes32(tokenId)));

        _register("kyy", alice);
    }

    // ---------------------------------------------------------------
    //                          HELPERS
    // ---------------------------------------------------------------

    function _register(string memory name, address owner) internal {
        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: name,
            tld: tldNode,
            owner: owner,
            duration: YEAR,
            secret: bytes32("secret"),
            resolver: address(resolver),
            resolverData: new bytes[](0),
            reverseRecord: false
        });
        bytes32 commitment = ctrl.makeCommitment(req);
        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);

        (uint256 base, uint256 premium) = ctrl.rentPrice(name, tldNode, YEAR);
        uint256 price = base + premium;
        vm.deal(owner, price);
        vm.prank(owner);
        ctrl.register{ value: price }(req);
    }

    // ---------------------------------------------------------------
    //                      ADDR — ETH (coinType 60)
    // ---------------------------------------------------------------

    function test_setAddr_eth_by_owner() public {
        bytes memory ethAddr = abi.encodePacked(alice);
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_ETH, ethAddr);
        assertEq(resolver.addr(nameNode, COIN_ETH), ethAddr);
    }

    function test_setAddr_solana_by_owner() public {
        bytes memory solAddr = bytes("So11111111111111111111111111111111111111112");
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_SOL, solAddr);
        assertEq(resolver.addr(nameNode, COIN_SOL), solAddr);
    }

    function test_setAddr_btc_by_owner() public {
        bytes memory btcAddr = bytes("bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh");
        vm.prank(alice);
        resolver.setAddr(nameNode, COIN_BTC, btcAddr);
        assertEq(resolver.addr(nameNode, COIN_BTC), btcAddr);
    }

    function test_setAddr_emits_AddrChanged() public {
        bytes memory ethAddr = abi.encodePacked(alice);
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit IResolver.AddrChanged(nameNode, COIN_ETH, ethAddr);
        resolver.setAddr(nameNode, COIN_ETH, ethAddr);
    }

    function test_addr_returns_empty_before_set() public view {
        assertEq(resolver.addr(nameNode, COIN_ETH).length, 0);
    }

    function test_setAddr_reverts_unauthorized() public {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode, eve));
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(alice));
    }

    function test_setAddr_by_registry_operator() public {
        vm.prank(alice);
        reg.setApprovalForAll(bob, true);

        bytes memory ethAddr = abi.encodePacked(alice);
        vm.prank(bob);
        resolver.setAddr(nameNode, COIN_ETH, ethAddr);
        assertEq(resolver.addr(nameNode, COIN_ETH), ethAddr);
    }

    function test_setAddr_by_resolver_delegate() public {
        vm.prank(alice);
        resolver.approve(nameNode, bob, true);

        bytes memory ethAddr = abi.encodePacked(alice);
        vm.prank(bob);
        resolver.setAddr(nameNode, COIN_ETH, ethAddr);
        assertEq(resolver.addr(nameNode, COIN_ETH), ethAddr);
    }

    function test_setAddr_multiple_coin_types_independent() public {
        bytes memory ethAddr = abi.encodePacked(alice);
        bytes memory solAddr = bytes("SolanaAddressHere");

        vm.startPrank(alice);
        resolver.setAddr(nameNode, COIN_ETH, ethAddr);
        resolver.setAddr(nameNode, COIN_SOL, solAddr);
        vm.stopPrank();

        assertEq(resolver.addr(nameNode, COIN_ETH), ethAddr);
        assertEq(resolver.addr(nameNode, COIN_SOL), solAddr);
    }

    function test_setAddr_overwrite() public {
        bytes memory addr1 = abi.encodePacked(alice);
        bytes memory addr2 = abi.encodePacked(bob);

        vm.startPrank(alice);
        resolver.setAddr(nameNode, COIN_ETH, addr1);
        resolver.setAddr(nameNode, COIN_ETH, addr2);
        vm.stopPrank();

        assertEq(resolver.addr(nameNode, COIN_ETH), addr2);
    }

    // ---------------------------------------------------------------
    //                        TEXT RECORDS
    // ---------------------------------------------------------------

    function test_setText_and_read() public {
        vm.prank(alice);
        resolver.setText(nameNode, "twitter", "@kyy");
        assertEq(resolver.text(nameNode, "twitter"), "@kyy");
    }

    function test_setText_emits_TextChanged() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IResolver.TextChanged(nameNode, "twitter", "twitter", "@kyy");
        resolver.setText(nameNode, "twitter", "@kyy");
    }

    function test_text_returns_empty_before_set() public view {
        assertEq(bytes(resolver.text(nameNode, "twitter")).length, 0);
    }

    function test_setText_reverts_unauthorized() public {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode, eve));
        resolver.setText(nameNode, "twitter", "@hacked");
    }

    function test_setText_multiple_keys_independent() public {
        vm.startPrank(alice);
        resolver.setText(nameNode, "twitter", "@kyy");
        resolver.setText(nameNode, "github", "kyy");
        resolver.setText(nameNode, "url", "https://kyy.id");
        vm.stopPrank();

        assertEq(resolver.text(nameNode, "twitter"), "@kyy");
        assertEq(resolver.text(nameNode, "github"), "kyy");
        assertEq(resolver.text(nameNode, "url"), "https://kyy.id");
    }

    function test_setText_overwrite() public {
        vm.startPrank(alice);
        resolver.setText(nameNode, "twitter", "@old");
        resolver.setText(nameNode, "twitter", "@new");
        vm.stopPrank();
        assertEq(resolver.text(nameNode, "twitter"), "@new");
    }

    // ---------------------------------------------------------------
    //                        CONTENTHASH
    // ---------------------------------------------------------------

    function test_setContenthash_and_read() public {
        // SHA2-256 multihash prefix (0x1220) + 32-byte digest
        bytes memory ipfsHash = hex"12209f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
        vm.prank(alice);
        resolver.setContenthash(nameNode, ipfsHash);
        assertEq(resolver.contenthash(nameNode), ipfsHash);
    }

    function test_setContenthash_emits_ContenthashChanged() public {
        bytes memory hash = hex"deadbeef";
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit IResolver.ContenthashChanged(nameNode, hash);
        resolver.setContenthash(nameNode, hash);
    }

    function test_contenthash_returns_empty_before_set() public view {
        assertEq(resolver.contenthash(nameNode).length, 0);
    }

    function test_setContenthash_reverts_unauthorized() public {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode, eve));
        resolver.setContenthash(nameNode, hex"deadbeef");
    }

    // ---------------------------------------------------------------
    //                        DELEGATION
    // ---------------------------------------------------------------

    function test_approve_grants_write_access() public {
        vm.prank(alice);
        resolver.approve(nameNode, bob, true);
        assertTrue(resolver.isApprovedFor(nameNode, bob));
    }

    function test_revoke_removes_write_access() public {
        vm.startPrank(alice);
        resolver.approve(nameNode, bob, true);
        resolver.approve(nameNode, bob, false);
        vm.stopPrank();

        assertFalse(resolver.isApprovedFor(nameNode, bob));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode, bob));
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(alice));
    }

    function test_approve_reverts_if_not_owner() public {
        vm.prank(eve);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode, eve));
        resolver.approve(nameNode, eve, true);
    }

    function test_approve_emits_Approved() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PublicResolver.Approved(alice, nameNode, bob, true);
        resolver.approve(nameNode, bob, true);
    }

    function test_delegation_scoped_to_node() public {
        // Register a second name for alice
        _register("kyz", alice);
        uint256 tokenId2 = uint256(keccak256(bytes("kyz")));
        bytes32 nameNode2 = keccak256(abi.encodePacked(tldNode, bytes32(tokenId2)));

        // Approve bob only on nameNode (kyy.id), not nameNode2 (kyz.id)
        vm.prank(alice);
        resolver.approve(nameNode, bob, true);

        // bob can write to kyy.id
        vm.prank(bob);
        resolver.setAddr(nameNode, COIN_ETH, abi.encodePacked(alice));

        // bob cannot write to kyz.id
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PublicResolver.Unauthorised.selector, nameNode2, bob));
        resolver.setAddr(nameNode2, COIN_ETH, abi.encodePacked(alice));
    }

    // ---------------------------------------------------------------
    //                          ERC-165
    // ---------------------------------------------------------------

    function test_supportsInterface_erc165() public view {
        assertTrue(resolver.supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_resolver() public view {
        assertTrue(resolver.supportsInterface(type(IResolver).interfaceId));
    }

    function test_supportsInterface_false_for_unknown() public view {
        assertFalse(resolver.supportsInterface(0xdeadbeef));
    }

    // ---------------------------------------------------------------
    //                        FUZZ TESTS
    // ---------------------------------------------------------------

    function testFuzz_setAddr_any_coin_type(uint256 coinType, bytes calldata rawAddr) public {
        vm.assume(rawAddr.length > 0 && rawAddr.length <= 128);
        vm.prank(alice);
        resolver.setAddr(nameNode, coinType, rawAddr);
        assertEq(resolver.addr(nameNode, coinType), rawAddr);
    }

    function testFuzz_setText_any_key_value(
        string calldata key,
        string calldata value
    ) public {
        vm.assume(bytes(key).length > 0 && bytes(key).length <= 64);
        vm.assume(bytes(value).length <= 256);
        vm.prank(alice);
        resolver.setText(nameNode, key, value);
        assertEq(resolver.text(nameNode, key), value);
    }
}

// Bring IRegistrarController into scope for the helper
import { IRegistrarController } from "../src/interfaces/IRegistrarController.sol";
