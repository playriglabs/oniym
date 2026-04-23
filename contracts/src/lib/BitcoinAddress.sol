// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title BitcoinAddress
/// @notice Validates Bitcoin address format for Legacy (P2PKH/P2SH), SegWit (P2WPKH/P2WSH),
///         and Taproot (P2TR) address types.
/// @dev Validates UTF-8 encoded address strings passed as bytes. Checks character set, prefix,
///      and length only — not cryptographic integrity (no Base58Check double-SHA256, no Bech32
///      checksum). Intended for coinType 0 (SLIP-0044 BTC) in the Resolver setAddr flow.
library BitcoinAddress {
    error InvalidBitcoinAddress();

    // Shortest possible valid Bitcoin address (P2PKH with leading zero bytes)
    uint256 private constant MIN_LEN = 25;
    // Longest possible valid Bitcoin address (P2WSH / P2TR, 62 Bech32 chars)
    uint256 private constant MAX_LEN = 62;
    // Legacy P2PKH and P2SH addresses are Base58Check-encoded, max 34 chars
    uint256 private constant LEGACY_MAX_LEN = 34;
    // Native SegWit P2WPKH: bc + 1 + q + 32 data + 6 checksum = 42 chars
    uint256 private constant P2WPKH_LEN = 42;

    /// @notice Validates a Bitcoin mainnet address encoded as UTF-8 bytes.
    /// @param addr The address bytes (UTF-8 string, e.g. bytes("1A1zP1..."))
    function validate(bytes memory addr) internal pure {
        uint256 len = addr.length;
        if (len < MIN_LEN || len > MAX_LEN) revert InvalidBitcoinAddress();

        uint8 first = uint8(addr[0]);

        if (first == 0x31 || first == 0x33) {
            // '1' = P2PKH, '3' = P2SH — Base58Check encoded
            _validateBase58(addr, len);
        } else if (
            first == 0x62 && // 'b'
            uint8(addr[1]) == 0x63 && // 'c'
            uint8(addr[2]) == 0x31 // '1' (separator)
        ) {
            // 'bc1' — native SegWit or Taproot (Bech32 / Bech32m)
            _validateBech32(addr, len);
        } else {
            revert InvalidBitcoinAddress();
        }
    }

    /// @dev Validates a Base58 character set and length for legacy address types.
    function _validateBase58(bytes memory addr, uint256 len) private pure {
        if (len > LEGACY_MAX_LEN) revert InvalidBitcoinAddress();
        for (uint256 i; i < len; ++i) {
            if (!_isBase58Char(uint8(addr[i]))) revert InvalidBitcoinAddress();
        }
    }

    /// @dev Validates the Bech32 data portion of a native SegWit or Taproot address.
    ///      The HRP ('bc') and separator ('1') at positions 0-2 are already confirmed
    ///      by the caller. Validation starts at position 3 (the witness version char).
    function _validateBech32(bytes memory addr, uint256 len) private pure {
        // P2WPKH = 42, P2WSH = 62, P2TR = 62
        if (len != P2WPKH_LEN && len != MAX_LEN) revert InvalidBitcoinAddress();

        uint8 version = uint8(addr[3]);
        // 'q' (0x71) = witness v0 (P2WPKH at 42, P2WSH at 62)
        // 'p' (0x70) = witness v1 / Taproot (only valid at 62 chars)
        bool validVersion = version == 0x71 || (version == 0x70 && len == MAX_LEN);
        if (!validVersion) revert InvalidBitcoinAddress();

        for (uint256 i = 3; i < len; ++i) {
            if (!_isBech32Char(uint8(addr[i]))) revert InvalidBitcoinAddress();
        }
    }

    /// @dev Returns true if `c` is in the Base58 alphabet.
    ///      Excluded: '0' (0x30), 'I' (0x49), 'O' (0x4F), 'l' (0x6C).
    function _isBase58Char(uint8 c) private pure returns (bool) {
        return
            (c >= 0x31 && c <= 0x39) || // 1–9
            (c >= 0x41 && c <= 0x48) || // A–H  (skips I)
            (c >= 0x4A && c <= 0x4E) || // J–N  (skips O)
            (c >= 0x50 && c <= 0x5A) || // P–Z
            (c >= 0x61 && c <= 0x6B) || // a–k  (skips l)
            (c >= 0x6D && c <= 0x7A); // m–z
    }

    /// @dev Returns true if `c` is in the Bech32 data charset.
    ///      Charset: qpzry9x8gf2tvdw0s3jn54khce6mua7l
    ///      Excluded lowercase: 'b' (0x62), 'i' (0x69), 'o' (0x6F).
    ///      Excluded digit:     '1' (0x31) — used only as the HRP separator.
    function _isBech32Char(uint8 c) private pure returns (bool) {
        return
            (c >= 0x30 && c <= 0x39 && c != 0x31) || // 0, 2–9  (not '1')
            (c >= 0x61 && c <= 0x7A && c != 0x62 && c != 0x69 && c != 0x6F); // a–z except b,i,o
    }
}
