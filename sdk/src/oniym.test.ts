import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { Oniym, COIN_TYPES, SUPPORTED_TLDS, MAX_TLD_COUNT, MAX_TLD_LENGTH } from "./oniym";
import type { ResolveResult, LookupResult, NamesResult } from "./oniym";

// ---------------------------------------------------------------
//                     CONSTANTS
// ---------------------------------------------------------------

describe("SUPPORTED_TLDS", () => {
    it("has exactly MAX_TLD_COUNT entries", () => {
        expect(SUPPORTED_TLDS.length).toBe(MAX_TLD_COUNT);
    });

    it("every label is within MAX_TLD_LENGTH characters", () => {
        for (const tld of SUPPORTED_TLDS) {
            expect(tld.length, `"${tld}" exceeds MAX_TLD_LENGTH`).toBeLessThanOrEqual(
                MAX_TLD_LENGTH,
            );
        }
    });

    it("contains no duplicates", () => {
        const unique = new Set(SUPPORTED_TLDS);
        expect(unique.size).toBe(SUPPORTED_TLDS.length);
    });

    it("contains no leading dots", () => {
        for (const tld of SUPPORTED_TLDS) {
            expect(tld.startsWith("."), `"${tld}" should not start with a dot`).toBe(false);
        }
    });

    it("MAX_TLD_COUNT is 65", () => {
        expect(MAX_TLD_COUNT).toBe(65);
    });

    it("MAX_TLD_LENGTH is 5", () => {
        expect(MAX_TLD_LENGTH).toBe(5);
    });
});

describe("COIN_TYPES", () => {
    it("has correct SLIP-0044 values", () => {
        expect(COIN_TYPES.btc).toBe(0);
        expect(COIN_TYPES.eth).toBe(60);
        expect(COIN_TYPES.sol).toBe(501);
        expect(COIN_TYPES.sui).toBe(784);
        expect(COIN_TYPES.bnb).toBe(714);
    });
});

// ---------------------------------------------------------------
//                     ONIYM CLASS
// ---------------------------------------------------------------

describe("Oniym.parseName", () => {
    const oniym = new Oniym();

    it("parses valid two-part names", () => {
        expect(oniym.parseName("kyy.web3")).toEqual({ label: "kyy", tld: "web3" });
        expect(oniym.parseName("alice.app")).toEqual({ label: "alice", tld: "app" });
        expect(oniym.parseName("bob.xyz")).toEqual({ label: "bob", tld: "xyz" });
        expect(oniym.parseName("dev.dev")).toEqual({ label: "dev", tld: "dev" });
    });

    it("returns null for an empty string", () => {
        expect(oniym.parseName("")).toBeNull();
    });

    it("returns null for a bare label with no dot", () => {
        expect(oniym.parseName("kyy")).toBeNull();
    });

    it("returns null for sub-names (not supported in v1)", () => {
        expect(oniym.parseName("sub.kyy.web3")).toBeNull();
    });

    it("returns null when the label part is empty", () => {
        expect(oniym.parseName(".web3")).toBeNull();
    });

    it("returns null when the TLD part is empty", () => {
        expect(oniym.parseName("kyy.")).toBeNull();
    });
});

describe("Oniym.coinTypeFor", () => {
    const oniym = new Oniym();

    it("returns correct SLIP-0044 coin types", () => {
        expect(oniym.coinTypeFor("btc")).toBe(0);
        expect(oniym.coinTypeFor("eth")).toBe(60);
        expect(oniym.coinTypeFor("sol")).toBe(501);
        expect(oniym.coinTypeFor("sui")).toBe(784);
        expect(oniym.coinTypeFor("bnb")).toBe(714);
    });
});

