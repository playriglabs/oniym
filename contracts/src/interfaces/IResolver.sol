// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IResolver
/// @notice Multichain resolver interface. Maps node + coinType to an address.
/// @dev coinType follows SLIP-0044: 60=ETH, 501=SOL, 0=BTC, 118=ATOM, etc.
///      Addresses are stored as `bytes` to accommodate non-EVM chains
///      (Solana = 32 bytes, Bitcoin = variable).
interface IResolver {
    // -- Events --

    event AddrChanged(bytes32 indexed node, uint256 coinType, bytes addr);
    event TextChanged(bytes32 indexed node, string indexed indexedKey, string key, string value);
    event ContenthashChanged(bytes32 indexed node, bytes hash);

    // -- Multichain address records --

    /// @notice Set an address for a given chain
    /// @param node  The namehash of the name
    /// @param coinType  SLIP-0044 coin type
    /// @param addr  The address bytes (chain-specific encoding)
    function setAddr(bytes32 node, uint256 coinType, bytes calldata addr) external;

    /// @notice Read an address for a given chain
    function addr(bytes32 node, uint256 coinType) external view returns (bytes memory);

    // -- Text records --

    function setText(bytes32 node, string calldata key, string calldata value) external;
    function text(bytes32 node, string calldata key) external view returns (string memory);

    // -- Content hash (IPFS / Swarm / etc) --

    function setContenthash(bytes32 node, bytes calldata hash) external;
    function contenthash(bytes32 node) external view returns (bytes memory);
}
