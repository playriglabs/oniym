// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ITLDRegistrar
/// @notice ERC-721 registrar for a single protocol-managed TLD (e.g. `.eth`, `.sol`, `.btc`).
/// @dev Generic replacement for IBaseRegistrar (see ADR-007). Each deployed instance
///      manages exactly one TLD. The TLD is fixed at construction; query it via {baseNode}
///      and {tldLabel}.
///
///      Each registered name is an NFT. `tokenId` = `uint256(labelHash)` where
///      `labelHash = keccak256(bytes(label))`. Mirrors ENS BaseRegistrarImplementation
///      for tooling compatibility.
///
///      Ownership flows two ways:
///        NFT owner  ↔  registry.ownerOf(namehash(label + "." + tld))
///      Transferring the NFT transfers registry ownership atomically via {reclaim}.
///      The registrar is the sole writer of subnode records under its TLD root node.
interface ITLDRegistrar is IERC721 {
    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    /// @notice Emitted when a controller contract is added
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a controller is removed
    event ControllerRemoved(address indexed controller);

    /// @notice Emitted on new name registration
    /// @param id      The token ID (uint256 of labelHash)
    /// @param owner   The initial owner
    /// @param expires Unix timestamp when registration expires
    event NameRegistered(uint256 indexed id, address indexed owner, uint256 expires);

    /// @notice Emitted on registration renewal
    event NameRenewed(uint256 indexed id, uint256 expires);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice Label is unavailable (either active or within grace period)
    error NameUnavailable(uint256 id);

    /// @notice Registration duration is outside the acceptable range
    error InvalidDuration(uint256 duration);

    /// @notice Caller is not an authorized controller
    error NotController(address caller);

    /// @notice Caller is not the token owner
    error NotTokenOwner(uint256 id, address caller);

    // ---------------------------------------------------------------
    //                        ADMIN / OWNER
    // ---------------------------------------------------------------

    /// @notice Add a controller that is allowed to register/renew names
    /// @dev Typically IRegistrarController, but additional controllers can be
    ///      added for other registration paths (allowlist, airdrop, merkle claim).
    function addController(address controller) external;

    /// @notice Revoke a controller's registration privileges
    function removeController(address controller) external;

    /// @notice Query controller status
    function isController(address controller) external view returns (bool);

    // ---------------------------------------------------------------
    //                      REGISTRATION
    // ---------------------------------------------------------------

    /// @notice Register a name for a fixed duration
    /// @dev Only callable by an authorized controller
    /// @param id       The token ID (uint256 of labelHash)
    /// @param owner    The owner to receive the NFT and registry ownership
    /// @param duration Duration of the registration in seconds
    /// @return expires The expiry timestamp set for this registration
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external returns (uint256 expires);

    /// @notice Renew an existing registration
    /// @dev Only callable by an authorized controller. Adds duration to existing
    ///      expiry (or from block.timestamp if already expired).
    function renew(uint256 id, uint256 duration) external returns (uint256 expires);

    // ---------------------------------------------------------------
    //                       NFT OPERATIONS
    // ---------------------------------------------------------------

    /// @notice Reclaim registry ownership after a token transfer
    /// @dev Called automatically during ERC-721 transfers to keep registry in sync.
    ///      Can also be called manually by the current NFT owner if drift occurs.
    function reclaim(uint256 id, address owner) external;

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @notice Unix timestamp when a registration expires
    function nameExpires(uint256 id) external view returns (uint256);

    /// @notice True if a name can be newly registered right now
    /// @dev Returns false both during active registration AND during grace period
    function available(uint256 id) external view returns (bool);

    /// @notice Grace period after expiry during which the owner can still renew
    /// @dev After expiry + gracePeriod, the name becomes available to others.
    ///      Matches ENS convention of 90 days.
    function gracePeriod() external view returns (uint256);

    /// @notice Minimum allowed registration duration (e.g. 28 days)
    function minRegistrationDuration() external view returns (uint256);

    /// @notice The namehash of the TLD this registrar manages (e.g. namehash("eth"))
    function baseNode() external view returns (bytes32);

    /// @notice The human-readable TLD label without the leading dot (e.g. "eth", "sol", "btc")
    function tldLabel() external view returns (string memory);
}
