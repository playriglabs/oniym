// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IBaseRegistrar
/// @notice ERC-721 registrar for `.oniym` second-level names
/// @dev Each registered name is an NFT. The `tokenId` is `uint256(labelHash)`
///      where `labelHash = keccak256(bytes(label))`. This mirrors ENS's
///      BaseRegistrarImplementation for tooling compatibility.
///
/// Ownership flows two ways:
///   NFT owner  ↔  registry.ownerOf(namehash(label + ".oniym"))
/// Transferring the NFT transfers the registry ownership atomically via
/// {reclaim}. The registrar is the sole writer of subnode records under the
/// `.oniym` TLD.
interface IBaseRegistrar is IERC721 {
    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    /// @notice Emitted when a controller contract is added
    event ControllerAdded(address indexed controller);

    /// @notice Emitted when a controller is removed
    event ControllerRemoved(address indexed controller);

    /// @notice Emitted on new name registration
    /// @param id The token ID (uint256 of labelHash)
    /// @param owner The initial owner
    /// @param expires Unix timestamp when registration expires
    event NameRegistered(uint256 indexed id, address indexed owner, uint256 expires);

    /// @notice Emitted on registration renewal
    event NameRenewed(uint256 indexed id, uint256 expires);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice Label is unavailable (either active or in grace period)
    error NameUnavailable(uint256 id);

    /// @notice Registration duration is outside acceptable range
    error InvalidDuration(uint256 duration);

    /// @notice Caller is not an authorized controller
    error NotController(address caller);

    /// @notice Caller is not the token owner
    error NotTokenOwner(uint256 id, address caller);

    // ---------------------------------------------------------------
    //                        ADMIN / OWNER
    // ---------------------------------------------------------------

    /// @notice Add a controller that is allowed to register/renew names
    /// @dev The controller is typically the ETHRegistrarController, but
    ///      additional controllers can be added for different registration
    ///      paths (e.g. allowlist, airdrop, merkle-proof claim).
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
    /// @param id  The token ID (uint256 of labelHash)
    /// @param owner The owner to receive the NFT and registry ownership
    /// @param duration Duration of the registration in seconds
    /// @return expires The expiry timestamp set for this registration
    function register(
        uint256 id,
        address owner,
        uint256 duration
    ) external returns (uint256 expires);

    /// @notice Renew an existing registration
    /// @dev Only callable by an authorized controller. Adds duration onto
    ///      existing expiry (or from now if already expired).
    function renew(uint256 id, uint256 duration) external returns (uint256 expires);

    // ---------------------------------------------------------------
    //                       NFT OPERATIONS
    // ---------------------------------------------------------------

    /// @notice Reclaim registry ownership after a transfer
    /// @dev Called automatically during ERC-721 transfers to sync registry
    ///      state. Can also be called manually by the current NFT owner if
    ///      ownership drift occurs.
    function reclaim(uint256 id, address owner) external;

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @notice Unix timestamp when registration expires
    function nameExpires(uint256 id) external view returns (uint256);

    /// @notice True if name can be newly registered right now
    /// @dev Returns false both during active registration AND during grace period
    function available(uint256 id) external view returns (bool);

    /// @notice The grace period after expiry during which owner can still renew
    /// @dev After expiry + gracePeriod, the name becomes available to others.
    ///      Matches ENS convention of 90 days.
    function GRACE_PERIOD() external view returns (uint256);

    /// @notice Minimum allowed registration duration (e.g. 28 days)
    function MIN_REGISTRATION_DURATION() external view returns (uint256);

    /// @notice The namehash of the TLD this registrar manages (e.g. namehash("oniym"))
    function baseNode() external view returns (bytes32);
}
