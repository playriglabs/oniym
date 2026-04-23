// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { BitcoinAddress } from "../src/lib/BitcoinAddress.sol";

/// @title BitcoinAddressTest
/// @notice Unit tests for the BitcoinAddress validation library.
///         Covers P2PKH, P2SH, P2WPKH, P2WSH, and P2TR address formats.
contract BitcoinAddressTest is Test {
    /// @dev Wrapper so vm.expectRevert can catch reverts from the internal library.
    function callValidate(bytes memory addr) external pure {
        BitcoinAddress.validate(addr);
    }

    // ---------------------------------------------------------------
    //                     VALID ADDRESSES
    // ---------------------------------------------------------------

    function test_validP2PKH() public pure {
        // Genesis coinbase output address (34 chars)
        BitcoinAddress.validate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv7Divfna"));
    }

    function test_validP2SH() public pure {
        BitcoinAddress.validate(bytes("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"));
    }

    function test_validP2WPKH() public pure {
        // Native SegWit P2WPKH — always 42 chars
        BitcoinAddress.validate(bytes("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_validP2WSH() public pure {
        // Native SegWit P2WSH — always 62 chars (bc1q + 58 data chars)
        BitcoinAddress.validate(
            bytes("bc1qaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        );
    }

    function test_validTaproot() public pure {
        // Taproot P2TR — Bech32m, always 62 chars, version char 'p'
        BitcoinAddress.validate(
            bytes("bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297")
        );
    }

    // ---------------------------------------------------------------
    //                     INVALID ADDRESSES
    // ---------------------------------------------------------------

    function test_revertOnEmpty() public {
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes(""));
    }

    function test_revertOnTooShort() public {
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1BpEi6DfD"));
    }

    function test_revertOnTooLong() public {
        // 63 chars — exceeds the 62-char max for any Bitcoin address type
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg32977"));
    }

    function test_revertOnInvalidPrefix() public {
        // Starts with '2' — not a valid Bitcoin address prefix
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("2invalidprefix1234567890123456789"));
    }

    function test_revertOnBase58WithZero() public {
        // '0' (zero) is excluded from the Base58 alphabet
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv70ivfna"));
    }

    function test_revertOnBase58WithCapI() public {
        // 'I' (uppercase) is excluded from the Base58 alphabet
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv7IivfnZ"));
    }

    function test_revertOnBase58WithCapO() public {
        // 'O' (uppercase) is excluded from the Base58 alphabet
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv7OivfnZ"));
    }

    function test_revertOnBase58WithLowercaseL() public {
        // 'l' (lowercase L) is excluded from the Base58 alphabet
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv7livfnZ"));
    }

    function test_revertOnLegacyTooLong() public {
        // 37 chars — exceeds the 34-char max for Base58 Bitcoin addresses
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("1A1zP1eP5QGefi2DMPTfTL5SLmv7Divfnaaa"));
    }

    function test_revertOnBech32InvalidVersion() public {
        // 'z' is not a valid witness version character ('q' or 'p' are the only valid ones)
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1zar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_revertOnBech32WrongLength() public {
        // 34-char bc1q address — not 42 or 62 chars
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1qar0srrr7xfkvy5l643lydnw9re59gt"));
    }

    function test_revertOnBech32WithExcludedChar_b() public {
        // 'b' is excluded from the Bech32 data charset
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1qar0srrr7bfkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_revertOnBech32WithExcludedChar_i() public {
        // 'i' is excluded from the Bech32 data charset
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1qar0srrr7ifkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_revertOnBech32WithExcludedChar_o() public {
        // 'o' is excluded from the Bech32 data charset
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1qar0srrr7ofkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_revertOnBech32WithSeparatorInData() public {
        // '1' is the HRP separator and is excluded from the Bech32 data charset
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1qar1srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    }

    function test_revertOnTaprootAtWrongLength() public {
        // 'p' (witness v1 / Taproot) is only valid at 62 chars, not 42
        vm.expectRevert(BitcoinAddress.InvalidBitcoinAddress.selector);
        this.callValidate(bytes("bc1par0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    }
}
