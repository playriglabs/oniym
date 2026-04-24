import { describe, it, expect } from "vitest";
import { namehash, makeNode, labelhash } from "./namehash";

describe("namehash", () => {
    // Parity tests with Solidity - exact same vectors as Namehash.t.sol

    it("empty string returns zero", () => {
        expect(namehash("")).toBe(`0x${"00".repeat(32)}`);
    });

    it("hashes 'eth' to canonical ENS value", () => {
        expect(namehash("eth")).toBe(
            "0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae",
        );
    });

    it("hashes 'foo.eth' correctly", () => {
        expect(namehash("foo.eth")).toBe(
            "0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f",
        );
    });

    it("hashes 'vitalik.eth' correctly", () => {
        expect(namehash("vitalik.eth")).toBe(
            "0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835",
        );
    });

    it("handles multi-level subdomains", () => {
        // wallet.kyy.eth should equal the step-by-step construction
        const eth = namehash("eth");
        const kyyEth = makeNode(eth, "kyy");
        const walletKyyEth = makeNode(kyyEth, "wallet");

        expect(namehash("wallet.kyy.eth")).toBe(walletKyyEth);
    });

    it("is deterministic", () => {
        const a = namehash("kyy.eth");
        const b = namehash("kyy.eth");
        expect(a).toBe(b);
    });
});

describe("makeNode", () => {
    it("matches full namehash for subdomain construction", () => {
        const parent = namehash("eth");
        const viaMakeNode = makeNode(parent, "kyy");
        const viaNamehash = namehash("kyy.eth");

        expect(viaMakeNode).toBe(viaNamehash);
    });
});

describe("labelhash", () => {
    it("is keccak256 of UTF-8 label bytes", () => {
        // keccak256('eth') in ENS:
        expect(labelhash("eth")).toBe(
            "0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0",
        );
    });
});
