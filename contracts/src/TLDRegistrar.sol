// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ITLDRegistrar } from "./interfaces/ITLDRegistrar.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/// @title TLDRegistrar
/// @notice ERC-721 registrar for a single protocol-managed TLD.
/// @dev One instance is deployed per TLD (e.g. one for ".id", one for ".one").
///
///      Ownership model:
///        tokenId = uint256(keccak256(bytes(label)))
///        Minting a token sets the registry subnode record under BASE_NODE.
///        Transferring a token syncs the registry via _update() override.
///        The registrar must own BASE_NODE in the Registry to write subnodes.
///
///      Controllers (typically RegistrarController) are the only callers
///      allowed to register/renew. Owner (TLDManager) manages controllers.
contract TLDRegistrar is ITLDRegistrar, ERC721, Ownable2Step {
    uint256 public constant GRACE_PERIOD = 90 days;
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;

    IRegistry public immutable REGISTRY;
    bytes32 public immutable BASE_NODE;
    string private _tldLabel;

    /// @dev tokenId => expiry timestamp
    mapping(uint256 => uint256) private _expiries;

    /// @dev authorized controllers
    mapping(address => bool) private _controllers;

    modifier onlyController() {
        _checkController();
        _;
    }

    constructor(
        IRegistry _registry,
        bytes32 _baseNode,
        string memory tld,
        address initialOwner
    ) ERC721(string.concat("Oniym .", tld), string.concat("ONM.", tld)) Ownable(initialOwner) {
        REGISTRY = _registry;
        BASE_NODE = _baseNode;
        _tldLabel = tld;
    }

    // ---------------------------------------------------------------
    //                       ADMIN / OWNER
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDRegistrar
    function addController(address controller) external override onlyOwner {
        _controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    /// @inheritdoc ITLDRegistrar
    function removeController(address controller) external override onlyOwner {
        _controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    /// @inheritdoc ITLDRegistrar
    function isController(address controller) external view override returns (bool) {
        return _controllers[controller];
    }

    // ---------------------------------------------------------------
    //                        REGISTRATION
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDRegistrar
    /// @dev Mints the NFT to `owner` and creates the registry subnode record.
    ///      Reverts if the name is still within its grace period.
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external override onlyController returns (uint256 expires) {
        if (!available(id)) revert NameUnavailable(id);
        if (duration < MIN_REGISTRATION_DURATION) revert InvalidDuration(duration);

        expires = block.timestamp + duration;
        _expiries[id] = expires;

        // Write registry record: owner = caller-supplied, resolver = zero (controller sets it)
        // forge-lint: disable-next-line(unsafe-typecast) — safe: block.timestamp + duration won't overflow uint64 before year 2554
        REGISTRY.setSubnodeRecord(BASE_NODE, bytes32(id), owner, address(0), uint64(expires));

        // Mint or re-mint the NFT (burn first if expired token still exists in storage)
        if (_ownerOf(id) != address(0)) {
            _burn(id);
        }
        _safeMint(owner, id);

        emit NameRegistered(id, owner, expires);
    }

    /// @inheritdoc ITLDRegistrar
    function renew(
        uint256 id,
        uint256 duration
    ) external override onlyController returns (uint256 expires) {
        if (_expiries[id] == 0) revert NameUnavailable(id);
        if (duration < MIN_REGISTRATION_DURATION) revert InvalidDuration(duration);

        // Renew from current expiry or now (whichever is later)
        uint256 base = _expiries[id] > block.timestamp ? _expiries[id] : block.timestamp;
        expires = base + duration;
        _expiries[id] = expires;

        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 nameNode = keccak256(abi.encodePacked(BASE_NODE, bytes32(id)));
        // forge-lint: disable-next-line(unsafe-typecast) — same safety as register()
        REGISTRY.setExpiry(nameNode, uint64(expires));

        emit NameRenewed(id, expires);
    }

    // ---------------------------------------------------------------
    //                        NFT OPERATIONS
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDRegistrar
    /// @dev Syncs registry ownership to match the current NFT owner.
    ///      Caller must be the current NFT owner or approved.
    function reclaim(uint256 id, address owner) external override {
        if (!_isAuthorized(_ownerOf(id), msg.sender, id)) revert NotTokenOwner(id, msg.sender);
        REGISTRY.setSubnodeOwner(BASE_NODE, bytes32(id), owner);
    }

    // ---------------------------------------------------------------
    //                            READS
    // ---------------------------------------------------------------

    /// @inheritdoc ITLDRegistrar
    function nameExpires(uint256 id) external view override returns (uint256) {
        return _expiries[id];
    }

    /// @inheritdoc ITLDRegistrar
    /// @dev Available = never registered OR expired past grace period.
    function available(uint256 id) public view override returns (bool) {
        uint256 exp = _expiries[id];
        return exp == 0 || exp + GRACE_PERIOD < block.timestamp;
    }

    /// @inheritdoc ITLDRegistrar
    function gracePeriod() external pure override returns (uint256) {
        return GRACE_PERIOD;
    }

    /// @inheritdoc ITLDRegistrar
    function minRegistrationDuration() external pure override returns (uint256) {
        return MIN_REGISTRATION_DURATION;
    }

    /// @inheritdoc ITLDRegistrar
    function baseNode() external view override returns (bytes32) {
        return BASE_NODE;
    }

    /// @inheritdoc ITLDRegistrar
    function tldLabel() external view override returns (string memory) {
        return _tldLabel;
    }

    // ---------------------------------------------------------------
    //                      ERC-721 OVERRIDES
    // ---------------------------------------------------------------

    /// @dev On every token transfer (not mint), sync the registry subnode owner.
    ///      This is called by OZ ERC721._update() — msg.sender context is TLDRegistrar,
    ///      so REGISTRY sees TLDRegistrar as the caller, which owns BASE_NODE. ✓
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address from) {
        from = super._update(to, tokenId, auth);

        // Sync registry on transfers only (not mints — register() handles those)
        if (from != address(0) && to != address(0)) {
            REGISTRY.setSubnodeOwner(BASE_NODE, bytes32(tokenId), to);
        }
    }

    // ---------------------------------------------------------------
    //                          INTERNAL
    // ---------------------------------------------------------------

    function _checkController() internal view {
        if (!_controllers[msg.sender]) revert NotController(msg.sender);
    }
}
