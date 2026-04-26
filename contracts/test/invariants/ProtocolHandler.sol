// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Registry } from "../../src/Registry.sol";
import { TLDRegistrar } from "../../src/TLDRegistrar.sol";
import { RegistrarController } from "../../src/RegistrarController.sol";
import { IRegistrarController } from "../../src/interfaces/IRegistrarController.sol";

/// @dev Handler wraps all state-changing protocol functions with bounded, valid inputs.
///      Ghost variables shadow on-chain state so invariant contracts can assert
///      expected values without re-deriving them from raw contract storage.
contract ProtocolHandler is CommonBase, StdCheats, StdUtils {
    // ---------------------------------------------------------------
    //                      PROTOCOL CONTRACTS
    // ---------------------------------------------------------------

    Registry public reg;
    TLDRegistrar public registrar;
    RegistrarController public ctrl;
    bytes32 public tldNode;
    address public protocolOwner;

    // ---------------------------------------------------------------
    //                         FIXED TEST SPACE
    // ---------------------------------------------------------------

    // 5 names × 3 users = manageable state space for invariant exploration
    string[5] internal _names = ["aaa", "bbb", "ccc", "ddd", "eee"];
    address[3] internal _users;

    // ---------------------------------------------------------------
    //                       GHOST VARIABLES
    // ---------------------------------------------------------------

    /// @dev Total ETH paid via register() and renew()
    uint256 public ghostTotalPaid;

    /// @dev Total ETH removed via withdraw()
    uint256 public ghostTotalWithdrawn;

    /// @dev tokenId => last recorded expiry (set on register / renew)
    mapping(uint256 => uint256) public ghostLastExpiry;

    /// @dev tokenId => whether the name has ever been registered
    mapping(uint256 => bool) public ghostEverRegistered;

    constructor(
        Registry _reg,
        TLDRegistrar _registrar,
        RegistrarController _ctrl,
        bytes32 _tldNode,
        address _protocolOwner
    ) {
        reg = _reg;
        registrar = _registrar;
        ctrl = _ctrl;
        tldNode = _tldNode;
        protocolOwner = _protocolOwner;

        _users[0] = makeAddr("user0");
        _users[1] = makeAddr("user1");
        _users[2] = makeAddr("user2");
    }

    // ---------------------------------------------------------------
    //                         ACTIONS
    // ---------------------------------------------------------------

    function register(uint256 nameIdx, uint256 userIdx, uint256 durationSeed) external {
        string memory name = _names[bound(nameIdx, 0, _names.length - 1)];
        address user = _users[bound(userIdx, 0, _users.length - 1)];
        uint256 duration = bound(durationSeed, 28 days, 365 days);

        uint256 tokenId = uint256(keccak256(bytes(name)));
        if (!registrar.available(tokenId)) return;

        IRegistrarController.RegisterRequest memory req = IRegistrarController.RegisterRequest({
            name: name,
            tld: tldNode,
            owner: user,
            duration: duration,
            secret: keccak256("handler-secret"),
            resolver: address(0),
            resolverData: new bytes[](0),
            reverseRecord: false
        });

        bytes32 commitment = ctrl.makeCommitment(req);
        if (ctrl.commitments(commitment) != 0) return; // already committed

        ctrl.commit(commitment);
        vm.warp(block.timestamp + ctrl.MIN_COMMITMENT_AGE() + 1);

        (uint256 base, uint256 premium) = ctrl.rentPrice(name, tldNode, duration);
        uint256 price = base + premium;
        vm.deal(address(this), price);

        uint256 expectedExpiry = block.timestamp + duration;
        ctrl.register{ value: price }(req);

        ghostTotalPaid += price;
        ghostLastExpiry[tokenId] = expectedExpiry;
        ghostEverRegistered[tokenId] = true;
    }

    function renew(uint256 nameIdx, uint256 durationSeed) external {
        string memory name = _names[bound(nameIdx, 0, _names.length - 1)];
        uint256 duration = bound(durationSeed, 28 days, 365 days);
        uint256 tokenId = uint256(keccak256(bytes(name)));

        // Must be registered (even if expired — renew still works within grace period)
        if (!ghostEverRegistered[tokenId]) return;
        if (registrar.available(tokenId)) return; // past grace period

        uint256 expBefore = registrar.nameExpires(tokenId);
        uint256 renewBase = expBefore > block.timestamp ? expBefore : block.timestamp;
        uint256 expectedExpiry = renewBase + duration;

        (uint256 base, uint256 premium) = ctrl.rentPrice(name, tldNode, duration);
        uint256 price = base + premium;
        vm.deal(address(this), price);

        ctrl.renew{ value: price }(name, tldNode, duration);

        ghostTotalPaid += price;
        ghostLastExpiry[tokenId] = expectedExpiry;
    }

    function withdraw() external {
        uint256 bal = address(ctrl).balance;
        if (bal == 0) return;

        address treasury = makeAddr("treasury");
        vm.prank(protocolOwner);
        ctrl.withdraw(treasury);

        ghostTotalWithdrawn += bal;
    }

    function warpTime(uint256 seconds_) external {
        // Bound to 0–730 days to exercise expiry and grace period paths
        vm.warp(block.timestamp + bound(seconds_, 0, 730 days));
    }

    // ---------------------------------------------------------------
    //                          HELPERS
    // ---------------------------------------------------------------

    function names() external view returns (string[5] memory) {
        return _names;
    }

    function users() external view returns (address[3] memory) {
        return _users;
    }
}
