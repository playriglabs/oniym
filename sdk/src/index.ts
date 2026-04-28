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
 * const oniym = new Oniym({ indexerUrl: "https://api.oniym.xyz" });
 *
 * const name = await oniym.getName("0x123...");
 * const addr = await oniym.getAddress("kyy.web3", "sol");
 * const all  = await oniym.getAddresses("kyy.web3");
 * ```
 *
 * @packageDocumentation
 */

export { Oniym, COIN_TYPES, MAX_TLD_COUNT, MAX_TLD_LENGTH } from "./oniym";
export { SUPPORTED_TLDS } from "./tlds";

export type {
    OniymConfig,
    MultiChainAddresses,
    TLDInfo,
    SupportedChain,
    SupportedTLD,
    ResolveResult,
    LookupResult,
    OwnedName,
    NamesResult,
    RegisterOptions,
} from "./oniym";

export { namehash, makeNode, labelhash } from "./namehash";

export {
    CHAIN_IDS,
    CONTRACT_ADDRESSES,
    registrarControllerAbi,
    publicResolverAbi,
    registryAbi,
} from "./contracts";

export type { ChainId } from "./contracts";
