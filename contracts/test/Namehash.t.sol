// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Namehash } from "../src/lib/Namehash.sol";

/// @title NamehashTest
/// @notice Test vectors verified against ENS reference implementation
/// @dev These vectors MUST match ENS exactly — any deviation breaks interop
contract NamehashTest is Test {
    /// @notice Empty string hashes to zero
    function test_emptyString() public pure {
        assertEq(Namehash.namehash(""), bytes32(0));
    }

    /// @notice Single label: "eth"
    /// @dev Reference: ENS canonical namehash for "eth"
    function test_ethTLD() public pure {
        assertEq(
            Namehash.namehash("eth"),
            0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae
        );
    }

    /// @notice Two labels: "foo.eth"
    function test_fooEth() public pure {
        assertEq(
            Namehash.namehash("foo.eth"),
            0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f
        );
    }

    /// @notice Real-world example: "vitalik.eth"
    function test_vitalikEth() public pure {
        assertEq(
            Namehash.namehash("vitalik.eth"),
            0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835
        );
    }

    /// @notice Our own TLD
    function test_oniymTLD() public pure {
        bytes32 expected = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes("oniym"))));
        assertEq(Namehash.namehash("oniym"), expected);
    }

    /// @notice Multi-level subdomain
    function test_multiLevel() public pure {
        // wallet.kyy.oniym
        bytes32 oniym = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes("oniym"))));
        bytes32 kyyOniym = keccak256(abi.encodePacked(oniym, keccak256(bytes("kyy"))));
        bytes32 expected = keccak256(abi.encodePacked(kyyOniym, keccak256(bytes("wallet"))));

        assertEq(Namehash.namehash("wallet.kyy.oniym"), expected);
    }

    /// @notice makeNode should match full namehash for subdomain construction
    function test_makeNodeMatchesNamehash() public pure {
        bytes32 parent = Namehash.namehash("oniym");
        bytes32 viaMakeNode = Namehash.makeNode(parent, "kyy");
        bytes32 viaNamehash = Namehash.namehash("kyy.oniym");

        assertEq(viaMakeNode, viaNamehash);
    }

    /// @notice Deeply nested subdomain
    function test_deeplyNested() public pure {
        // Ensure the algorithm works for 5 levels deep
        string memory name = "a.b.c.d.oniym";

        bytes32 step0 = bytes32(0);
        bytes32 step1 = keccak256(abi.encodePacked(step0, keccak256(bytes("oniym"))));
        bytes32 step2 = keccak256(abi.encodePacked(step1, keccak256(bytes("d"))));
        bytes32 step3 = keccak256(abi.encodePacked(step2, keccak256(bytes("c"))));
        bytes32 step4 = keccak256(abi.encodePacked(step3, keccak256(bytes("b"))));
        bytes32 step5 = keccak256(abi.encodePacked(step4, keccak256(bytes("a"))));

        assertEq(Namehash.namehash(name), step5);
    }

    /// @notice Fuzz: single label without dots
    function testFuzz_singleLabel(string memory label) public pure {
        vm.assume(bytes(label).length > 0);
        vm.assume(bytes(label).length <= 64);
        vm.assume(!_containsDot(label));

        bytes32 expected = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes(label))));
        assertEq(Namehash.namehash(label), expected);
    }

    /// @notice Fuzz: two-level names have correct structure
    function testFuzz_twoLevel(string memory label, string memory tld) public pure {
        vm.assume(bytes(label).length > 0 && bytes(label).length <= 64);
        vm.assume(bytes(tld).length > 0 && bytes(tld).length <= 64);
        vm.assume(!_containsDot(label) && !_containsDot(tld));

        bytes32 tldNode = keccak256(abi.encodePacked(bytes32(0), keccak256(bytes(tld))));
        bytes32 expected = keccak256(abi.encodePacked(tldNode, keccak256(bytes(label))));

        string memory fullName = string(abi.encodePacked(label, ".", tld));
        assertEq(Namehash.namehash(fullName), expected);
    }

    // -- helpers --

    function _containsDot(string memory s) private pure returns (bool) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == 0x2e) return true;
        }
        return false;
    }
}
