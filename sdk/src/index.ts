/**
 * @oniym/sdk
 *
 * TypeScript SDK for Oniym — a multichain naming service.
 * One name, every chain.
 *
 * @example
 * ```ts
 * import { Oniym } from "@oniym/sdk";
 *
 * const oniym = new Oniym();
 * const name = await oniym.getName("0x123...");     // "kyy.eth"
 * const addr = await oniym.getAddress("kyy.eth", "sol"); // "..."
 * ```
 *
 * @packageDocumentation
 */

export { Oniym, COIN_TYPES, SUPPORTED_TLDS, MAX_TLD_COUNT, MAX_TLD_LENGTH } from "./oniym";
export type {
    OniymConfig,
    MultiChainAddresses,
    TLDInfo,
    SupportedChain,
    SupportedTLD,
} from "./oniym";

export { namehash, makeNode, labelhash } from "./namehash";
