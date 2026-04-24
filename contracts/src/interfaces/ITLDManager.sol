// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ITLDManager
/// @notice Protocol-owned registry of all active TLDs.
/// @dev Owns each TLD's root node in the Registry and authorizes ITLDRegistrar
///      deployments. New TLDs can be added post-launch via {addTld} without
///      touching the Registry or Resolver contracts.
///
///      Launch TLDs (see ADR-007):
///        .eth  — Ethereum / EVM-native users  (SLIP-0044 coinType 60)
///        .sol  — Solana-native users           (SLIP-0044 coinType 501)
///        .btc  — Bitcoin-native users          (SLIP-0044 coinType 0)
///        .sui  — Sui-native users              (SLIP-0044 coinType 784)
///        .base — Base ecosystem users          (SLIP-0044 coinType 8453)
interface ITLDManager {
    // ---------------------------------------------------------------
    //                           STRUCTS
    // ---------------------------------------------------------------

    /// @notice Metadata for a protocol-managed TLD
    struct Tld {
        bytes32 node; // namehash of the TLD label (e.g. namehash("eth"))
        string label; // human-readable label without dot (e.g. "eth")
        address registrar; // ITLDRegistrar managing this TLD
        bool active; // whether new registrations are open
    }

    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    /// @notice Emitted when a new TLD is added to the protocol
    event TLDAdded(bytes32 indexed node, string label, address registrar);

    /// @notice Emitted when a TLD's active status changes
    event TLDStatusChanged(bytes32 indexed node, bool active);

    /// @notice Emitted when a TLD's registrar contract is replaced
    event RegistrarUpdated(bytes32 indexed node, address oldRegistrar, address newRegistrar);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    /// @notice TLD label is already registered in this protocol
    error TLDAlreadyExists(bytes32 node);

    /// @notice TLD node not found in this protocol
    error TLDNotFound(bytes32 node);

    /// @notice TLD is inactive; registrations are paused for this TLD
    error TLDInactive(bytes32 node);

    /// @notice Registrar address cannot be zero
    error ZeroRegistrar();

    /// @notice Protocol has reached the maximum number of TLDs
    error MaxTldCountReached(uint256 max);

    /// @notice TLD label exceeds the maximum allowed character length
    error TldLabelTooLong(string label, uint256 length, uint256 max);

    // ---------------------------------------------------------------
    //                        CONSTANTS
    // ---------------------------------------------------------------

    /// @notice Maximum number of TLDs this protocol will ever register
    /// @dev Hard cap — reverts with MaxTldCountReached once reached
    function maxTldCount() external pure returns (uint256); // 10

    /// @notice Maximum character length of a TLD label (excluding leading dot)
    /// @dev Reverts with TldLabelTooLong if exceeded
    function maxTldLabelLength() external pure returns (uint256); // 5

    // ---------------------------------------------------------------
    //                           ADMIN
    // ---------------------------------------------------------------

    /// @notice Add a new TLD to the protocol
    /// @dev Caller must be protocol owner. Reverts if MAX_TLD_COUNT is reached
    ///      or if label exceeds MAX_TLD_LABEL_LENGTH. Registers the TLD root
    ///      node in the Registry and grants the registrar subnode write access.
    /// @param label      Human-readable TLD label without leading dot (e.g. "id", "xyz")
    /// @param registrar  The ITLDRegistrar to authorize for this TLD
    /// @return node      The namehash of the TLD label
    function addTld(string calldata label, address registrar) external returns (bytes32 node);

    /// @notice Open or close registrations for a TLD
    function setTldActive(bytes32 node, bool active) external;

    /// @notice Replace the registrar for an existing TLD
    /// @dev Used when upgrading the registrar contract. Revokes the old
    ///      registrar's controller status and grants it to the new one.
    function setRegistrar(bytes32 node, address registrar) external;

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @notice Get TLD metadata by namehash node
    function getTld(bytes32 node) external view returns (Tld memory);

    /// @notice Get TLD metadata by label string (e.g. "eth")
    function getTldByLabel(string calldata label) external view returns (Tld memory);

    /// @notice List all registered TLDs (active and inactive)
    function listTlds() external view returns (Tld[] memory);

    /// @notice True if the TLD is registered and currently accepting registrations
    function isActiveTld(bytes32 node) external view returns (bool);

    /// @notice True if the label corresponds to any registered TLD (active or not)
    function isTld(string calldata label) external view returns (bool);
}
