/* eslint-disable @typescript-eslint/require-await */
/* eslint-disable @typescript-eslint/no-redundant-type-constituents */
import type { Hex } from "viem";
import { namehash as _namehash, labelhash as _labelhash, makeNode as _makeNode } from "./namehash";

// SLIP-0044 coin types for supported chains
export const COIN_TYPES = {
    btc: 0,
    eth: 60,
    sol: 501,
    sui: 784,
    bnb: 714,
} as const satisfies Record<string, number>;

export type SupportedChain = keyof typeof COIN_TYPES;

/** Maximum number of TLDs the protocol will ever register (enforced on-chain in ITLDManager) */
export const MAX_TLD_COUNT = 65;

/** Maximum character length of a TLD label, excluding the leading dot */
export const MAX_TLD_LENGTH = 5;

/**
 * Protocol-managed TLDs — web-style, chain-neutral (see ADR-007).
 *
 * Any TLD name resolves to ALL supported chain addresses. TLD choice is
 * purely about identity preference, not chain restriction.
 *
 * Capped at MAX_TLD_COUNT (65). Each label is ≤ MAX_TLD_LENGTH (5) chars.
 */
export const SUPPORTED_TLDS = [
    // General identity
    "id",
    "one",
    "me",
    "co",
    // Web3 / tech signals
    "xyz",
    "web3",
    "io",
    "pro",
    "app",
    "dev",
    "onm",
    "go",
    // Crypto culture
    "ape",
    "fud",
    "hodl",
    "fomo",
    "moon",
    "rekt",
    "wagmi",
    "ngmi",
    "degen",
    "whale",
    "buidl",
    "dyor",
    "pump",
    "alpha",
    "safu",
    "l2",
    "gm",
    "lfg",
    "ser",
    "fren",
    "goat",
    "cope",
    "pepe",
    "wen",
    // Finance / DeFi
    "mint",
    "bear",
    "gas",
    "dao",
    "ath",
    "dex",
    "cex",
    "burn",
    "node",
    "swap",
    "yield",
    "bag",
    "bags",
    "seed",
    "drop",
    "stake",
    "pool",
    "wrap",
    "farm",
    "shill",
    // Misc
    "xxx",
    "regs",
    "main",
    "test",
    "exit",
    "fair",
    "guh",
    "bots",
    "keys",
] as const;
export type SupportedTLD = (typeof SUPPORTED_TLDS)[number];

export interface TLDInfo {
    /** Human-readable label without leading dot (e.g. "eth") */
    label: SupportedTLD | string;
    /** namehash of the label */
    node: Hex;
    /** Whether new registrations are currently open */
    active: boolean;
}

/**
 * Multichain addresses keyed by chain name.
 * Only chains that have a record set on-chain are present.
 */
export type MultiChainAddresses = Partial<Record<SupportedChain, string>>;

export interface OniymConfig {
    /** Indexer API base URL for fast reads. Falls back to direct RPC if omitted. */
    indexerUrl?: string;
    /** Base RPC URL for trustless fallback reads. */
    rpcUrl?: string;
}

/**
 * Oniym SDK — multichain naming service client.
 *
 * Inspired by the Clusters SDK: a simple, chain-agnostic API for
 * name ↔ address resolution across ETH, SOL, BTC, SUI, and Base.
 *
 * @example
 * ```ts
 * import { Oniym } from "@oniym/sdk";
 *
 * const oniym = new Oniym();
 *
 * // Reverse: address → primary name (like clusters.getName)
 * const name = await oniym.getName("0x123...");           // "kyy.id"
 *
 * // Forward: name → address on a specific chain
 * const addr = await oniym.getAddress("kyy.id", "sol");   // "..."
 *
 * // All addresses for a name (multichain bundle)
 * const all = await oniym.getAddresses("kyy.id");
 * // { eth: "0x...", sol: "...", btc: "...", bnb: "..." }
 * ```
 */
export class Oniym {
    readonly config: OniymConfig;

    constructor(config: OniymConfig = {}) {
        this.config = config;
    }

    // ---------------------------------------------------------------
    //                     REVERSE RESOLUTION
    // ---------------------------------------------------------------

    /**
     * Resolve an address to its primary name across all protocol TLDs.
     * Equivalent to `clusters.getName(address)`.
     *
     * Returns the first verified reverse record found, or `null` if none.
     * Verification: forward-resolves the returned name and confirms address match
     * (Reverse + Forward verification — see IReverseRegistrar).
     *
     * @param address EVM address (0x-prefixed) or chain-native address string
     * @returns Full name with TLD (e.g. "kyy.id") or null
     */
    async getName(address: string): Promise<string | null> {
        // TODO: query indexer API / RPC once contracts are deployed
        void address;
        return null;
    }

