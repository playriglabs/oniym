/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/no-redundant-type-constituents */
import {
    createPublicClient,
    http,
    toBytes,
    toHex,
    encodeFunctionData,
    type Hex,
    type Address,
    type Hash,
    type WalletClient,
} from "viem";
import { baseSepolia } from "viem/chains";
import type { Chain } from "viem";
import { namehash as _namehash, labelhash as _labelhash, makeNode as _makeNode } from "./namehash";
import {
    CHAIN_IDS,
    CONTRACT_ADDRESSES,
    registrarControllerAbi,
    publicResolverAbi,
    priceOracleAbi,
    erc20Abi,
    registryAbi,
    type ChainId,
} from "./contracts";
import { SUPPORTED_TLDS } from "./tlds";

// ---------------------------------------------------------------
//                          CONSTANTS
// ---------------------------------------------------------------

export const COIN_TYPES = {
    btc: 0,
    eth: 60,
    sol: 501,
    sui: 784,
    bnb: 714,
} as const satisfies Record<string, number>;

export type SupportedChain = keyof typeof COIN_TYPES;

export const MAX_TLD_COUNT = 65;
export const MAX_TLD_LENGTH = 5;

export type SupportedTLD = (typeof SUPPORTED_TLDS)[number];

// ---------------------------------------------------------------
//                            TYPES
// ---------------------------------------------------------------

export interface TLDInfo {
    label: SupportedTLD | string;
    node: Hex;
    active: boolean;
}

export type MultiChainAddresses = Partial<Record<SupportedChain, string>>;

export interface ResolveResult {
    name: string;
    node: Hex;
    owner: string;
    resolver: string | null;
    expiresAt: string;
    expired: boolean;
    addresses: Record<string, string>;
    texts: Record<string, string>;
    contenthash: string | null;
}

export interface LookupResult {
    address: string;
    name: string | null;
    reverseNode: string;
    verified: boolean;
}

export interface OwnedName {
    name: string;
    node: string;
    expiresAt: string;
    expired: boolean;
}

export interface NamesResult {
    address: string;
    names: OwnedName[];
}

export interface RegisterOptions {
    name: string;
    tld: SupportedTLD | string;
    duration?: number;
    owner?: Address;
    resolver?: Address;
    reverseRecord?: boolean;
    addresses?: Partial<Record<SupportedChain, string>>;
    texts?: Record<string, string>;
    paymentToken?: "eth" | "usdc";
    onCommit?: (hash: Hash) => void;
    onWaiting?: (remainingMs: number) => void;
}

export interface RenewOptions {
    name: string;
    tld: SupportedTLD | string;
    duration?: number;
    paymentToken?: "eth" | "usdc";
}

export interface OniymConfig {
    indexerUrl?: string;
    rpcUrl?: string;
    chainId?: ChainId;
}

// ---------------------------------------------------------------
//                         ONIYM CLASS
// ---------------------------------------------------------------

export class Oniym {
    readonly config: OniymConfig;
    private readonly chainId: ChainId;
    private readonly addresses: (typeof CONTRACT_ADDRESSES)[ChainId];
    private readonly chain: Chain;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    private readonly publicClient: ReturnType<typeof createPublicClient<any, Chain>>;

    constructor(config: OniymConfig = {}) {
        this.config = config;
        this.chainId = config.chainId ?? CHAIN_IDS.baseSepolia;
        this.addresses = CONTRACT_ADDRESSES[this.chainId];
        this.chain = baseSepolia;
        this.publicClient = createPublicClient({
            chain: this.chain,
            transport: http(config.rpcUrl),
        });
    }

    // ---------------------------------------------------------------
    //                      INDEXER READS
    // ---------------------------------------------------------------

    async resolve(name: string): Promise<ResolveResult | null> {
        const url = this._indexerUrl(`/resolve/${encodeURIComponent(name)}`);
        const res = await fetch(url);
        if (res.status === 404) return null;
        if (!res.ok) throw new Error(`Resolve failed: ${res.status}`);
        return res.json() as Promise<ResolveResult>;
    }

    async getName(address: string): Promise<string | null> {
        const url = this._indexerUrl(`/lookup/${address}`);
        const res = await fetch(url);
        if (res.status === 404) return null;
        if (!res.ok) throw new Error(`Lookup failed: ${res.status}`);
        const data = (await res.json()) as LookupResult;
        return data.name;
    }

    async getAddress(name: string, chain: SupportedChain): Promise<string | null> {
        const result = await this.resolve(name);
        if (!result) return null;
        const coinType = COIN_TYPES[chain].toString();
        return result.addresses[coinType] ?? null;
    }