describe("Oniym.namehash / labelhash / makeNode", () => {
    const oniym = new Oniym();

    it("namehash produces a 32-byte hex string", () => {
        expect(oniym.namehash("kyy.web3")).toMatch(/^0x[0-9a-f]{64}$/);
        expect(oniym.namehash("alice.app")).toMatch(/^0x[0-9a-f]{64}$/);
    });

    it("namehash of empty string is zero", () => {
        expect(oniym.namehash("")).toBe(`0x${"00".repeat(32)}`);
    });

    it("labelhash produces a 32-byte hex string", () => {
        expect(oniym.labelhash("kyy")).toMatch(/^0x[0-9a-f]{64}$/);
    });

    it("makeNode is consistent with namehash for protocol TLDs", () => {
        for (const tld of SUPPORTED_TLDS) {
            const parent = oniym.namehash(tld);
            const viaMakeNode = oniym.makeNode(parent, "kyy");
            const viaNamehash = oniym.namehash(`kyy.${tld}`);
            expect(viaMakeNode, `makeNode mismatch for .${tld}`).toBe(viaNamehash);
        }
    });

    it("different TLDs produce different nodes for the same label", () => {
        const nodes = SUPPORTED_TLDS.map((tld) => oniym.namehash(`kyy.${tld}`));
        const unique = new Set(nodes);
        expect(unique.size).toBe(SUPPORTED_TLDS.length);
    });

    it("is deterministic", () => {
        expect(oniym.namehash("kyy.web3")).toBe(oniym.namehash("kyy.web3"));
    });
});

describe("Oniym.getTLDs", () => {
    const oniym = new Oniym();

    it("returns exactly MAX_TLD_COUNT TLDs", () => {
        const tlds = oniym.getTLDs();
        expect(tlds).toHaveLength(MAX_TLD_COUNT);
    });

    it("each TLD has the correct shape", () => {
        const tlds = oniym.getTLDs();
        for (const tld of tlds) {
            expect(tld.label).toBeTruthy();
            expect(tld.node).toMatch(/^0x[0-9a-f]{64}$/);
            expect(typeof tld.active).toBe("boolean");
        }
    });

    it("TLD labels match SUPPORTED_TLDS", () => {
        const tlds = oniym.getTLDs();
        const labels = tlds.map((t) => t.label);
        expect(labels).toEqual([...SUPPORTED_TLDS]);
    });

    it("all TLD nodes are distinct", () => {
        const tlds = oniym.getTLDs();
        const nodes = new Set(tlds.map((t) => t.node));
        expect(nodes.size).toBe(tlds.length);
    });

    it("all TLDs are marked active", () => {
        const tlds = oniym.getTLDs();
        expect(tlds.every((t) => t.active)).toBe(true);
    });
});

// ---------------------------------------------------------------
//                  ONIYM INDEXER READS (mocked fetch)
// ---------------------------------------------------------------

const MOCK_RESOLVE: ResolveResult = {
    name: "kyy.web3",
    node: "0xf7d7c4fb47297d0f2106ac50d24c93063bc0fe50d559ed65e99edb91cc86f8a2",
    owner: "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
    resolver: "0xcdE3eD98423FbE098E24Bba9B634dFC3b449AC1C",
    expiresAt: "9999999999",
    expired: false,
    addresses: {
        "60": "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
        "501": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
    },
    texts: { twitter: "@kyy", github: "kyy" },
    contenthash: null,
};

const MOCK_LOOKUP: LookupResult = {
    address: "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
    name: "kyy.web3",
    reverseNode: "0xabc",
    verified: true,
};

const MOCK_NAMES: NamesResult = {
    address: "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
    names: [
        {
            name: "kyy.web3",
            node: "0xf7d7c4fb47297d0f2106ac50d24c93063bc0fe50d559ed65e99edb91cc86f8a2",
            expiresAt: "9999999999",
            expired: false,
        },
        {
            name: "kyy.app",
            node: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            expiresAt: "9999999999",
            expired: false,
        },
    ],
};

function ok(body: unknown): Response {
    return new Response(JSON.stringify(body), {
        status: 200,
        headers: { "content-type": "application/json" },
    });
}

function notFound(): Response {
    return new Response(null, { status: 404 });
}

describe("Oniym.resolve (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => void vi.stubGlobal("fetch", vi.fn()));
    afterEach(() => vi.unstubAllGlobals());

    it("returns full ResolveResult on success", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_RESOLVE));
        const result = await oniym.resolve("kyy.web3");
        expect(result?.name).toBe("kyy.web3");
        expect(result?.owner).toBe("0x11702b8eF5F882191Af862a7e27096C44A5e2B37");
        expect(result?.expired).toBe(false);
    });

    it("returns null on 404", async () => {
        vi.mocked(fetch).mockResolvedValue(notFound());
        await expect(oniym.resolve("unknown.web3")).resolves.toBeNull();
    });

    it("throws on unexpected server error", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 500 }));
        await expect(oniym.resolve("kyy.web3")).rejects.toThrow("Resolve failed: 500");
    });
});

