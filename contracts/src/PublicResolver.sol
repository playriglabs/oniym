// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IResolver } from "./interfaces/IResolver.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

/// @title PublicResolver
/// @notice Stores multichain addresses, text records, and contenthashes for names.
/// @dev Authorization: node owner, registry-level operators (setApprovalForAll),
///      or resolver-level delegates (approve()) may write records for a node.
///
///      Coin types follow SLIP-0044:
///        0   = BTC, 60  = ETH, 118 = ATOM, 195 = TRX,
///        501 = SOL, 714 = BNB, 784 = SUI,  637 = APT
contract PublicResolver is IResolver, IERC165 {
    IRegistry public immutable REGISTRY;

    error Unauthorised(bytes32 node, address caller);

    /// @dev Emitted when resolver-level delegation changes for a node.
    event Approved(
        address indexed owner,
        bytes32 indexed node,
        address indexed delegate,
        bool approved
    );

    /// @dev node => coinType => chain-native address bytes (SLIP-0044 encoding)
    mapping(bytes32 => mapping(uint256 => bytes)) private _addrs;

    /// @dev node => key => value
    mapping(bytes32 => mapping(string => string)) private _texts;

    /// @dev node => contenthash (IPFS multihash, Swarm, etc.)
    mapping(bytes32 => bytes) private _contenthashes;

    /// @dev node => delegate => approved  (resolver-level, narrower than registry operators)
    mapping(bytes32 => mapping(address => bool)) private _approved;

    modifier authorised(bytes32 node) {
        _checkAuthorised(node);
        _;
    }

    constructor(IRegistry _registry) {
        REGISTRY = _registry;
    }

    // ---------------------------------------------------------------
    //                        DELEGATION
    // ---------------------------------------------------------------

    /// @notice Grant or revoke resolver-level write access for a single node.
    /// @dev Only the current node owner can delegate. Useful when the owner wants
    ///      to let a separate key manage records without a full registry operator grant.
    function approve(bytes32 node, address delegate, bool approved) external {
        address owner = REGISTRY.ownerOf(node);
        if (msg.sender != owner) revert Unauthorised(node, msg.sender);
        _approved[node][delegate] = approved;
        emit Approved(owner, node, delegate, approved);
    }

    /// @notice Check whether `delegate` has resolver-level approval for `node`.
    function isApprovedFor(bytes32 node, address delegate) external view returns (bool) {
        return _approved[node][delegate];
    }

    // ---------------------------------------------------------------
    //                    MULTICHAIN ADDRESSES
    // ---------------------------------------------------------------

    /// @inheritdoc IResolver
    function setAddr(
        bytes32 node,
        uint256 coinType,
        bytes calldata _addr
    ) external override authorised(node) {
        _addrs[node][coinType] = _addr;
        emit AddrChanged(node, coinType, _addr);
    }

    /// @inheritdoc IResolver
    function addr(bytes32 node, uint256 coinType) external view override returns (bytes memory) {
        return _addrs[node][coinType];
    }

    // ---------------------------------------------------------------
    //                       TEXT RECORDS
    // ---------------------------------------------------------------

    /// @inheritdoc IResolver
    function setText(
        bytes32 node,
        string calldata key,
        string calldata value
    ) external override authorised(node) {
        _texts[node][key] = value;
        emit TextChanged(node, key, key, value);
    }

    /// @inheritdoc IResolver
    function text(
        bytes32 node,
        string calldata key
    ) external view override returns (string memory) {
        return _texts[node][key];
    }

    // ---------------------------------------------------------------
    //                       CONTENTHASH
    // ---------------------------------------------------------------

    /// @inheritdoc IResolver
    function setContenthash(
        bytes32 node,
        bytes calldata hash
    ) external override authorised(node) {
        _contenthashes[node] = hash;
        emit ContenthashChanged(node, hash);
    }

    /// @inheritdoc IResolver
    function contenthash(bytes32 node) external view override returns (bytes memory) {
        return _contenthashes[node];
    }

    // ---------------------------------------------------------------
    //                          ERC-165
    // ---------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IResolver).interfaceId;
    }

    // ---------------------------------------------------------------
    //                         INTERNAL
    // ---------------------------------------------------------------

    function _checkAuthorised(bytes32 node) internal view {
        address owner = REGISTRY.ownerOf(node);
        if (msg.sender == owner) return;
        if (REGISTRY.isApprovedForAll(owner, msg.sender)) return;
        if (_approved[node][msg.sender]) return;
        revert Unauthorised(node, msg.sender);
    }
}
