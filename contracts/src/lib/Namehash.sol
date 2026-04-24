// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Namehash
/// @notice ENSIP-1 compatible namehash algorithm for hierarchical domain names
/// @dev Reference: https://docs.ens.domains/ensip/1
///
/// The namehash algorithm recursively hashes labels right-to-left:
///   namehash('')          = 0x00...00
///   namehash('eth')       = keccak256(0x00...00 ‖ keccak256('eth'))
///   namehash('kyy.eth')   = keccak256(namehash('eth') ‖ keccak256('kyy'))
///
/// Input MUST be pre-normalized (lowercase, UTS-46). This library does not
/// perform normalization — callers are responsible for passing valid input.
library Namehash {
    /// @notice The ASCII codepoint for the label separator '.'
    uint8 private constant DOT = 0x2e;

    /// @notice Computes the namehash of a dot-separated name
    /// @param name The fully-qualified name (e.g. "kyy.eth")
    /// @return node The 32-byte namehash
    function namehash(string memory name) internal pure returns (bytes32 node) {
        bytes memory nameBytes = bytes(name);
        uint256 len = nameBytes.length;

        // Empty name → zero node
        if (len == 0) return bytes32(0);

        // Walk right-to-left, hashing each label into the accumulator
        uint256 labelEnd = len;
        for (uint256 i = len; i > 0; i--) {
            if (uint8(nameBytes[i - 1]) == DOT) {
                bytes32 labelHash = keccakSlice(nameBytes, i, labelEnd);
                node = hashPair(node, labelHash);
                labelEnd = i - 1;
            }
        }

        // Final (leftmost) label — no preceding dot
        bytes32 firstLabelHash = keccakSlice(nameBytes, 0, labelEnd);
        node = hashPair(node, firstLabelHash);
    }

    /// @notice Computes a subdomain namehash from parent node and label
    /// @param parentNode The namehash of the parent
    /// @param label The label string (no dots)
    /// @return The namehash of parent.label
    function makeNode(bytes32 parentNode, string memory label) internal pure returns (bytes32) {
        return hashPair(parentNode, keccak256(bytes(label)));
    }

    /// @notice Hashes two 32-byte values using keccak256 via scratch space
    /// @dev Uses the EVM's free scratch space at 0x00..0x40 — safe in pure
    ///      functions because nothing else can write to it before keccak256
    function hashPair(bytes32 a, bytes32 b) private pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    /// @notice Hashes a slice of a bytes array using keccak256
    /// @dev Uses assembly for efficient in-place hashing without memory copy
    function keccakSlice(
        bytes memory data,
        uint256 start,
        uint256 end
    ) private pure returns (bytes32 result) {
        assembly {
            // `data` points to length prefix; actual bytes start at data + 32
            result := keccak256(add(add(data, 0x20), start), sub(end, start))
        }
    }
}