    async getNames(address: string): Promise<OwnedName[]> {
        const url = this._indexerUrl(`/names/${address}`);
        const res = await fetch(url);
        if (!res.ok) throw new Error(`getNames failed: ${res.status}`);
        const data = (await res.json()) as NamesResult;
        return data.names;
    }

    async getAddresses(name: string): Promise<MultiChainAddresses> {
        const result = await this.resolve(name);
        if (!result) return {};

        const out: MultiChainAddresses = {};
        for (const [chain, coinType] of Object.entries(COIN_TYPES) as [SupportedChain, number][]) {
            const addr = result.addresses[coinType.toString()];
            if (addr) out[chain] = addr;
        }
        return out;
    }

    // ---------------------------------------------------------------
    //                       RPC READS
    // ---------------------------------------------------------------

    async available(name: string, tld: string): Promise<boolean> {
        return this.publicClient.readContract({
            address: this.addresses.RegistrarController,
            abi: registrarControllerAbi,
            functionName: "available",
            args: [name, _namehash(tld)],
        });
    }

    async rentPrice(name: string, tld: string, duration: number): Promise<bigint> {
        const [base, premium] = await this.publicClient.readContract({
            address: this.addresses.RegistrarController,
            abi: registrarControllerAbi,
            functionName: "rentPrice",
            args: [name, _namehash(tld), BigInt(duration)],
        });
        return base + premium;
    }

    getTLDs(): TLDInfo[] {
        return SUPPORTED_TLDS.map((label) => ({
            label,
            node: _namehash(label),
            active: true,
        }));
    }

    // ---------------------------------------------------------------
    //                          WRITES
    // ---------------------------------------------------------------

    async register(options: RegisterOptions, walletClient: WalletClient): Promise<Hash> {
        const account = walletClient.account;
        if (!account) throw new Error("walletClient.account is required");

        const owner = options.owner ?? account.address;
        const resolver = options.resolver ?? this.addresses.PublicResolver;
        const duration = options.duration ?? 365 * 24 * 60 * 60;
        const tldNode = _namehash(options.tld);
        const nameNode = _makeNode(tldNode, options.name);
        const secret = toHex(crypto.getRandomValues(new Uint8Array(32)));

        const resolverData = this._buildResolverData(nameNode, options.addresses, options.texts);

        const req = {
            name: options.name,
            tld: tldNode,
            owner,
            duration: BigInt(duration),
            secret,
            resolver,
            resolverData,
            reverseRecord: options.reverseRecord ?? false,
        } as const;

        // 1. Commit
        const commitment = await this.publicClient.readContract({
            address: this.addresses.RegistrarController,
            abi: registrarControllerAbi,
            functionName: "makeCommitment",
            args: [req],
        });

        const commitHash = await walletClient.writeContract({
            address: this.addresses.RegistrarController,
            abi: registrarControllerAbi,
            functionName: "commit",
            args: [commitment],
            chain: this.chain,
            account,
        });
        options.onCommit?.(commitHash);

        // 2. Wait for MIN_COMMITMENT_AGE
        const minAge = await this.publicClient.readContract({
            address: this.addresses.RegistrarController,
            abi: registrarControllerAbi,
            functionName: "MIN_COMMITMENT_AGE",
        });

        const waitMs = (Number(minAge) + 5) * 1000;
        options.onWaiting?.(waitMs);
        await new Promise<void>((r) => setTimeout(r, waitMs));

        // 3. Register
        const useUsdc = options.paymentToken === "usdc";

        if (useUsdc) {
            const usdcAmount = await this._priceUsdc(options.name, duration);
            await walletClient.writeContract({
                address: this.addresses.USDC,
                abi: erc20Abi,
                functionName: "approve",
                args: [this.addresses.RegistrarController, usdcAmount],
                chain: this.chain,
                account,
            });
            return walletClient.writeContract({
                address: this.addresses.RegistrarController,
                abi: registrarControllerAbi,
                functionName: "register",
                args: [req, this.addresses.USDC],
                chain: this.chain,
                account,
            });
        } else {
            const total = await this.rentPrice(options.name, options.tld, duration);
            return walletClient.writeContract({
                address: this.addresses.RegistrarController,
                abi: registrarControllerAbi,
                functionName: "register",
                args: [req, "0x0000000000000000000000000000000000000000"],
                value: total,
                chain: this.chain,
                account,
            });
        }
    }

