// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IRegistry
/// @notice Core Oniym registry. Models ownership of nodes in the hierarchical name tree.
/// @dev ENSIP-1 compatible node semantics. Kept intentionally close to ENS registry
///      for developer familiarity and ecosystem interop.
///
/// The registry is a thin "who owns what" database. Actual resolution data
/// (addresses, text records, etc.) lives in separate resolver contracts
/// referenced by {resolverOf}.
interface IRegistry {
    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    /// @notice Emitted when a subnode is created or reassigned
    /// @dev Mirrors ENS `NewOwner` event for indexer compatibility
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    /// @notice Emitted when ownership of an existing node changes
    event Transfer(bytes32 indexed node, address owner);

    /// @notice Emitted when the resolver for a node changes
    event NewResolver(bytes32 indexed node, address resolver);

    /// @notice Emitted when a node's expiry timestamp changes
    event NewExpiry(bytes32 indexed node, uint64 expires);

    /// @notice Emitted when an operator approval is granted or revoked
    /// @dev Operator can act on ALL of owner's nodes. Scoped per (owner, operator).
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice Caller is not authorized to act on this node
    error Unauthorized(bytes32 node, address caller);

    /// @notice Node has expired and cannot be modified by its previous owner
    error NodeExpired(bytes32 node);

    /// @notice Expiry timestamp is in the past or otherwise invalid
    error InvalidExpiry(uint64 expires);

    /// @notice Zero address is not allowed for this operation
    error ZeroAddress();

    // ---------------------------------------------------------------
    //                          WRITES
    // ---------------------------------------------------------------

    /// @notice Transfer ownership of a node
    /// @dev Caller must be current owner or approved operator
    function setOwner(bytes32 node, address owner) external;

    /// @notice Create or reassign ownership of a subnode
    /// @param parentNode The namehash of the parent
    /// @param label The keccak256 hash of the label string
    /// @param owner The new owner of the subnode
    /// @return subnode The namehash of parentNode.label
    function setSubnodeOwner(
        bytes32 parentNode,
        bytes32 label,
        address owner
    ) external returns (bytes32 subnode);

    /// @notice Atomic subnode creation with resolver and expiry in one tx
    /// @dev Saves gas vs three separate calls. Used by registrars at registration time.
    function setSubnodeRecord(
        bytes32 parentNode,
        bytes32 label,
        address owner,
        address resolver,
        uint64 expires
    ) external returns (bytes32 subnode);

    /// @notice Update the resolver for a node
    /// @dev Caller must be owner or approved operator
    function setResolver(bytes32 node, address resolver) external;

    /// @notice Update expiry for a node
    /// @dev Only callable by the node's registrar (the node's direct parent owner)
    function setExpiry(bytes32 node, uint64 expires) external;

    /// @notice Grant/revoke operator status for another address
    /// @dev Operator can manage ALL of caller's nodes
    function setApprovalForAll(address operator, bool approved) external;

    // ---------------------------------------------------------------
    //                          READS
    // ---------------------------------------------------------------

    /// @notice Current owner of a node (zero if not registered or expired)
    function ownerOf(bytes32 node) external view returns (address);

    /// @notice Resolver contract for a node
    function resolverOf(bytes32 node) external view returns (address);

    /// @notice Expiry timestamp (0 = permanent, e.g. TLD itself)
    function expiresAt(bytes32 node) external view returns (uint64);

    /// @notice True if a record for this node has ever been created
    /// @dev Expired records still return true here — use {ownerOf} for effective ownership
    function recordExists(bytes32 node) external view returns (bool);

    /// @notice Check if operator is approved for all of owner's nodes
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
