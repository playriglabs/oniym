// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ITLDManager } from "./interfaces/ITLDManager.sol";
import { ITLDRegistrar } from "./interfaces/ITLDRegistrar.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/// @title TLDManager
/// @notice Protocol-owned manager for all active TLDs.
/// @dev Owns the Registry root node (bytes32(0)). When a TLD is added, this
///      contract calls REGISTRY.setSubnodeOwner(ROOT, labelHash, registrar),
///      making the registrar the owner of that TLD root node so it can create
///      second-level name subnodes.
///
///      The TLDManager retains metadata about each TLD and manages the
///      authorized registrar set. To upgrade a registrar, the current registrar
///      must transfer its TLD root ownership back to a new registrar via
///      REGISTRY.setOwner — this is an admin operation performed with owner privileges.
contract TLDManager is ITLDManager, Ownable2Step {
    uint256 public constant MAX_TLD_COUNT = 128;
    uint256 public constant MAX_TLD_LABEL_LENGTH = 5;

    IRegistry public immutable REGISTRY;

    /// @dev Ordered list of all TLD nodes (for listTlds())
    bytes32[] private _tldList;

    /// @dev node => Tld metadata
    mapping(bytes32 => Tld) private _tlds;

    /// @dev lowercase label => node (for getTldByLabel)
    mapping(string => bytes32) private _labelToNode;

    constructor(IRegistry _registry, address initialOwner) Ownable(initialOwner) {
        REGISTRY = _registry;
    }

    // ---------------------------------------------------------------
    //                           ADMIN
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDManager
    function addTld(
        string calldata label,
        address registrar
    ) external override onlyOwner returns (bytes32 node) {
        if (registrar == address(0)) revert ZeroRegistrar();
        if (_tldList.length >= MAX_TLD_COUNT) revert MaxTldCountReached(MAX_TLD_COUNT);

        uint256 labelLen = bytes(label).length;
        if (labelLen == 0 || labelLen > MAX_TLD_LABEL_LENGTH) {
            revert TldLabelTooLong(label, labelLen, MAX_TLD_LABEL_LENGTH);
        }

        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 labelHash = keccak256(bytes(label));
        node = keccak256(abi.encodePacked(bytes32(0), labelHash));

        if (_tlds[node].registrar != address(0)) revert TLDAlreadyExists(node);

        // Grant the registrar ownership of this TLD root node in the registry
        REGISTRY.setSubnodeOwner(bytes32(0), labelHash, registrar);

        _tlds[node] = Tld({ node: node, label: label, registrar: registrar, active: true });
        _labelToNode[label] = node;
        _tldList.push(node);

        emit TLDAdded(node, label, registrar);
    }

    /// @inheritdoc ITLDManager
    function setTldActive(bytes32 node, bool active) external override onlyOwner {
        if (_tlds[node].registrar == address(0)) revert TLDNotFound(node);
        _tlds[node].active = active;
        emit TLDStatusChanged(node, active);
    }

    /// @inheritdoc ITLDManager
    /// @dev The old registrar must have transferred TLD root ownership to this contract
    ///      (or directly to newRegistrar) before this is called. This function updates
    ///      the metadata and hands root ownership to the new registrar.
    function setRegistrar(bytes32 node, address registrar) external override onlyOwner {
        if (registrar == address(0)) revert ZeroRegistrar();
        Tld storage tld = _tlds[node];
        if (tld.registrar == address(0)) revert TLDNotFound(node);

        address old = tld.registrar;
        tld.registrar = registrar;

        // Transfer TLD root ownership to the new registrar.
        // Requires TLDManager to currently own the node (old registrar must have surrendered it).
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 labelHash = keccak256(bytes(tld.label));
        REGISTRY.setSubnodeOwner(bytes32(0), labelHash, registrar);

        emit RegistrarUpdated(node, old, registrar);
    }

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDManager
    function getTld(bytes32 node) external view override returns (Tld memory) {
        if (_tlds[node].registrar == address(0)) revert TLDNotFound(node);
        return _tlds[node];
    }

    /// @inheritdoc ITLDManager
    function getTldByLabel(string calldata label) external view override returns (Tld memory) {
        bytes32 node = _labelToNode[label];
        if (_tlds[node].registrar == address(0)) revert TLDNotFound(node);
        return _tlds[node];
    }

    /// @inheritdoc ITLDManager
    function listTlds() external view override returns (Tld[] memory tlds) {
        tlds = new Tld[](_tldList.length);
        for (uint256 i = 0; i < _tldList.length; i++) {
            tlds[i] = _tlds[_tldList[i]];
        }
    }

    /// @inheritdoc ITLDManager
    function isActiveTld(bytes32 node) external view override returns (bool) {
        return _tlds[node].active;
    }

    /// @inheritdoc ITLDManager
    function isTld(string calldata label) external view override returns (bool) {
        bytes32 node = _labelToNode[label];
        return _tlds[node].registrar != address(0);
    }

    /// @notice Authorize a controller on a specific TLD's registrar.
    /// @dev Called after deploying a new RegistrarController. Only the protocol owner
    ///      can do this since TLDManager owns all registrars.
    function addControllerToRegistrar(bytes32 tldNode, address controller) external onlyOwner {
        Tld storage tld = _tlds[tldNode];
        if (tld.registrar == address(0)) revert TLDNotFound(tldNode);
        ITLDRegistrar(tld.registrar).addController(controller);
    }

    /// @notice Revoke a controller from a specific TLD's registrar.
    function removeControllerFromRegistrar(bytes32 tldNode, address controller) external onlyOwner {
        Tld storage tld = _tlds[tldNode];
        if (tld.registrar == address(0)) revert TLDNotFound(tldNode);
        ITLDRegistrar(tld.registrar).removeController(controller);
    }

    /// @inheritdoc ITLDManager
    function maxTldCount() external pure override returns (uint256) {
        return MAX_TLD_COUNT;
    }

    /// @inheritdoc ITLDManager
    function maxTldLabelLength() external pure override returns (uint256) {
        return MAX_TLD_LABEL_LENGTH;
    }
}
