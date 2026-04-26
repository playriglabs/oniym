import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { Oniym, COIN_TYPES, SUPPORTED_TLDS, MAX_TLD_COUNT, MAX_TLD_LENGTH } from "./oniym";

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
        expect(oniym.parseName("kyy.id")).toEqual({ label: "kyy", tld: "id" });
        expect(oniym.parseName("alice.one")).toEqual({ label: "alice", tld: "one" });
        expect(oniym.parseName("bob.xyz")).toEqual({ label: "bob", tld: "xyz" });
        expect(oniym.parseName("dev.web3")).toEqual({ label: "dev", tld: "web3" });
    });

    it("returns null for an empty string", () => {
        expect(oniym.parseName("")).toBeNull();
    });

    it("returns null for a bare label with no dot", () => {
        expect(oniym.parseName("kyy")).toBeNull();
    });

    it("returns null for sub-names (not supported in v1)", () => {
        expect(oniym.parseName("sub.kyy.id")).toBeNull();
    });

    it("returns null when the label part is empty", () => {
        expect(oniym.parseName(".id")).toBeNull();
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
        expect(oniym.namehash("kyy.id")).toMatch(/^0x[0-9a-f]{64}$/);
        expect(oniym.namehash("alice.one")).toMatch(/^0x[0-9a-f]{64}$/);
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
        expect(oniym.namehash("kyy.id")).toBe(oniym.namehash("kyy.id"));
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
});

describe("Oniym resolution (mocked fetch)", () => {
    const oniym = new Oniym({ indexerUrl: "http://localhost:42069" });

    beforeEach(() => {
        vi.stubGlobal("fetch", vi.fn());
    });

    afterEach(() => {
        vi.unstubAllGlobals();
    });

    it("getName returns null when indexer returns 404", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 404 }));
        await expect(
            oniym.getName("0x00000000000e1a99dddd5610111884278bdbda1d"),
        ).resolves.toBeNull();
    });

    it("getAddress returns null when name not found", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 404 }));
        await expect(oniym.getAddress("kyy.id", "eth")).resolves.toBeNull();
    });

    it("getAddresses returns empty object when name not found", async () => {
        vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 404 }));
        await expect(oniym.getAddresses("kyy.id")).resolves.toEqual({});
    });

    it("getName returns name from reverse lookup", async () => {
        vi.mocked(fetch).mockResolvedValue(
            new Response(
                JSON.stringify({
                    address: "0x123",
                    name: "kyy.web3",
                    reverseNode: "0xabc",
                    verified: false,
                }),
                { status: 200, headers: { "content-type": "application/json" } },
            ),
        );
        await expect(oniym.getName("0x123")).resolves.toBe("kyy.web3");
    });

    it("getAddress extracts correct coinType from resolve result", async () => {
        vi.mocked(fetch).mockResolvedValue(
            new Response(
                JSON.stringify({
                    name: "kyy.web3",
                    node: "0xf7d7c4fb47297d0f2106ac50d24c93063bc0fe50d559ed65e99edb91cc86f8a2",
                    owner: "0x123",
                    resolver: null,
                    expiresAt: "9999999999",
                    expired: false,
                    addresses: { "60": "0x11702b8eF5F882191Af862a7e27096C44A5e2B37" },
                    texts: {},
                    contenthash: null,
                }),
                { status: 200, headers: { "content-type": "application/json" } },
            ),
        );
        await expect(oniym.getAddress("kyy.web3", "eth")).resolves.toBe(
            "0x11702b8eF5F882191Af862a7e27096C44A5e2B37",
        );
    });
});
