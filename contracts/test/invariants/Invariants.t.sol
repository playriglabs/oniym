// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, StdInvariant } from "forge-std/Test.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Registry } from "../../src/Registry.sol";
import { TLDManager } from "../../src/TLDManager.sol";
import { TLDRegistrar } from "../../src/TLDRegistrar.sol";
import { RegistrarController } from "../../src/RegistrarController.sol";
import { PriceOracle } from "../../src/PriceOracle.sol";
import { ProtocolHandler } from "./ProtocolHandler.sol";

contract MockFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 3_000_00000000, block.timestamp, block.timestamp, 1);
    }
}

/// @title Protocol Invariant Tests
/// @notice Tests properties that must hold across any sequence of protocol actions.
///
///   INV-1  ETH accounting      ctrl.balance == totalPaid − totalWithdrawn
///   INV-2  Expiry recorded     nameExpires matches ghost after register/renew
///   INV-3  Grace protection    names in grace period cannot be re-registered
///   INV-4  NFT-registry sync   registry owner matches NFT owner for live names
contract ProtocolInvariantTest is StdInvariant, Test {
    Registry reg;
    TLDManager mgr;
    TLDRegistrar registrar;
    PriceOracle oracle;
    RegistrarController ctrl;
    ProtocolHandler handler;

    address protocolOwner = makeAddr("protocol");
    bytes32 constant ROOT = bytes32(0);
    bytes32 tldNode;

    function setUp() public {
        reg = new Registry();
        mgr = new TLDManager(reg, protocolOwner);
        oracle = new PriceOracle(address(new MockFeed()), 1 hours, 5_00000000, protocolOwner);
        ctrl = new RegistrarController(reg, mgr, oracle, protocolOwner);

        reg.setOwner(ROOT, address(mgr));

        tldNode = keccak256(abi.encodePacked(ROOT, keccak256(bytes("id"))));
        registrar = new TLDRegistrar(reg, tldNode, "id", address(mgr));

        vm.prank(protocolOwner);
        mgr.addTld("id", address(registrar));

        vm.prank(address(mgr));
        registrar.addController(address(ctrl));

        handler = new ProtocolHandler(reg, registrar, ctrl, tldNode, protocolOwner);

        // Only fuzz through the handler — no direct contract calls
        targetContract(address(handler));
    }

    // ---------------------------------------------------------------
    //             INV-1: ETH ACCOUNTING
    // ---------------------------------------------------------------

    /// @dev Every wei that enters the controller came from a registration or renewal.
    ///      Every wei that left went through withdraw(). No other paths exist.
    function invariant_controller_eth_accounting() public view {
        assertEq(
            address(ctrl).balance,
            handler.ghost_totalPaid() - handler.ghost_totalWithdrawn(),
            "INV-1: controller balance != totalPaid - totalWithdrawn"
        );
    }

    // ---------------------------------------------------------------
    //             INV-2: EXPIRY RECORDED CORRECTLY
    // ---------------------------------------------------------------

    /// @dev After each register/renew the handler records the expected expiry.
    ///      The on-chain expiry must always match — only register() and renew()
    ///      touch expiry, so no other path can change it between handler calls.
    function invariant_expiry_matches_ghost() public view {
        string[5] memory names = handler.names();
        for (uint256 i = 0; i < names.length; i++) {
            uint256 tokenId = uint256(keccak256(bytes(names[i])));
            uint256 ghostExp = handler.ghost_lastExpiry(tokenId);
            if (ghostExp == 0) continue; // never registered

            assertEq(
                registrar.nameExpires(tokenId),
                ghostExp,
                "INV-2: on-chain expiry does not match ghost"
            );
        }
    }

    // ---------------------------------------------------------------
    //             INV-3: GRACE PERIOD PROTECTION
    // ---------------------------------------------------------------

    /// @dev Names within the 90-day grace window after expiry must NOT be
    ///      available for re-registration. Violating this would allow
    ///      squatting on names that just expired.
    function invariant_grace_period_protects_names() public view {
        string[5] memory names = handler.names();
        for (uint256 i = 0; i < names.length; i++) {
            uint256 tokenId = uint256(keccak256(bytes(names[i])));
            uint256 expires = registrar.nameExpires(tokenId);
            if (expires == 0) continue;

            bool inGracePeriod =
                block.timestamp > expires
                    && block.timestamp <= expires + registrar.gracePeriod();

            if (inGracePeriod) {
                assertFalse(
                    registrar.available(tokenId),
                    "INV-3: name available during grace period"
                );
            }
        }
    }

    // ---------------------------------------------------------------
    //             INV-4: NFT-REGISTRY OWNERSHIP SYNC
    // ---------------------------------------------------------------

    /// @dev For any live (non-expired) registered name, the Registry owner
    ///      must equal the ERC-721 owner. TLDRegistrar._update() syncs the
    ///      registry on every transfer, so these should never diverge.
    function invariant_nft_registry_ownership_sync() public view {
        string[5] memory names = handler.names();
        for (uint256 i = 0; i < names.length; i++) {
            uint256 tokenId = uint256(keccak256(bytes(names[i])));
            if (!handler.ghost_everRegistered(tokenId)) continue;

            uint256 expires = registrar.nameExpires(tokenId);
            // Only check live names — expired names have registry owner = address(0)
            if (block.timestamp >= expires) continue;

            address nftOwner = IERC721(address(registrar)).ownerOf(tokenId);
            bytes32 nameNode = keccak256(abi.encodePacked(tldNode, bytes32(tokenId)));
            address regOwner = reg.ownerOf(nameNode);

            assertEq(
                regOwner,
                nftOwner,
                "INV-4: registry owner != NFT owner for live name"
            );
        }
    }

    // ---------------------------------------------------------------
    //             INV-5: CONTROLLER NEVER HOLDS NAMES
    // ---------------------------------------------------------------

    /// @dev The RegistrarController temporarily holds an NFT during registration
    ///      to set resolver data, then immediately transfers to the buyer.
    ///      After any sequence of completed actions, the controller must hold
    ///      no NFTs.
    function invariant_controller_holds_no_nfts() public view {
        assertEq(
            IERC721(address(registrar)).balanceOf(address(ctrl)),
            0,
            "INV-5: controller should not hold any NFTs after registration"
        );
    }
}
