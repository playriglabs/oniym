import { concat, keccak256, stringToBytes, type Hex } from "viem";

/**
 * ENSIP-1 compatible namehash algorithm.
 *
 * MUST produce identical output to {@link contracts/src/lib/Namehash.sol}.
 *
 * @param name Pre-normalized dot-separated name (lowercase, UTS-46)
 * @returns 32-byte namehash as 0x-prefixed hex
 *
 * @example
 * namehash('')            // 0x000...000
 * namehash('oniym')       // keccak256(0x0 ‖ keccak256('oniym'))
 * namehash('kyy.oniym')   // keccak256(namehash('oniym') ‖ keccak256('kyy'))
 */
export function namehash(name: string): Hex {
    let node: Hex = `0x${"00".repeat(32)}`;
    if (name.length === 0) return node;

    const labels = name.split(".").reverse();
    for (const label of labels) {
        const labelHash = keccak256(stringToBytes(label));
        node = keccak256(concat([node, labelHash]));
    }
    return node;
}

/**
 * Compute a subdomain namehash from parent node and label.
 *
 * Equivalent to {@link Namehash.makeNode} in Solidity.
 */
export function makeNode(parentNode: Hex, label: string): Hex {
    const labelHash = keccak256(stringToBytes(label));
    return keccak256(concat([parentNode, labelHash]));
}

/**
 * Hash a single label (keccak256 of its UTF-8 bytes).
 */
export function labelhash(label: string): Hex {
    return keccak256(stringToBytes(label));
}
