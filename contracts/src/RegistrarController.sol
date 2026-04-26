// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IRegistrarController } from "./interfaces/IRegistrarController.sol";
import { ITLDManager } from "./interfaces/ITLDManager.sol";
import { ITLDRegistrar } from "./interfaces/ITLDRegistrar.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { IReverseRegistrar } from "./interfaces/IReverseRegistrar.sol";

/// @title RegistrarController
/// @notice Public-facing registration controller for all protocol TLDs.
/// @dev Commit-reveal flow prevents frontrunning:
///      1. commit(makeCommitment(req))  — name is hidden
///      2. wait >= MIN_COMMITMENT_AGE
///      3. register(req) + msg.value   — reveals and registers
///
///      At registration time, the controller temporarily holds ownership of the
///      name node so it can set resolver data atomically, then transfers to
///      req.owner via NFT transfer (which triggers the registry sync hook).
contract RegistrarController is IRegistrarController, Ownable2Step, Pausable {
    uint256 public constant override MIN_COMMITMENT_AGE = 60 seconds;
    uint256 public constant override MAX_COMMITMENT_AGE = 24 hours;
    uint256 public constant MIN_NAME_LENGTH = 3;

    IRegistry public immutable REGISTRY;
    ITLDManager public immutable TLD_MANAGER;
    IPriceOracle public immutable PRICE_ORACLE;
    IReverseRegistrar public immutable REVERSE_REGISTRAR;

    /// @dev commitment hash => timestamp when it was submitted
    mapping(bytes32 => uint256) public override commitments;

    constructor(
        IRegistry _registry,
        ITLDManager _tldManager,
        IPriceOracle _priceOracle,
        IReverseRegistrar _reverseRegistrar,
        address initialOwner
    ) Ownable(initialOwner) {
        REGISTRY = _registry;
        TLD_MANAGER = _tldManager;
        PRICE_ORACLE = _priceOracle;
        REVERSE_REGISTRAR = _reverseRegistrar;
    }

    // ---------------------------------------------------------------
    //                        COMMIT-REVEAL
    // ---------------------------------------------------------------

    /// @inheritdoc IRegistrarController
    function makeCommitment(RegisterRequest calldata req)
        external
        pure
        override
        returns (bytes32)
    {
        bytes memory encoded = abi.encode(
            req.name,
            req.tld,
            req.owner,
            req.duration,
            req.secret,
            req.resolver,
            req.resolverData,
            req.reverseRecord
        );
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(encoded);
    }

    /// @inheritdoc IRegistrarController
    function commit(bytes32 commitment) external override whenNotPaused {
        if (commitments[commitment] != 0) revert CommitmentAlreadyExists(commitment);
        commitments[commitment] = block.timestamp;
    }

    // ---------------------------------------------------------------
    //                        REGISTRATION
    // ---------------------------------------------------------------

    /// @inheritdoc IRegistrarController
    function available(
        string calldata name,
        bytes32 tld
    ) external view override returns (bool) {
        if (!valid(name)) return false;
        ITLDManager.Tld memory tldData = _getTldOrRevert(tld);
        uint256 tokenId = uint256(keccak256(bytes(name)));
        return ITLDRegistrar(tldData.registrar).available(tokenId);
    }

    /// @inheritdoc IRegistrarController
    function valid(string calldata name) public pure override returns (bool) {
        uint256 len = bytes(name).length;
        if (len < MIN_NAME_LENGTH) return false;
        // Only allow lowercase ASCII letters, digits, and hyphens; no leading/trailing hyphen
        bytes memory b = bytes(name);
        if (b[0] == "-" || b[len - 1] == "-") return false;
        for (uint256 i = 0; i < len; i++) {
            bytes1 c = b[i];
            bool isLower = c >= 0x61 && c <= 0x7a; // a-z
            bool isDigit = c >= 0x30 && c <= 0x39; // 0-9
            bool isHyphen = c == 0x2d;             // -
            if (!isLower && !isDigit && !isHyphen) return false;
        }
        return true;
    }

    /// @inheritdoc IRegistrarController
    function minNameLength() external pure override returns (uint256) {
        return MIN_NAME_LENGTH;
    }

    /// @inheritdoc IRegistrarController
    function rentPrice(
        string calldata name,
        bytes32, /* tld — included for future per-TLD pricing; flat for now */
        uint256 duration
    ) external view override returns (uint256 base, uint256 premium) {
        IPriceOracle.Price memory p = PRICE_ORACLE.price(name, 0, duration);
        return (p.base, p.premium);
    }

    /// @inheritdoc IRegistrarController
    function register(RegisterRequest calldata req)
        external
        payable
        override
        whenNotPaused
    {
        // 1. Validate name and TLD
        if (!valid(req.name)) revert InvalidName(req.name);
        ITLDManager.Tld memory tldData = _getTldOrRevert(req.tld);
        if (!tldData.active) revert TLDNotActive(req.tld);

        // 2. Verify and consume commitment
        bytes32 commitment = this.makeCommitment(req);
        _validateAndConsumeCommitment(commitment);

        // 3. Check availability
        uint256 tokenId = uint256(keccak256(bytes(req.name)));
        ITLDRegistrar registrar = ITLDRegistrar(tldData.registrar);
        if (!registrar.available(tokenId)) revert NameUnavailable(req.name, req.tld);

        // 4. Verify payment
        IPriceOracle.Price memory p = PRICE_ORACLE.price(req.name, 0, req.duration);
        uint256 total = p.base + p.premium;
        if (msg.value < total) revert InsufficientValue(total, msg.value);

        // 5. Register: mint to this contract temporarily so we can set resolver data atomically
        registrar.register(tokenId, address(this), req.duration);

        // 6. Set resolver if provided
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 nameNode = keccak256(abi.encodePacked(registrar.baseNode(), bytes32(tokenId)));
        if (req.resolver != address(0)) {
            REGISTRY.setResolver(nameNode, req.resolver);
            for (uint256 i = 0; i < req.resolverData.length; i++) {
                (bool ok, bytes memory ret) = req.resolver.call(req.resolverData[i]);
                if (!ok) revert ResolverCallFailed(i, ret);
            }
        } else if (req.resolverData.length > 0) {
            revert ResolverRequired();
        }

        // 7. Transfer NFT to actual owner — triggers _update hook which syncs registry
        IERC721(address(registrar)).safeTransferFrom(address(this), req.owner, tokenId);

        // 8. Optionally set reverse record
        if (req.reverseRecord) {
            string memory tldLabel = TLD_MANAGER.getTld(req.tld).label;
            string memory fullName = string.concat(req.name, ".", tldLabel);
            address resolver = req.resolver != address(0) ? req.resolver : REVERSE_REGISTRAR.defaultResolver();
            REVERSE_REGISTRAR.setNameForAddr(req.owner, req.owner, resolver, fullName);
        }

        // 9. Refund excess ETH
        if (msg.value > total) {
            (bool sent,) = payable(msg.sender).call{ value: msg.value - total }("");
            require(sent, "refund failed");
        }

        emit NameRegistered(
            req.name,
            req.tld,
            bytes32(tokenId),
            req.owner,
            p.base,
            p.premium,
            block.timestamp + req.duration
        );
    }

    /// @inheritdoc IRegistrarController
    function renew(
        string calldata name,
        bytes32 tld,
        uint256 duration
    ) external payable override whenNotPaused {
        ITLDManager.Tld memory tldData = _getTldOrRevert(tld);

        IPriceOracle.Price memory p = PRICE_ORACLE.price(name, 0, duration);
        uint256 total = p.base + p.premium;
        if (msg.value < total) revert InsufficientValue(total, msg.value);

        uint256 tokenId = uint256(keccak256(bytes(name)));
        uint256 expires = ITLDRegistrar(tldData.registrar).renew(tokenId, duration);

        if (msg.value > total) {
            (bool sent,) = payable(msg.sender).call{ value: msg.value - total }("");
            require(sent, "refund failed");
        }

        emit NameRenewed(name, tld, bytes32(tokenId), total, expires);
    }

    // ---------------------------------------------------------------
    //                      ADMIN / PROTOCOL
    // ---------------------------------------------------------------

    /// @inheritdoc IRegistrarController
    function withdraw(address to) external override onlyOwner {
        uint256 bal = address(this).balance;
        emit FeesWithdrawn(to, bal);
        (bool sent,) = payable(to).call{ value: bal }("");
        require(sent, "withdraw failed");
    }

    /// @inheritdoc IRegistrarController
    function pause() external override onlyOwner {
        _pause();
    }

    /// @inheritdoc IRegistrarController
    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @inheritdoc IRegistrarController
    function paused() public view override(IRegistrarController, Pausable) returns (bool) {
        return super.paused();
    }

    // ---------------------------------------------------------------
    //                          INTERNAL
    // ---------------------------------------------------------------

    function _validateAndConsumeCommitment(bytes32 commitment) internal {
        uint256 ts = commitments[commitment];
        if (ts == 0) revert CommitmentNotFound(commitment);
        if (block.timestamp < ts + MIN_COMMITMENT_AGE) revert CommitmentTooNew(commitment);
        if (block.timestamp > ts + MAX_COMMITMENT_AGE) revert CommitmentTooOld(commitment);
        delete commitments[commitment];
    }

    function _getTldOrRevert(bytes32 tld) internal view returns (ITLDManager.Tld memory) {
        try TLD_MANAGER.getTld(tld) returns (ITLDManager.Tld memory data) {
            return data;
        } catch {
            revert TLDNotActive(tld);
        }
    }

    /// @dev Required by IERC721Receiver so safeTransferFrom doesn't revert.
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
