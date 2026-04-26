/**
 * Oniym SDK — Node.js example
 *
 * Demonstrates name resolution against the local indexer.
 * Run: pnpm start
 */

import { Oniym } from "@oniym/sdk";

const oniym = new Oniym({
    indexerUrl: "http://localhost:42069",
    rpcUrl: "https://sepolia.base.org",
});

async function main(): Promise<void> {
    console.log("=== Oniym SDK Example ===\n");

    // Forward resolution
    const name = "kyy.web3";
    console.log(`Resolving ${name}...`);
    const result = await oniym.resolve(name);
    if (result) {
        console.log(`  owner:     ${result.owner}`);
        console.log(
            `  expiresAt: ${new Date(Number(result.expiresAt) * 1000).toLocaleDateString()}`,
        );
        console.log(`  expired:   ${String(result.expired)}`);
        console.log(`  addresses: ${JSON.stringify(result.addresses)}`);
        console.log(`  texts:     ${JSON.stringify(result.texts)}`);
    } else {
        console.log("  not found");
    }

    // Reverse resolution
    console.log("\nReverse lookup for 0x11702b8eF5F882191Af862a7e27096C44A5e2B37...");
    const reverseName = await oniym.getName("0x11702b8eF5F882191Af862a7e27096C44A5e2B37");
    console.log(`  name: ${reverseName ?? "not set"}`);

    // Availability check (via RPC)
    console.log("\nChecking availability of alice.web3...");
    const isAvailable = await oniym.available("alice", "web3");
    console.log(`  available: ${String(isAvailable)}`);

    // Rent price (via RPC)
    console.log("\nRent price for kyy.dev (1 year)...");
    const price = await oniym.rentPrice("kyy", "dev", 365 * 24 * 60 * 60);
    console.log(`  price: ${price.toString()} wei (${(Number(price) / 1e18).toString()} ETH)`);

    // Namehash utilities
    console.log("\nNamehash utilities:");
    console.log(`  namehash('kyy.web3'): ${oniym.namehash("kyy.web3")}`);
    console.log(`  labelhash('kyy'):     ${oniym.labelhash("kyy")}`);
    console.log(`  parseName('kyy.web3'): ${JSON.stringify(oniym.parseName("kyy.web3"))}`);
}

main().catch(console.error);
