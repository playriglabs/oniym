// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IReverseRegistrar
/// @notice Manages reverse resolution: "0x123... → kyy.oniym"
/// @dev Reverse records live at a special namespace `[hex-address].addr.reverse`
///      under the reverse-resolution TLD. This mirrors ENS's ReverseRegistrar.
///
/// # Why reverse resolution matters
///
/// Forward resolution answers: "What address should I send to for kyy.oniym?"
/// Reverse resolution answers: "What name should I display for 0x123...?"
///
/// Without reverse resolution, dApps showing user addresses can't display
/// friendly names unless they separately map addresses to names.
///
/// # Trust model
///
/// Reverse records are PERMISSIONLESS — anyone can claim "my address points
/// to bob.oniym", even if they don't own bob.oniym. Therefore, dApps MUST
/// always verify forward resolution matches:
///
///   1. Read reverse: 0x123... → claims "kyy.oniym"
///   2. Read forward: kyy.oniym → is address 0x123... in the addr list?
///   3. Only if both match, display "kyy.oniym"
///
/// This pattern is called "Reverse + Forward verification."
interface IReverseRegistrar {
    // ---------------------------------------------------------------
    //                           EVENTS
    // ---------------------------------------------------------------

    event ReverseClaimed(address indexed addr, bytes32 indexed node);
    event DefaultResolverChanged(address indexed resolver);

    // ---------------------------------------------------------------
    //                           ERRORS
    // ---------------------------------------------------------------

    error Unauthorized(address caller);

    // ---------------------------------------------------------------
    //                           WRITES
    // ---------------------------------------------------------------

    /// @notice Claim the reverse record for msg.sender
    /// @dev Sets msg.sender's reverse record owner to `owner`, pointing to
    ///      the default resolver.
    function claim(address owner) external returns (bytes32 node);

    /// @notice Claim reverse record for msg.sender with a custom resolver
    function claimWithResolver(address owner, address resolver) external returns (bytes32 node);

    /// @notice Claim and immediately set the `name` text record
    /// @dev Convenience function used by ETHRegistrarController when the
    ///      user opts in via `reverseRecord: true` at registration time.
    function setName(string calldata name) external returns (bytes32 node);

    /// @notice Set the reverse record for `addr` (requires authorization)
    /// @dev Authorization: (a) addr is msg.sender, (b) msg.sender is owner of addr's reverse record,
    ///      (c) msg.sender is an approved controller.
    function setNameForAddr(
        address addr,
        address owner,
        address resolver,
        string calldata name
    ) external returns (bytes32 node);

    // ---------------------------------------------------------------
    //                           READS
    // ---------------------------------------------------------------

    /// @notice Compute the reverse namehash for an address
    /// @dev node = namehash("[lowercase-hex-without-0x].addr.reverse")
    function node(address addr) external pure returns (bytes32);

    /// @notice The default resolver used when none is explicitly set
    function defaultResolver() external view returns (address);
}
