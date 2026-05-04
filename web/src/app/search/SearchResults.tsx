"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAccount } from "wagmi";
import { motion, AnimatePresence } from "framer-motion";
import { oniym } from "@/lib/oniym";
import { SUPPORTED_TLDS } from "@oniym/sdk";

const TLD_META: Record<string, { bg: string; color: string; label: string }> = {
    id: { bg: "rgba(20,172,195,0.18)", color: "#85efff", label: "Oniym Identity" },
    me: { bg: "rgba(96,165,250,0.18)", color: "#93c5fd", label: "Personal" },
    web3: { bg: "rgba(167,139,250,0.18)", color: "#c4b5fd", label: "Web3 Native" },
    xyz: { bg: "rgba(52,211,153,0.18)", color: "#6ee7b7", label: "General Purpose" },
    app: { bg: "rgba(251,146,60,0.18)", color: "#fdba74", label: "Applications" },
    wagmi: { bg: "rgba(244,114,182,0.18)", color: "#f9a8d4", label: "DeFi & Culture" },
    degen: { bg: "rgba(250,204,21,0.18)", color: "#fde047", label: "Degen Finance" },
    gm: { bg: "rgba(74,222,128,0.18)", color: "#86efac", label: "GM Community" },
    one: { bg: "rgba(129,140,248,0.18)", color: "#a5b4fc", label: "Universal" },
    co: { bg: "rgba(251,191,36,0.18)", color: "#fcd34d", label: "Companies" },
    io: { bg: "rgba(56,189,248,0.18)", color: "#7dd3fc", label: "Tech" },
    dev: { bg: "rgba(99,102,241,0.18)", color: "#a5b4fc", label: "Developers" },
    pro: { bg: "rgba(168,162,158,0.18)", color: "#d6d3d1", label: "Professionals" },
};

const FALLBACK_META = { bg: "rgba(133,239,255,0.12)", color: "#85efff", label: "Oniym" };

const SUGGESTION_TLDS = [
    "id", "me", "web3", "xyz", "app", "co", "one", "wagmi", "degen", "gm", "io", "dev", "pro",
];

const BATCH_SIZE = 3;
const BATCH_DELAY = 150;

type RowStatus = "loading" | "available" | "taken" | "error";

interface TldRow {
    tld: string;
    status: RowStatus;
}

async function checkBatched(
    label: string,
    tlds: string[],
    onResult: (tld: string, status: RowStatus) => void,
) {
    for (let i = 0; i < tlds.length; i += BATCH_SIZE) {
        const batch = tlds.slice(i, i + BATCH_SIZE);
        await Promise.all(
            batch.map(async (t) => {
                try {
                    const avail = await oniym.available(label, t);
                    onResult(t, avail ? "available" : "taken");
                } catch {
                    onResult(t, "error");
                }
            }),
        );
        if (i + BATCH_SIZE < tlds.length) {
            await new Promise<void>((r) => setTimeout(r, BATCH_DELAY));
        }
    }
}

interface Props {
    label: string;
    tld: string;
}

