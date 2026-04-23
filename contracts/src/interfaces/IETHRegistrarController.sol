// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IETHRegistrarController
/// @notice Public-facing registration controller for `.oniym` names
/// @dev Implements a commit-reveal registration flow to prevent mempool
///      frontrunning bots from stealing desirable names.
///
/// # Commit-reveal flow
///
///   Step 1 (commit):
///     User computes `commitment = keccak256(name, owner, duration, secret, resolver)`
///     and submits it via {commit}. The contract stores the commitment
///     timestamp. The name itself is never revealed in this tx.
///
///   Step 2 (wait):
///     User must wait at least `MIN_COMMITMENT_AGE` (e.g. 60 seconds) before
///     revealing. During this window, frontrunners cannot race the
///     registration because they don't know the name.
///
///   Step 3 (register):
///     User submits {register} with the full parameters plus `secret`.
///     The contract rebuilds the commitment hash, verifies it exists and is
///     aged appropriately, mints the NFT, and stores the resolver address.
///
///   Step 4 (expiry):
///     Commitments expire after `MAX_COMMITMENT_AGE` (e.g. 1 hour) to prevent
///     old commitments from being replayed.
///
/// # Security invariants
///
/// - Every successful register() consumes exactly one commitment
/// - A commitment cannot be reused (prevents same-secret replays)
/// - Registration price MUST be paid in ETH at register() time, not commit() time
///   (prevents committers from locking in old prices)
/// - The `secret` must be unguessable in the commit-window or the bot can race
interface IETHRegistrarController {
    // ---------------------------------------------------------------
    //                           STRUCTS
    // ---------------------------------------------------------------

    /// @notice Registration parameters bundle
    /// @dev Bundled to keep {register} signature readable and enable future
    ///      extensions (e.g. resolver data pre-population, referrals) without
    ///      breaking callers.
    struct RegisterRequest {
        string name;
        address owner;
        uint256 duration;
        bytes32 secret;
        address resolver;
        bytes[] resolverData;
        bool reverseRecord;
    }

    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint256 baseCost,
        uint256 premium,
        uint256 expires
    );

    event NameRenewed(string name, bytes32 indexed label, uint256 cost, uint256 expires);

    /// @notice Emitted when fees are withdrawn by the owner
    event FeesWithdrawn(address indexed to, uint256 amount);

    // Note: `Paused` and `Unpaused` events come from OpenZeppelin's {Pausable}
    //       and are re-emitted automatically in the implementation.

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice Commitment not found — caller must commit first
    error CommitmentNotFound(bytes32 commitment);

    /// @notice Commitment submitted too recently (MIN_COMMITMENT_AGE not elapsed)
    error CommitmentTooNew(bytes32 commitment);

    /// @notice Commitment has expired (MAX_COMMITMENT_AGE exceeded)
    error CommitmentTooOld(bytes32 commitment);

    /// @notice Commitment already exists and is still active
    error CommitmentAlreadyExists(bytes32 commitment);

    /// @notice Insufficient ETH sent to cover price
    error InsufficientValue(uint256 required, uint256 provided);

    /// @notice Name label contains invalid characters or structure
    error InvalidName(string name);

    /// @notice Name is currently unavailable
    error NameUnavailable(string name);

    /// @notice Duration is outside min/max bounds
    error InvalidDuration(uint256 duration);

    /// @notice Resolver data multicall failed — likely malformed encoded call
    error ResolverCallFailed(uint256 index, bytes returnData);

    /// @notice Resolver data was provided but resolver address is zero
    error ResolverRequired();

    // ---------------------------------------------------------------
    //                    COMMIT-REVEAL CONSTANTS
    // ---------------------------------------------------------------

    /// @notice Minimum age a commitment must have before it can be revealed
    /// @dev Typically 60 seconds. Short enough for UX, long enough to prevent frontrunning
    function MIN_COMMITMENT_AGE() external view returns (uint256);

    /// @notice Maximum age of a commitment before it's considered expired
    /// @dev Typically 1-24 hours. Prevents replay of ancient commitments.
    function MAX_COMMITMENT_AGE() external view returns (uint256);

    // ---------------------------------------------------------------
    //                           COMMITS
    // ---------------------------------------------------------------

    /// @notice Compute the commitment hash for a registration request
    /// @dev Pure function. Users call this off-chain to compute what to submit
    ///      to {commit}, OR on-chain wrappers can call this to verify.
    function makeCommitment(RegisterRequest calldata req) external pure returns (bytes32);

    /// @notice Submit a commitment for a future registration
    /// @dev Idempotent per commitment hash; cannot overwrite an active commitment
    function commit(bytes32 commitment) external;

    /// @notice Timestamp when a commitment was submitted (0 if not present)
    function commitments(bytes32 commitment) external view returns (uint256);

    // ---------------------------------------------------------------
    //                         REGISTRATION
    // ---------------------------------------------------------------

    /// @notice Check if a name is available for registration right now
    /// @dev Rejects names shorter than {minNameLength} and names currently owned
    function available(string calldata name) external view returns (bool);

    /// @notice Validate a name's label structure (length, charset)
    /// @return True if the name can be registered if available
    function valid(string calldata name) external view returns (bool);

    /// @notice Minimum allowed label length (e.g. 3 chars)
    function minNameLength() external view returns (uint256);

    /// @notice Quote total price in wei for a registration
    function rentPrice(
        string calldata name,
        uint256 duration
    ) external view returns (uint256 base, uint256 premium);

    /// @notice Register a name using a previously committed request
    /// @dev Must be called with msg.value >= rentPrice. Excess is refunded.
    function register(RegisterRequest calldata req) external payable;

    /// @notice Renew an existing registration — no commit-reveal required
    /// @dev Renewal isn't front-runnable because it doesn't change ownership
    function renew(string calldata name, uint256 duration) external payable;

    // ---------------------------------------------------------------
    //                      ADMIN / PROTOCOL
    // ---------------------------------------------------------------

    /// @notice Withdraw accumulated registration fees
    /// @dev Only callable by protocol owner (multisig/DAO)
    function withdraw(address to) external;

    /// @notice Pause all user-facing write functions (commit, register, renew)
    /// @dev Only callable by protocol owner. Use in emergencies only.
    ///      Existing name ownership is NOT affected — users can still transfer
    ///      names and update resolvers directly via the Registry/Registrar.
    function pause() external;

    /// @notice Resume operations after a pause
    function unpause() external;

    /// @notice Query paused status
    function paused() external view returns (bool);
}