    async renew(options: RenewOptions, walletClient: WalletClient): Promise<Hash> {
        const account = walletClient.account;
        if (!account) throw new Error("walletClient.account is required");

        const tldNode = _namehash(options.tld);
        const duration = options.duration ?? 365 * 24 * 60 * 60;
        const useUsdc = options.paymentToken === "usdc";

        if (useUsdc) {
            const usdcAmount = await this._priceUsdc(options.name, duration);
            await walletClient.writeContract({
                address: this.addresses.USDC,
                abi: erc20Abi,
                functionName: "approve",
                args: [this.addresses.RegistrarController, usdcAmount],
                chain: this.chain,
                account,
            });
            return walletClient.writeContract({
                address: this.addresses.RegistrarController,
                abi: registrarControllerAbi,
                functionName: "renew",
                args: [options.name, tldNode, BigInt(duration), this.addresses.USDC],
                chain: this.chain,
                account,
            });
        } else {
            const total = await this.rentPrice(options.name, options.tld, duration);
            return walletClient.writeContract({
                address: this.addresses.RegistrarController,
                abi: registrarControllerAbi,
                functionName: "renew",
                args: [
                    options.name,
                    tldNode,
                    BigInt(duration),
                    "0x0000000000000000000000000000000000000000",
                ],
                value: total,
                chain: this.chain,
                account,
            });
        }
    }

    async setAddress(
        name: string,
        chain: SupportedChain,
        address: string,
        walletClient: WalletClient,
    ): Promise<Hash> {
        const account = walletClient.account;
        if (!account) throw new Error("walletClient.account is required");

        const node = _namehash(name);
        const coinType = BigInt(COIN_TYPES[chain]);
        const addrBytes: Hex = toHex(toBytes(address));

        return walletClient.writeContract({
            address: this.addresses.PublicResolver,
            abi: publicResolverAbi,
            functionName: "setAddr",
            args: [node, coinType, addrBytes],
            chain: this.chain,
            account,
        });
    }

    async setText(
        name: string,
        key: string,
        value: string,
        walletClient: WalletClient,
    ): Promise<Hash> {
        const account = walletClient.account;
        if (!account) throw new Error("walletClient.account is required");

        return walletClient.writeContract({
            address: this.addresses.PublicResolver,
            abi: publicResolverAbi,
            functionName: "setText",
            args: [_namehash(name), key, value],
            chain: this.chain,
            account,
        });
    }

    async setResolver(name: string, resolver: Address, walletClient: WalletClient): Promise<Hash> {
        const account = walletClient.account;
        if (!account) throw new Error("walletClient.account is required");

        return walletClient.writeContract({
            address: this.addresses.Registry,
            abi: registryAbi,
            functionName: "setResolver",
            args: [_namehash(name), resolver],
            chain: this.chain,
            account,
        });
    }

    // ---------------------------------------------------------------
    //                         UTILITIES
    // ---------------------------------------------------------------

    namehash(name: string): Hex {
        return _namehash(name);
    }

    labelhash(label: string): Hex {
        return _labelhash(label);
    }

    makeNode(parentNode: Hex, label: string): Hex {
        return _makeNode(parentNode, label);
    }

    parseName(name: string): { label: string; tld: string } | null {
        const dot = name.indexOf(".");
        if (dot <= 0 || dot === name.length - 1) return null;
        const label = name.slice(0, dot);
        const tld = name.slice(dot + 1);
        if (tld.includes(".")) return null;
        return { label, tld };
    }

    coinTypeFor(chain: SupportedChain): number {
        return COIN_TYPES[chain];
    }

    // ---------------------------------------------------------------
    //                          PRIVATE
    // ---------------------------------------------------------------

    private async _priceUsdc(name: string, duration: number): Promise<bigint> {
        return this.publicClient.readContract({
            address: this.addresses.PriceOracle,
            abi: priceOracleAbi,
            functionName: "priceUsdc",
            args: [name, 0n, BigInt(duration)],
        });
    }

    private _indexerUrl(path: string): string {
        const base = this.config.indexerUrl ?? "http://localhost:42069";
        return `${base.replace(/\/$/, "")}${path}`;
    }

    private _buildResolverData(
        nameNode: Hex,
        addresses?: Partial<Record<SupportedChain, string>>,
        texts?: Record<string, string>,
    ): Hex[] {
        const calls: Hex[] = [];

        if (addresses) {
            for (const [chain, addr] of Object.entries(addresses) as [SupportedChain, string][]) {
                if (!addr) continue;
                const addrBytes: Hex = toHex(toBytes(addr));
                calls.push(
                    encodeFunctionData({
                        abi: publicResolverAbi,
                        functionName: "setAddr",
                        args: [nameNode, BigInt(COIN_TYPES[chain]), addrBytes],
                    }),
                );
            }
        }

        if (texts) {
            for (const [key, value] of Object.entries(texts)) {
                calls.push(
                    encodeFunctionData({
                        abi: publicResolverAbi,
                        functionName: "setText",
                        args: [nameNode, key, value],
                    }),
                );
            }
        }

        return calls;
    }
}
