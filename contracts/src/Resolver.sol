// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IResolver } from "./interfaces/IResolver.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { BitcoinAddress } from "./lib/BitcoinAddress.sol";

/// @title Resolver
/// @notice Multichain resolver for Oniym names. Stores addresses (SLIP-0044 coin types),
///         text records, and content hashes per node.
/// @dev Bitcoin addresses (coinType=0) are format-validated on write via BitcoinAddress.
///      All writes are gated to the node's owner or an approved operator in the Registry.
contract Resolver is IResolver {
    // SLIP-0044 coin type for Bitcoin
    uint256 private constant COIN_TYPE_BTC = 0;

    IRegistry public immutable REGISTRY;

    mapping(bytes32 node => mapping(uint256 coinType => bytes)) private _addrs;
    mapping(bytes32 node => mapping(string key => string)) private _texts;
    mapping(bytes32 node => bytes) private _contenthashes;

    error Unauthorized(bytes32 node);

    constructor(IRegistry _registry) {
        REGISTRY = _registry;
    }

    modifier authorised(bytes32 node) {
        _authorised(node);
        _;
    }

    function _authorised(bytes32 node) internal view {
        address owner = REGISTRY.ownerOf(node);
        if (msg.sender != owner && !REGISTRY.isApprovedForAll(owner, msg.sender)) {
            revert Unauthorized(node);
        }
    }

    /// @inheritdoc IResolver
    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes calldata addrBytes
    ) external override authorised(node) {
        if (coinType == COIN_TYPE_BTC) BitcoinAddress.validate(addrBytes);
        _addrs[node][coinType] = addrBytes;
        emit AddrChanged(node, coinType, addrBytes);
    }

    /// @inheritdoc IResolver
    function addr(bytes32 node, uint256 coinType) external view override returns (bytes memory) {
        return _addrs[node][coinType];
    }

    /// @inheritdoc IResolver
    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external override authorised(node) {
        _texts[node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /// @inheritdoc IResolver
    function text(
        bytes32 node,
        string calldata key
    ) external view override returns (string memory) {
        return _texts[node][key];
    }

    /// @inheritdoc IResolver
    function setContenthash(bytes32 node, bytes calldata hash) external override authorised(node) {
        _contenthashes[node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /// @inheritdoc IResolver
    function contenthash(bytes32 node) external view override returns (bytes memory) {
        return _contenthashes[node];
    }
}
