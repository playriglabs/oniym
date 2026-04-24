// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IRegistry } from "./interfaces/IRegistry.sol";

/// @title Registry
/// @notice Core ownership store for the Oniym name tree. Thin "who owns what" database.
/// @dev Root node (bytes32(0)) is owned by the deployer and should immediately be
///      transferred to TLDManager after deployment.
///
///      Expiry semantics: expires == 0 means permanent (used for TLD root nodes).
///      An expired node returns address(0) from ownerOf() but its record still exists.
///
///      Parent tracking: setSubnodeOwner/setSubnodeRecord store the parent node so
///      that setExpiry can verify the caller is the parent's owner (i.e. the registrar).
contract Registry is IRegistry {
    struct Record {
        address owner;
        address resolver;
        uint64 expires;
    }

    /// @dev node => record
    mapping(bytes32 => Record) private _records;

    /// @dev owner => operator => approved
    mapping(address => mapping(address => bool)) private _operators;

    /// @dev child node => parent node (set on subnode creation, used by setExpiry)
    mapping(bytes32 => bytes32) private _parents;

    constructor() {
        // Deployer owns the root so it can immediately hand it to TLDManager
        _records[bytes32(0)].owner = msg.sender;
        emit Transfer(bytes32(0), msg.sender);
    }

    // ---------------------------------------------------------------
    //                       AUTH HELPERS
    // ---------------------------------------------------------------

    modifier authorised(bytes32 node) {
        _checkAuthorised(node);
        _;
    }

    function _checkAuthorised(bytes32 node) internal view {
        address owner = _records[node].owner;
        if (msg.sender != owner && !_operators[owner][msg.sender]) {
            revert Unauthorized(node, msg.sender);
        }
    }

    // ---------------------------------------------------------------
    //                           WRITES
    // ---------------------------------------------------------------

    /// @inheritdoc IRegistry
    function setOwner(bytes32 node, address owner) external authorised(node) {
        _records[node].owner = owner;
        emit Transfer(node, owner);
    }

    /// @inheritdoc IRegistry
    function setSubnodeOwner(
        bytes32 parentNode,
        bytes32 label,
        address owner
    ) external authorised(parentNode) returns (bytes32 subnode) {
        subnode = _subnode(parentNode, label);
        // Preserve resolver and expiry; only update owner
        _records[subnode].owner = owner;
        _parents[subnode] = parentNode;
        emit NewOwner(parentNode, label, owner);
    }

    /// @inheritdoc IRegistry
    function setSubnodeRecord(
        bytes32 parentNode,
        bytes32 label,
        address owner,
        address resolver,
        uint64 expires
    ) external authorised(parentNode) returns (bytes32 subnode) {
        subnode = _subnode(parentNode, label);
        _records[subnode] = Record({ owner: owner, resolver: resolver, expires: expires });
        _parents[subnode] = parentNode;
        emit NewOwner(parentNode, label, owner);
        if (resolver != address(0)) emit NewResolver(subnode, resolver);
        if (expires != 0) emit NewExpiry(subnode, expires);
    }

    /// @inheritdoc IRegistry
    function setResolver(bytes32 node, address resolver) external authorised(node) {
        _records[node].resolver = resolver;
        emit NewResolver(node, resolver);
    }

    /// @inheritdoc IRegistry
    /// @dev Caller must be the owner of this node's parent (i.e. the TLD registrar).
    ///      TLD root nodes (expires == 0) cannot have their expiry changed this way.
    function setExpiry(bytes32 node, uint64 expires) external {
        bytes32 parent = _parents[node];
        address parentOwner = _records[parent].owner;
        if (msg.sender != parentOwner && !_operators[parentOwner][msg.sender]) {
            revert Unauthorized(node, msg.sender);
        }
        if (expires == 0) revert InvalidExpiry(expires);
        _records[node].expires = expires;
        emit NewExpiry(node, expires);
    }

    /// @inheritdoc IRegistry
    function setApprovalForAll(address operator, bool approved) external {
        _operators[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @inheritdoc IRegistry
    function ownerOf(bytes32 node) external view returns (address) {
        Record storage r = _records[node];
        // expires == 0 means permanent; otherwise check expiry
        if (r.expires != 0 && r.expires < block.timestamp) return address(0);
        return r.owner;
    }

    /// @inheritdoc IRegistry
    function resolverOf(bytes32 node) external view returns (address) {
        return _records[node].resolver;
    }

    /// @inheritdoc IRegistry
    function expiresAt(bytes32 node) external view returns (uint64) {
        return _records[node].expires;
    }

    /// @inheritdoc IRegistry
    function recordExists(bytes32 node) external view returns (bool) {
        Record storage r = _records[node];
        return r.owner != address(0) || r.resolver != address(0);
    }

    /// @inheritdoc IRegistry
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operators[owner][operator];
    }

    // ---------------------------------------------------------------
    //                          INTERNAL
    // ---------------------------------------------------------------

    function _subnode(bytes32 parent, bytes32 label) internal pure returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(parent, label));
    }
}