export function SearchResults({ label, tld }: Props) {
    const router = useRouter();
    const { address } = useAccount();

    const [query, setQuery] = useState(label);
    const [mainStatus, setMainStatus] = useState<RowStatus>("loading");
    const [isOwner, setIsOwner] = useState(false);
    const [suggestions, setSuggestions] = useState<TldRow[]>([]);
    const [showAll, setShowAll] = useState(false);

    const suggestionTlds = SUGGESTION_TLDS.filter((t) => t !== tld).slice(0, 12);

    useEffect(() => {
        setMainStatus("loading");
        setIsOwner(false);

        void oniym
            .available(label, tld)
            .then(async (avail) => {
                setMainStatus(avail ? "available" : "taken");
                if (!avail && address) {
                    const result = await oniym.resolve(`${label}.${tld}`);
                    if (result?.owner.toLowerCase() === address.toLowerCase()) {
                        setIsOwner(true);
                    }
                }
            })
            .catch(() => setMainStatus("error"));

        setSuggestions(suggestionTlds.map((t) => ({ tld: t, status: "loading" })));
        void checkBatched(label, suggestionTlds, (t, status) => {
            setSuggestions((prev) => prev.map((row) => (row.tld === t ? { ...row, status } : row)));
        });
    }, [label, tld, address]);

    function handleSearch() {
        const q = query.toLowerCase().replace(/[^a-z0-9-]/g, "");
        if (q.length < 3) return;
        router.push(`/search?q=${encodeURIComponent(q + "." + tld)}`);
    }

    function handleLoadAll() {
        setShowAll(true);
        const all = SUPPORTED_TLDS.filter((t) => t !== tld);
        setSuggestions((prev) => {
            const existing = new Set(prev.map((r) => r.tld));
            const newTlds = all.filter((t) => !existing.has(t));
            void checkBatched(label, newTlds, (t, status) => {
                setSuggestions((s) => s.map((row) => (row.tld === t ? { ...row, status } : row)));
            });
            return [
                ...prev,
                ...newTlds.map((t) => ({ tld: t, status: "loading" as RowStatus })),
            ];
        });
    }

    const mainMeta = TLD_META[tld] ?? FALLBACK_META;

    return (
        <div className="max-w-2xl mx-auto">
            {/* Search bar */}
            <div className="flex items-center gap-2 mb-8">
                <div className="flex-1 flex items-center bg-bg-surface border border-border-dark rounded-xl shadow-[0_0_0_1px_rgba(255,255,255,0.04)]">
                    <input
                        type="text"
                        value={query}
                        onChange={(e) =>
                            setQuery(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))
                        }
                        onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                        spellCheck={false}
                        autoCapitalize="none"
                        className="flex-1 bg-transparent px-4 py-3 text-sm font-mono text-text-primary outline-none"
                    />
                </div>
                <button
                    onClick={handleSearch}
                    disabled={query.length < 3}
                    className="px-5 py-3 rounded-xl bg-cyan text-bg-base text-sm font-semibold disabled:opacity-30 hover:opacity-90 active:scale-95 transition-all"
                >
                    Search
                </button>
            </div>

            {/* Main result */}
            <AnimatePresence mode="wait">
                <motion.div
                    key={`${label}.${tld}`}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.2 }}
                    className={`rounded-2xl border p-4 mb-8 flex items-center gap-4 ${
                        mainStatus === "available"
                            ? "border-border-cyan bg-cyan-muted"
                            : mainStatus === "taken"
                              ? "border-error/25 bg-error-muted"
                              : "border-border-dark bg-bg-surface"
                    }`}
                >
                    {/* Badge */}
                    <div
                        className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 text-[11px] font-mono font-bold"
                        style={{ background: mainMeta.bg, color: mainMeta.color }}
                    >
                        .{tld.length > 3 ? tld.slice(0, 3) : tld}
                    </div>

                    {/* Name */}
                    <div className="flex-1 min-w-0">
                        <div className="font-mono font-medium text-text-primary">
                            <span>{label}</span>
                            <span style={{ color: mainMeta.color }}>.{tld}</span>
                        </div>
                        <div className="text-xs text-text-muted mt-0.5">{mainMeta.label}</div>
                    </div>

                    {/* Status + CTA */}
                    <div className="flex items-center gap-3 flex-shrink-0">
                        {mainStatus === "loading" && (
                            <span className="w-4 h-4 rounded-full border border-text-muted/40 border-t-text-muted animate-spin" />
                        )}
                        {mainStatus === "available" && (
                            <>
                                <div className="text-right hidden sm:block">
                                    <div className="text-xs font-bold tracking-widest uppercase text-cyan">Available</div>
                                    <div className="text-xs text-text-muted">$3 / mo</div>
                                </div>
                                <button
                                    onClick={() =>
                                        router.push(`/register/${encodeURIComponent(label + "." + tld)}`)
                                    }
                                    className="px-4 py-2 rounded-xl bg-cyan text-bg-base text-sm font-semibold hover:opacity-90 active:scale-95 transition-all"
                                >
                                    Register
                                </button>
                            </>
                        )}
                        {mainStatus === "taken" && !isOwner && (
                            <span className="text-xs font-bold tracking-widest uppercase text-error/70">
                                Taken
                            </span>
                        )}
                        {mainStatus === "taken" && isOwner && (
                            <button
                                onClick={() =>
                                    router.push(`/manage/${encodeURIComponent(label + "." + tld)}`)
                                }
                                className="px-4 py-2 rounded-xl border border-border-cyan text-cyan text-sm font-medium hover:bg-cyan-muted active:scale-95 transition-all"
                            >
                                Manage
                            </button>
                        )}
                    </div>
                </motion.div>
            </AnimatePresence>

            {/* Other TLDs */}
            <div
                className="rounded-2xl border border-border-dark overflow-hidden"
                style={{ boxShadow: "0 4px 24px rgba(0,0,0,0.3)" }}
            >
                <div className="px-4 pt-3 pb-2 border-b border-border-dark">
                    <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">
                        More options
                    </span>
                </div>

                <div>
                    {suggestions.map((row, i) => {
                        const meta = TLD_META[row.tld] ?? FALLBACK_META;
                        const isAvailable = row.status === "available";
                        const isTaken = row.status === "taken";
                        const isLoading = row.status === "loading";

                        return (
                            <motion.button
                                key={row.tld}
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                transition={{ delay: Math.min(i * 0.025, 0.3) }}
                                onClick={() =>
                                    isAvailable &&
                                    router.push(
                                        `/register/${encodeURIComponent(label + "." + row.tld)}`,
                                    )
                                }
                                className={`w-full flex items-center gap-3 px-4 py-3 border-b border-border-dark/60 last:border-b-0 transition-colors group ${
                                    isAvailable
                                        ? "hover:bg-white/[0.025] cursor-pointer"
                                        : "cursor-default"
                                } ${isTaken ? "opacity-40" : ""}`}
                            >
                                {/* Badge */}
                                <div
                                    className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 text-[11px] font-mono font-bold"
                                    style={{ background: meta.bg, color: meta.color }}
                                >
                                    .{row.tld.length > 3 ? row.tld.slice(0, 3) : row.tld}
                                </div>

                                {/* Name */}
                                <div className="flex-1 text-left min-w-0">
                                    <div className="text-sm font-mono font-medium text-text-primary leading-tight">
                                        <span>{label}</span>
                                        <span style={{ color: meta.color }}>.{row.tld}</span>
                                    </div>
                                    <div className="text-xs text-text-muted mt-0.5">{meta.label}</div>
                                </div>

                                {/* Status */}
                                <div className="flex items-center gap-2 flex-shrink-0">
                                    {isLoading && (
                                        <span className="w-3 h-3 rounded-full border border-text-muted/30 border-t-text-muted/70 animate-spin" />
                                    )}
                                    {isAvailable && (
                                        <span className="text-[11px] font-bold tracking-widest uppercase text-cyan">
                                            Available
                                        </span>
                                    )}
                                    {isTaken && (
                                        <span className="text-[11px] font-bold tracking-widest uppercase text-text-muted">
                                            Taken
                                        </span>
                                    )}
                                    {isAvailable && (
                                        <svg
                                            width="15"
                                            height="15"
                                            viewBox="0 0 15 15"
                                            fill="none"
                                            className="text-text-muted group-hover:text-text-secondary transition-colors"
                                        >
                                            <path
                                                d="M5.5 3.5L9.5 7.5L5.5 11.5"
                                                stroke="currentColor"
                                                strokeWidth="1.5"
                                                strokeLinecap="round"
                                                strokeLinejoin="round"
                                            />
                                        </svg>
                                    )}
                                </div>
                            </motion.button>
                        );
                    })}
                </div>

                {/* Load all */}
                {!showAll && (
                    <div className="px-4 py-3 border-t border-border-dark">
                        <button
                            onClick={handleLoadAll}
                            className="text-xs text-text-muted hover:text-text-secondary transition-colors"
                        >
                            Check all {SUPPORTED_TLDS.length} TLDs →
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
}
