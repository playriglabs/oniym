// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IRegistrarController
/// @notice Public-facing registration controller for all protocol-managed TLD names.
/// @dev Replaces IETHRegistrarController (see ADR-007). TLD-agnostic: the caller
///      specifies which TLD they are registering under via {RegisterRequest.tld}.
///
///      Implements a commit-reveal registration flow to prevent mempool
///      frontrunning bots from stealing desirable names.
///
/// # Commit-reveal flow
///
///   Step 1 (commit):
///     User computes `commitment = keccak256(name, tld, owner, duration, secret, resolver)`
///     and submits it via {commit}. Neither the name nor the TLD is revealed on-chain.
///
///   Step 2 (wait):
///     User must wait at least `MIN_COMMITMENT_AGE` (e.g. 60 seconds) before
///     revealing. Frontrunners cannot race the registration because they don't
///     know the name or TLD.
///
///   Step 3 (register):
///     User submits {register} with the full parameters plus `secret`.
///     Contract rebuilds the commitment hash, verifies it exists and is aged
///     appropriately, mints the NFT via ITLDRegistrar, stores the resolver address.
///
///   Step 4 (expiry):
///     Commitments expire after `MAX_COMMITMENT_AGE` to prevent replay of old commits.
///
/// # Security invariants
///
/// - Every successful register() consumes exactly one commitment
/// - A commitment cannot be reused (prevents same-secret replays)
/// - Registration price MUST be paid in ETH at register() time, not commit() time
///   (prevents committers from locking in old prices)
/// - Controller validates the requested TLD is active in ITLDManager before proceeding
interface IRegistrarController {
    // ---------------------------------------------------------------
    //                           STRUCTS
    // ---------------------------------------------------------------

    /// @notice Registration parameters bundle
    /// @dev Bundled to keep {register} signature readable and allow future extensions
    ///      (referrals, discounts) without breaking callers.
    struct RegisterRequest {
        string name; // label only, no TLD (e.g. "kyy")
        bytes32 tld; // namehash of the TLD (e.g. namehash("eth"))
        address owner;
        uint256 duration;
        bytes32 secret;
        address resolver;
        bytes[] resolverData; // batch setAddr / setText calls applied atomically at registration
        bool reverseRecord; // opt-in: set the reverse record at registration time
    }

    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    event NameRegistered(
        string name,
        bytes32 indexed tld,
        bytes32 indexed label,
        address indexed owner,
        uint256 baseCost,
        uint256 premium,
        uint256 expires
    );

    event NameRenewed(
        string name,
        bytes32 indexed tld,
        bytes32 indexed label,
        uint256 cost,
        uint256 expires
    );

    /// @notice Emitted when accumulated ETH fees are withdrawn
    event FeesWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when accumulated ERC-20 fees (e.g. USDC) are withdrawn
    event TokenFeesWithdrawn(address indexed token, address indexed to, uint256 amount);

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

    /// @notice Insufficient ETH sent to cover the quoted price
    error InsufficientValue(uint256 required, uint256 provided);

    /// @notice Payment token is not address(0) (ETH) or the whitelisted USDC address
    error UnsupportedPaymentToken(address token);

    /// @notice Name label contains invalid characters or is below minimum length
    error InvalidName(string name);

    /// @notice Name is currently unavailable under the requested TLD
    error NameUnavailable(string name, bytes32 tld);

    /// @notice Duration is outside min/max bounds
    error InvalidDuration(uint256 duration);

    /// @notice Resolver multicall failed — likely malformed encoded call
    error ResolverCallFailed(uint256 index, bytes returnData);

    /// @notice Resolver data was provided but resolver address is zero
    error ResolverRequired();

    /// @notice Requested TLD is not active in the protocol
    error TLDNotActive(bytes32 tld);

    // ---------------------------------------------------------------
    //                    COMMIT-REVEAL CONSTANTS
    // ---------------------------------------------------------------

    /// @notice Minimum age a commitment must have before it can be revealed
    /// @dev Typically 60 seconds. Short enough for UX, long enough to prevent frontrunning.
    function MIN_COMMITMENT_AGE() external view returns (uint256);

    /// @notice Maximum age of a commitment before it is considered expired
    /// @dev Typically 1–24 hours. Prevents replay of stale commitments.
    function MAX_COMMITMENT_AGE() external view returns (uint256);

    // ---------------------------------------------------------------
    //                           COMMITS
    // ---------------------------------------------------------------

    /// @notice Compute the commitment hash for a registration request
    /// @dev Pure function. Users call this off-chain to compute what to submit to {commit}.
    function makeCommitment(RegisterRequest calldata req) external pure returns (bytes32);

    /// @notice Submit a commitment for a future registration
    /// @dev Idempotent per commitment hash; cannot overwrite an active commitment.
    function commit(bytes32 commitment) external;

    /// @notice Timestamp when a commitment was submitted (0 if not present)
    function commitments(bytes32 commitment) external view returns (uint256);

    // ---------------------------------------------------------------
    //                         REGISTRATION
    // ---------------------------------------------------------------

    /// @notice Check if a name is available for registration under a specific TLD
    /// @dev Rejects names shorter than {minNameLength} and names currently owned.
    function available(string calldata name, bytes32 tld) external view returns (bool);

    /// @notice Validate a name label (length, charset)
    /// @return True if the label can be registered when available
    function valid(string calldata name) external view returns (bool);

    /// @notice Minimum allowed label length (e.g. 3 characters)
    function minNameLength() external view returns (uint256);

    /// @notice Quote total price in wei for registering a name under a specific TLD
    function rentPrice(
        string calldata name,
        bytes32 tld,
        uint256 duration
    ) external view returns (uint256 base, uint256 premium);

    /// @notice Register a name using a previously committed request
    /// @param req Registration parameters
    /// @param paymentToken address(0) to pay with ETH, USDC address to pay with USDC
    /// @dev ETH path: msg.value >= rentPrice; excess refunded.
    ///      USDC path: caller must approve controller first (or use EIP-2612 permit).
    function register(RegisterRequest calldata req, address paymentToken) external payable;

    /// @notice Renew an existing registration — no commit-reveal required
    /// @param paymentToken address(0) for ETH, USDC address for USDC
    /// @dev Renewal isn't frontrunnable because it doesn't change ownership.
    function renew(string calldata name, bytes32 tld, uint256 duration, address paymentToken)
        external
        payable;

    // ---------------------------------------------------------------
    //                      ADMIN / PROTOCOL
    // ---------------------------------------------------------------

    /// @notice Withdraw accumulated ETH registration fees
    /// @dev Only callable by protocol owner (multisig / DAO)
    function withdrawEth(address to) external;

    /// @notice Withdraw accumulated ERC-20 registration fees (e.g. USDC)
    /// @dev Only callable by protocol owner
    function withdrawToken(address token, address to) external;

    /// @notice The whitelisted USDC token address accepted as payment
    function USDC_TOKEN() external view returns (address);

    /// @notice Pause all user-facing writes (commit, register, renew)
    /// @dev Only callable by protocol owner. Existing name ownership is NOT affected —
    ///      users can still transfer names and update resolvers via Registry / Registrar.
    function pause() external;

    /// @notice Resume operations after a pause
    function unpause() external;

    /// @notice Query paused status
    function paused() external view returns (bool);
}
