import { Oniym } from "@oniym/sdk";

export const oniym = new Oniym({
    indexerUrl: process.env.NEXT_PUBLIC_INDEXER_URL,
    rpcUrl: process.env.NEXT_PUBLIC_RPC_URL,
});

export const MONTHLY_DURATION = 30 * 24 * 60 * 60;
export const ANNUAL_DURATION = 365 * 24 * 60 * 60;

export function formatEth(wei: bigint): string {
    const eth = Number(wei) / 1e18;
    return eth < 0.001 ? "<0.001" : eth.toFixed(4);
}

export function truncateAddress(addr: string): string {
    return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function parseName(fullName: string): { label: string; tld: string } | null {
    const dot = fullName.lastIndexOf(".");
    if (dot <= 0 || dot === fullName.length - 1) return null;
    return { label: fullName.slice(0, dot), tld: fullName.slice(dot + 1) };
}
