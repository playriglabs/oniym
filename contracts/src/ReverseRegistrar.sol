// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IReverseRegistrar } from "./interfaces/IReverseRegistrar.sol";
import { IResolver } from "./interfaces/IResolver.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/// @title ReverseRegistrar
/// @notice Maps Ethereum addresses to protocol names ("0x123... → kyy.id").
/// @dev Owns the `addr.reverse` node in the Registry. Each claim creates a permanent
///      subnode at `[lowercase-hex-addr].addr.reverse` owned by the claimant.
///
///      Setup (done once in deploy script):
///        1. Give ReverseRegistrar ownership of the "reverse" TLD node.
///        2. Give ReverseRegistrar ownership of "addr.reverse" (ADDR_REVERSE_NODE).
///        3. Set ADDR_REVERSE_NODE as the constructor argument.
///
///      Trust model: anyone can claim a reverse record for themselves. The `name`
///      text record is just a claim — dApps MUST verify forward resolution matches
///      before displaying it as a verified name.
contract ReverseRegistrar is IReverseRegistrar, Ownable2Step {
    IRegistry public immutable REGISTRY;

    /// @dev The node for "addr.reverse" — ReverseRegistrar must own this in the Registry.
    bytes32 public immutable ADDR_REVERSE_NODE;

    address private _defaultResolver;

    constructor(
        IRegistry _registry,
        bytes32 _addrReverseNode,
        address initialDefaultResolver,
        address initialOwner
    ) Ownable(initialOwner) {
        REGISTRY = _registry;
        ADDR_REVERSE_NODE = _addrReverseNode;
        _defaultResolver = initialDefaultResolver;
    }

    // ---------------------------------------------------------------
    //                           WRITES
    // ---------------------------------------------------------------

    /// @inheritdoc IReverseRegistrar
    function claim(address owner) external override returns (bytes32) {
        return _claimWithResolver(msg.sender, owner, _defaultResolver);
    }

    /// @inheritdoc IReverseRegistrar
    function claimWithResolver(address owner, address resolver) external override returns (bytes32) {
        return _claimWithResolver(msg.sender, owner, resolver);
    }

    /// @inheritdoc IReverseRegistrar
    /// @dev Temporarily owns the reverse node so it can call setText on behalf
    ///      of the caller, then transfers ownership to the caller.
    function setName(string calldata name) external override returns (bytes32 _node) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 labelHash = keccak256(bytes(_addrToHex(msg.sender)));

        // Own temporarily to write the text record as an authorized caller
        // forge-lint: disable-next-line(asm-keccak256)
        _node = REGISTRY.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, address(this), _defaultResolver, 0);
        IResolver(_defaultResolver).setText(_node, "name", name);
        REGISTRY.setOwner(_node, msg.sender);

        emit ReverseClaimed(msg.sender, _node);
    }

    /// @inheritdoc IReverseRegistrar
    function setNameForAddr(
        address _addr,
        address owner,
        address resolver,
        string calldata name
    ) external override returns (bytes32 _node) {
        _requireAuthorised(_addr);

        if (bytes(name).length > 0 && resolver != address(0)) {
            // forge-lint: disable-next-line(asm-keccak256)
            bytes32 labelHash = keccak256(bytes(_addrToHex(_addr)));
            // forge-lint: disable-next-line(asm-keccak256)
            _node = REGISTRY.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, address(this), resolver, 0);
            IResolver(resolver).setText(_node, "name", name);
            REGISTRY.setOwner(_node, owner);
            emit ReverseClaimed(_addr, _node);
        } else {
            _node = _claimWithResolver(_addr, owner, resolver);
        }
    }

    // ---------------------------------------------------------------
    //                            READS
    // ---------------------------------------------------------------

    /// @inheritdoc IReverseRegistrar
    function node(address addr) external view override returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(ADDR_REVERSE_NODE, keccak256(bytes(_addrToHex(addr)))));
    }

    /// @inheritdoc IReverseRegistrar
    function defaultResolver() external view override returns (address) {
        return _defaultResolver;
    }

    // ---------------------------------------------------------------
    //                            ADMIN
    // ---------------------------------------------------------------

    function setDefaultResolver(address resolver) external onlyOwner {
        emit DefaultResolverChanged(resolver);
        _defaultResolver = resolver;
    }

    // ---------------------------------------------------------------
    //                           INTERNAL
    // ---------------------------------------------------------------

    function _claimWithResolver(
        address addr,
        address owner,
        address resolver
    ) internal returns (bytes32 reverseNode) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 labelHash = keccak256(bytes(_addrToHex(addr)));
        // forge-lint: disable-next-line(asm-keccak256)
        reverseNode = REGISTRY.setSubnodeRecord(ADDR_REVERSE_NODE, labelHash, owner, resolver, 0);
        emit ReverseClaimed(addr, reverseNode);
    }

    /// @dev Authorization for setNameForAddr: addr itself, or the current reverse node owner,
    ///      or an operator approved on the reverse node owner's behalf.
    function _requireAuthorised(address addr) internal view {
        if (msg.sender == addr) return;
        bytes32 reverseNode = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, keccak256(bytes(_addrToHex(addr))))); // forge-lint: disable-line(asm-keccak256)
        address currentOwner = REGISTRY.ownerOf(reverseNode);
        if (currentOwner != address(0)) {
            if (msg.sender == currentOwner) return;
            if (REGISTRY.isApprovedForAll(currentOwner, msg.sender)) return;
        }
        revert Unauthorized(msg.sender);
    }

    /// @dev Convert an address to its lowercase hex string (40 chars, no 0x prefix).
    function _addrToHex(address addr) internal pure returns (string memory) {
        bytes20 addrBytes = bytes20(addr);
        bytes memory hexStr = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            uint8 b = uint8(addrBytes[i]);
            hexStr[i * 2] = _hexChar(b >> 4);
            hexStr[i * 2 + 1] = _hexChar(b & 0x0f);
        }
        return string(hexStr);
    }

    function _hexChar(uint8 nibble) internal pure returns (bytes1) {
        if (nibble < 10) return bytes1(nibble + 0x30); // '0'–'9'
        return bytes1(nibble - 10 + 0x61); // 'a'–'f'
    }
}