describe("Oniym.getName (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => void vi.stubGlobal("fetch", vi.fn()));
    afterEach(() => vi.unstubAllGlobals());

    it("returns the primary name for a known address", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_LOOKUP));
        await expect(oniym.getName("0x11702b8eF5F882191Af862a7e27096C44A5e2B37")).resolves.toBe(
            "kyy.web3",
        );
    });

    it("returns null when address has no primary name (name: null in response)", async () => {
        vi.mocked(fetch).mockResolvedValue(ok({ ...MOCK_LOOKUP, name: null }));
        await expect(
            oniym.getName("0x11702b8eF5F882191Af862a7e27096C44A5e2B37"),
        ).resolves.toBeNull();
    });

    it("returns null on 404", async () => {
        vi.mocked(fetch).mockResolvedValue(notFound());
        await expect(
            oniym.getName("0x00000000000e1a99dddd5610111884278bdbda1d"),
        ).resolves.toBeNull();
    });

    it("throws on unexpected server error", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 500 }));
        await expect(oniym.getName("0x11702b8eF5F882191Af862a7e27096C44A5e2B37")).rejects.toThrow(
            "Lookup failed: 500",
        );
    });
});

describe("Oniym.getAddress (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => void vi.stubGlobal("fetch", vi.fn()));
    afterEach(() => vi.unstubAllGlobals());

    it("returns ETH address by coinType 60", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_RESOLVE));
        await expect(oniym.getAddress("kyy.web3", "eth")).resolves.toBe(
            "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
        );
    });

    it("returns SOL address by coinType 501", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_RESOLVE));
        await expect(oniym.getAddress("kyy.web3", "sol")).resolves.toBe(
            "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
        );
    });

    it("returns null when the chain is not set", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_RESOLVE));
        await expect(oniym.getAddress("kyy.web3", "btc")).resolves.toBeNull();
    });

    it("returns null when name not found", async () => {
        vi.mocked(fetch).mockResolvedValue(notFound());
        await expect(oniym.getAddress("unknown.web3", "eth")).resolves.toBeNull();
    });
});

describe("Oniym.getAddresses (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => void vi.stubGlobal("fetch", vi.fn()));
    afterEach(() => vi.unstubAllGlobals());

    it("returns all stored chain addresses", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_RESOLVE));
        const result = await oniym.getAddresses("kyy.web3");
        expect(result.eth).toBe("0x11702b8eF5F882191Af862a7e27096C44A5e2B37");
        expect(result.sol).toBe("7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU");
        expect(result.btc).toBeUndefined();
    });

    it("returns empty object when name not found", async () => {
        vi.mocked(fetch).mockResolvedValue(notFound());
        await expect(oniym.getAddresses("unknown.web3")).resolves.toEqual({});
    });

    it("returns empty object when name has no addresses", async () => {
        vi.mocked(fetch).mockResolvedValue(ok({ ...MOCK_RESOLVE, addresses: {} }));
        await expect(oniym.getAddresses("kyy.web3")).resolves.toEqual({});
    });
});

describe("Oniym.getNames (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => void vi.stubGlobal("fetch", vi.fn()));
    afterEach(() => vi.unstubAllGlobals());

    it("returns all owned names for an address", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_NAMES));
        const result = await oniym.getNames("0x11702b8eF5F882191Af862a7e27096C44A5e2B37");
        expect(result).toHaveLength(2);
        expect(result[0]?.name).toBe("kyy.web3");
        expect(result[1]?.name).toBe("kyy.app");
    });

    it("returns empty array when address owns no names", async () => {
        vi.mocked(fetch).mockResolvedValue(ok({ address: "0x000", names: [] }));
        const result = await oniym.getNames("0x000");
        expect(result).toEqual([]);
    });

    it("returns correct OwnedName shape", async () => {
        vi.mocked(fetch).mockResolvedValue(ok(MOCK_NAMES));
        const result = await oniym.getNames("0x11702b8eF5F882191Af862a7e27096C44A5e2B37");
        const first = result[0];
        expect(first?.name).toBe("kyy.web3");
        expect(first?.node).toMatch(/^0x[0-9a-f]{64}$/);
        expect(first?.expiresAt).toBe("9999999999");
        expect(first?.expired).toBe(false);
    });

    it("throws on server error", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 500 }));
        await expect(oniym.getNames("0x11702b8eF5F882191Af862a7e27096C44A5e2B37")).rejects.toThrow(
            "getNames failed: 500",
        );
    });
});
