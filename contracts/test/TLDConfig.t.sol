// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Namehash } from "../src/lib/Namehash.sol";

/// @title TLDConfigTest
/// @notice Validates the protocol TLD configuration.
///
/// These tests are the Solidity parity for sdk/src/oniym.test.ts.
/// Any change to SUPPORTED_TLDS, MAX_TLD_COUNT, or MAX_TLD_LABEL_LENGTH
/// must be reflected in both files.
contract TLDConfigTest is Test {
    // Must match ITLDManager.maxTldCount() and sdk MAX_TLD_COUNT
    uint256 private constant MAX_TLD_COUNT = 65;

    // Must match ITLDManager.maxTldLabelLength() and sdk MAX_TLD_LENGTH
    uint256 private constant MAX_TLD_LABEL_LENGTH = 5;

    string[] private tlds;

    function setUp() public {
        // General identity
        tlds.push("id");
        tlds.push("one");
        tlds.push("me");
        tlds.push("co");
        // Web3 / tech signals
        tlds.push("xyz");
        tlds.push("web3");
        tlds.push("io");
        tlds.push("pro");
        tlds.push("app");
        tlds.push("dev");
        tlds.push("onm");
        tlds.push("go");
        // Crypto culture
        tlds.push("ape");
        tlds.push("fud");
        tlds.push("hodl");
        tlds.push("fomo");
        tlds.push("moon");
        tlds.push("rekt");
        tlds.push("wagmi");
        tlds.push("ngmi");
        tlds.push("degen");
        tlds.push("whale");
        tlds.push("buidl");
        tlds.push("dyor");
        tlds.push("pump");
        tlds.push("alpha");
        tlds.push("safu");
        tlds.push("l2");
        tlds.push("gm");
        tlds.push("lfg");
        tlds.push("ser");
        tlds.push("fren");
        tlds.push("goat");
        tlds.push("cope");
        tlds.push("pepe");
        tlds.push("wen");
        // Finance / DeFi
        tlds.push("mint");
        tlds.push("bear");
        tlds.push("gas");
        tlds.push("dao");
        tlds.push("ath");
        tlds.push("dex");
        tlds.push("cex");
        tlds.push("burn");
        tlds.push("node");
        tlds.push("swap");
        tlds.push("yield");
        tlds.push("bag");
        tlds.push("bags");
        tlds.push("seed");
        tlds.push("drop");
        tlds.push("stake");
        tlds.push("pool");
        tlds.push("wrap");
        tlds.push("farm");
        tlds.push("shill");
        // Misc
        tlds.push("xxx");
        tlds.push("regs");
        tlds.push("main");
        tlds.push("test");
        tlds.push("exit");
        tlds.push("fair");
        tlds.push("guh");
        tlds.push("bots");
        tlds.push("keys");
    }

    // ---------------------------------------------------------------
    //                     CONSTANTS
    // ---------------------------------------------------------------

    function test_emptyStringHashesToZero() public pure {
        assertEq(Namehash.namehash(""), bytes32(0));
    }

    function test_maxTldCount() public view {
        assertEq(tlds.length, MAX_TLD_COUNT);
    }

    function test_constants() public pure {
        assertEq(MAX_TLD_COUNT, 65);
        assertEq(MAX_TLD_LABEL_LENGTH, 5);
    }

    // ---------------------------------------------------------------
    //                     LABEL CONSTRAINTS
    // ---------------------------------------------------------------

    function test_allLabelsWithinMaxLength() public view {
        for (uint256 i = 0; i < tlds.length; i++) {
            assertLe(
                bytes(tlds[i]).length,
                MAX_TLD_LABEL_LENGTH,
                string.concat(tlds[i], " exceeds MAX_TLD_LABEL_LENGTH")
            );
        }
    }

    function test_noEmptyLabels() public view {
        for (uint256 i = 0; i < tlds.length; i++) {
            assertGt(bytes(tlds[i]).length, 0, "TLD label must not be empty");
        }
    }

    // ---------------------------------------------------------------
    //                     TLD NODE UNIQUENESS
    // ---------------------------------------------------------------

    function test_allTldNodesNonZero() public view {
        for (uint256 i = 0; i < tlds.length; i++) {
            bytes32 node = Namehash.namehash(tlds[i]);
            assertNotEq(node, bytes32(0), string.concat(tlds[i], " hashed to zero"));
        }
    }

    function test_allTldNodesUnique() public view {
        for (uint256 i = 0; i < tlds.length; i++) {
            for (uint256 j = i + 1; j < tlds.length; j++) {
                bytes32 nodeI = Namehash.namehash(tlds[i]);
                bytes32 nodeJ = Namehash.namehash(tlds[j]);
                assertNotEq(
                    nodeI,
                    nodeJ,
                    string.concat("collision: .", tlds[i], " and .", tlds[j])
                );
            }
        }
    }

    // ---------------------------------------------------------------
    //                     NAME NODE CORRECTNESS
    // ---------------------------------------------------------------

    function test_makeNodeMatchesNamehashForAllTlds() public view {
        // Namehash.makeNode(tldNode, label) must equal Namehash.namehash("label.tld")
        for (uint256 i = 0; i < tlds.length; i++) {
            bytes32 tldNode = Namehash.namehash(tlds[i]);
            bytes32 viaMakeNode = Namehash.makeNode(tldNode, "kyy");
            bytes32 viaNamehash = Namehash.namehash(string.concat("kyy.", tlds[i]));
            assertEq(viaMakeNode, viaNamehash, string.concat("makeNode mismatch for .', tlds[i]"));
        }
    }

    function test_nameNodesUniqueAcrossTlds() public view {
        // "kyy.<tld>" must produce a distinct node for every TLD
        for (uint256 i = 0; i < tlds.length; i++) {
            for (uint256 j = i + 1; j < tlds.length; j++) {
                bytes32 nodeI = Namehash.namehash(string.concat("kyy.", tlds[i]));
                bytes32 nodeJ = Namehash.namehash(string.concat("kyy.", tlds[j]));
                assertNotEq(
                    nodeI,
                    nodeJ,
                    string.concat("node collision: kyy.", tlds[i], " and kyy.", tlds[j])
                );
            }
        }
    }

    function test_tldNodesDifferFromNameNodes() public view {
        // namehash("id") != namehash("kyy.id") — TLD root and registered name are distinct
        for (uint256 i = 0; i < tlds.length; i++) {
            bytes32 tldNode = Namehash.namehash(tlds[i]);
            bytes32 nameNode = Namehash.namehash(string.concat("kyy.", tlds[i]));
            assertNotEq(tldNode, nameNode);
        }
    }

    // ---------------------------------------------------------------
    //                     KNOWN-VALUE PARITY
    // ---------------------------------------------------------------

    /// @notice Parity test: "id" TLD matches manually computed hash
    function test_idTldHash() public pure {
        bytes32 expected = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes("id"))));
        assertEq(Namehash.namehash("id"), expected);
    }

    /// @notice Parity test: "one" TLD matches manually computed hash
    function test_oneTldHash() public pure {
        bytes32 expected = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes("one"))));
        assertEq(Namehash.namehash("one"), expected);
    }

    /// @notice Parity test: "kyy.id" matches step-by-step construction
    function test_kyyIdNameHash() public pure {
        bytes32 idNode = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes("id"))));
        bytes32 expected = keccak256(abi.encodePacked(idNode, keccak256(bytes("kyy"))));
        assertEq(Namehash.namehash("kyy.id"), expected);
    }

    // ---------------------------------------------------------------
    //                         FUZZ
    // ---------------------------------------------------------------

    /// @notice Fuzz: any label within MAX_TLD_LABEL_LENGTH hashes to non-zero
    function testFuzz_shortLabelHashable(string memory label) public pure {
        vm.assume(bytes(label).length > 0);
        vm.assume(bytes(label).length <= MAX_TLD_LABEL_LENGTH);

        bytes32 node = Namehash.namehash(label);
        assertNotEq(node, bytes32(0));
    }

    /// @notice Fuzz: name under any protocol TLD produces a node distinct from the TLD root.
    /// @dev Uses a uint8 index into the known-valid tlds array to avoid mass vm.assume rejections
    ///      that would occur when fuzzing a raw string with the 5-char length constraint.
    function testFuzz_nameNodeDistinctFromTldNode(
        string memory label,
        uint8 tldIdx
    ) public view {
        vm.assume(bytes(label).length > 0 && bytes(label).length <= 64);
        vm.assume(!containsDot(label));

        string memory tld = tlds[tldIdx % tlds.length];

        bytes32 tldNode = Namehash.namehash(tld);
        bytes32 nameNode = Namehash.namehash(string.concat(label, ".", tld));
        assertNotEq(tldNode, nameNode);
    }

    // ---------------------------------------------------------------
    //                         HELPERS
    // ---------------------------------------------------------------

    function containsDot(string memory s) private pure returns (bool) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x2e) return true;
        }
        return false;
    }
}