    // ---------------------------------------------------------------
    //                     FORWARD RESOLUTION
    // ---------------------------------------------------------------

    /**
     * Resolve a name to an address on a specific chain.
     *
     * @param name  Full name with TLD (e.g. "kyy.id")
     * @param chain Target chain key (e.g. "eth", "sol", "btc")
     * @returns Chain-native address string, or null if no record is set
     */
    async getAddress(name: string, chain: SupportedChain): Promise<string | null> {
        // TODO: query indexer API / RPC once contracts are deployed
        void name;
        void chain;
        return null;
    }

    /**
     * Resolve a name to all registered chain addresses at once.
     *
     * @param name Full name with TLD (e.g. "kyy.id")
     * @returns Map of chain → address for every chain that has a record set
     */
    async getAddresses(name: string): Promise<MultiChainAddresses> {
        // TODO: query indexer API / RPC once contracts are deployed
        void name;
        return {};
    }

    // ---------------------------------------------------------------
    //                         TLD DISCOVERY
    // ---------------------------------------------------------------

    /**
     * List all active TLDs offered by the protocol.
     *
     * When contracts are deployed this reads from ITLDManager.listTLDs().
     * Until then it returns the static launch set.
     *
     * @returns Array of TLD metadata objects
     */
    async getTLDs(): Promise<TLDInfo[]> {
        // TODO: read from ITLDManager contract when deployed
        return SUPPORTED_TLDS.map((label) => ({
            label,
            node: _namehash(label),
            active: true,
        }));
    }

    // ---------------------------------------------------------------
    //                           WRITES
    // ---------------------------------------------------------------

    /**
     * Register a name under a specific TLD.
     *
     * Handles the full commit-reveal flow: commits, waits for MIN_COMMITMENT_AGE,
     * then reveals. Requires a connected wallet client.
     *
     * @param name     Label only, no TLD (e.g. "kyy")
     * @param tld      TLD label (e.g. "id", "one", "xyz")
     * @param duration Registration duration in seconds
     * @param owner    Owner address to receive the name NFT
     * @returns Transaction hash of the register() call
     */
    async register(
        name: string,
        tld: SupportedTLD | string,
        duration: number,
        owner: string,
    ): Promise<string> {
        // TODO: implement commit-reveal flow via IRegistrarController once deployed
        void name;
        void tld;
        void duration;
        void owner;
        throw new Error("register() not yet implemented — contracts not deployed");
    }

    /**
     * Set an address for a specific chain on an existing name.
     *
     * @param name    Full name with TLD (e.g. "kyy.id")
     * @param chain   Target chain key (e.g. "sol")
     * @param address Chain-native address to store
     * @returns Transaction hash
     */
    async setAddress(name: string, chain: SupportedChain, address: string): Promise<string> {
        // TODO: implement via Resolver.setAddr() once deployed
        void name;
        void chain;
        void address;
        throw new Error("setAddress() not yet implemented — contracts not deployed");
    }

    // ---------------------------------------------------------------
    //                          UTILITIES
    // ---------------------------------------------------------------

    /** ENSIP-1 namehash for a full name (e.g. "kyy.id") */
    namehash(name: string): Hex {
        return _namehash(name);
    }

    /** keccak256 of a single label (e.g. "kyy") */
    labelhash(label: string): Hex {
        return _labelhash(label);
    }

    /** Compute a subdomain node from a parent node + label */
    makeNode(parentNode: Hex, label: string): Hex {
        return _makeNode(parentNode, label);
    }

    /**
     * Parse a full name into its label and TLD.
     *
     * @example parseName("kyy.id") // { label: "kyy", tld: "id" }
     * @returns null if the name is not a valid two-part name
     */
    parseName(name: string): { label: string; tld: string } | null {
        const dot = name.indexOf(".");
        if (dot <= 0 || dot === name.length - 1) return null;
        const label = name.slice(0, dot);
        const tld = name.slice(dot + 1);
        if (tld.includes(".")) return null; // sub-names not supported in v1
        return { label, tld };
    }

    /**
     * SLIP-0044 coin type for a supported chain key.
     *
     * @example coinTypeFor("sol") // 501
     */
    coinTypeFor(chain: SupportedChain): number {
        return COIN_TYPES[chain];
    }
}
