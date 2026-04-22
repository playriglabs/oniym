// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IRegistry
/// @notice The core Oniym registry interface. Models ownership of nodes in the name tree.
/// @dev ENS-inspired; kept intentionally similar for interop and developer familiarity.
interface IRegistry {
    // -- Events --

    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);
    event Transfer(bytes32 indexed node, address owner);
    event NewResolver(bytes32 indexed node, address resolver);
    event NewExpiry(bytes32 indexed node, uint64 expires);

    // -- Errors --

    error Unauthorized(bytes32 node, address caller);
    error NodeExpired(bytes32 node);
    error InvalidExpiry(uint64 expires);

    // -- Writes --

    /// @notice Transfer ownership of a node
    function setOwner(bytes32 node, address owner) external;

    /// @notice Create or reassign ownership of a subnode
    /// @return subnode The namehash of parentNode.label
    function setSubnodeOwner(
        bytes32 parentNode,
        bytes32 label,
        address owner
    )
        external
        returns (bytes32 subnode);

    /// @notice Atomic subnode record update
    function setSubnodeRecord(
        bytes32 parentNode,
        bytes32 label,
        address owner,
        address resolver,
        uint64 expires
    )
        external
        returns (bytes32 subnode);

    /// @notice Update resolver for a node
    function setResolver(bytes32 node, address resolver) external;

    /// @notice Update expiry (TLD registrar only)
    function setExpiry(bytes32 node, uint64 expires) external;

    // -- Reads --

    function owner(bytes32 node) external view returns (address);
    function resolver(bytes32 node) external view returns (address);
    function expires(bytes32 node) external view returns (uint64);
    function recordExists(bytes32 node) external view returns (bool);
}
