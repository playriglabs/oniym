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
    "me", "web3", "xyz", "app", "co", "one", "wagmi", "degen", "gm", "io", "dev", "pro",
];

const BATCH_SIZE = 3;
const BATCH_DELAY = 150;

type RowStatus = "loading" | "available" | "taken" | "error";
type ViewMode = "list" | "grid";
type FilterMode = "all" | "available" | "taken";

interface TldRow {
    tld: string;
    status: RowStatus;
    isPrimary?: boolean;
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

function TldBadge({ tld, size = 36 }: { tld: string; size?: number }) {
    const meta = TLD_META[tld] ?? FALLBACK_META;
    const short = tld.length > 4 ? tld.slice(0, 4) : tld;
    return (
        <div
            className="rounded-xl flex items-center justify-center flex-shrink-0 text-[10px] font-mono font-bold"
            style={{ width: size, height: size, background: meta.bg, color: meta.color }}
        >
            .{short}
        </div>
    );
}

function StatusBadge({ status }: { status: RowStatus }) {
    if (status === "loading") {
        return <span className="w-3.5 h-3.5 rounded-full border border-text-muted/40 border-t-text-muted/80 animate-spin inline-block" />;
    }
    if (status === "available") {
        return (
            <span className="text-[11px] font-bold tracking-widest uppercase text-cyan">
                Available
            </span>
        );
    }
    if (status === "taken") {
        return (
            <span className="text-[11px] font-bold tracking-widest uppercase text-text-muted/60">
                Taken
            </span>
        );
    }
    return null;
}

export function SearchResults({ label, tld }: Props) {
    const router = useRouter();
    const { address } = useAccount();

    const [query, setQuery] = useState(label);
    const [view, setView] = useState<ViewMode>("list");
    const [filter, setFilter] = useState<FilterMode>("all");
    const [showAll, setShowAll] = useState(false);
    const [rows, setRows] = useState<TldRow[]>([]);
    const [isOwner, setIsOwner] = useState(false);

    const suggestionTlds = SUGGESTION_TLDS.filter((t) => t !== tld);

    useEffect(() => {
        setIsOwner(false);
        const initial: TldRow[] = [
            { tld, status: "loading", isPrimary: true },
            ...suggestionTlds.map((t) => ({ tld: t, status: "loading" as RowStatus })),
        ];
        setRows(initial);

        const update = (t: string, status: RowStatus) =>
            setRows((prev) => prev.map((r) => (r.tld === t ? { ...r, status } : r)));

        void oniym
            .available(label, tld)
            .then(async (avail) => {
                update(tld, avail ? "available" : "taken");
                if (!avail && address) {
                    const result = await oniym.resolve(`${label}.${tld}`);
                    if (result?.owner.toLowerCase() === address.toLowerCase()) {
                        setIsOwner(true);
                    }
                }
            })
            .catch(() => update(tld, "error"));

        void checkBatched(label, suggestionTlds, update);
    }, [label, tld, address]);

    function handleSearch() {
        const q = query.toLowerCase().replace(/[^a-z0-9-]/g, "");
        if (q.length < 3) return;
        router.push(`/search?q=${encodeURIComponent(q + "." + tld)}`);
    }

    function handleRefresh() {
        setRows((prev) => prev.map((r) => ({ ...r, status: "loading" })));
        const update = (t: string, status: RowStatus) =>
            setRows((prev) => prev.map((r) => (r.tld === t ? { ...r, status } : r)));
        const allTlds = rows.map((r) => r.tld);
        void checkBatched(label, allTlds, update);
    }

    function handleLoadAll() {
        setShowAll(true);
        setRows((prev) => {
            const existing = new Set(prev.map((r) => r.tld));
            const newTlds = SUPPORTED_TLDS.filter((t) => !existing.has(t));
            const update = (t: string, status: RowStatus) =>
                setRows((s) => s.map((r) => (r.tld === t ? { ...r, status } : r)));
            void checkBatched(label, newTlds, update);
            return [...prev, ...newTlds.map((t) => ({ tld: t, status: "loading" as RowStatus }))];
        });
    }

    function handleSelect(row: TldRow) {
        if (row.status !== "available") return;
        router.push(`/register/${encodeURIComponent(label + "." + row.tld)}`);
    }

    function handleManage(row: TldRow) {
        router.push(`/manage/${encodeURIComponent(label + "." + row.tld)}`);
    }

    const filteredRows = rows.filter((r) => {
        if (filter === "available") return r.status === "available";
        if (filter === "taken") return r.status === "taken";
        return true;
    });

    return (
        <div className="max-w-3xl mx-auto">
            {/* Search bar */}
            <div className="flex items-center gap-2 mb-6">
                <div className="flex-1 flex items-center bg-bg-surface border border-border-dark rounded-xl">
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

            {/* Toolbar */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-sm font-medium text-text-secondary">
                    Search for{" "}
                    <span className="font-mono font-semibold text-text-primary">{label}</span>
                </h2>

                <div className="flex items-center gap-2">
                    {/* Refresh */}
                    <button
                        onClick={handleRefresh}
                        className="w-8 h-8 flex items-center justify-center rounded-lg border border-border-dark text-text-muted hover:text-text-secondary hover:border-border-cyan transition-colors"
                    >
                        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                            <path d="M12 7A5 5 0 1 1 7 2a5 5 0 0 1 3.5 1.5L12 2v4H8l1.5-1.5A3 3 0 1 0 10 7" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
                        </svg>
                    </button>

                    {/* Filter */}
                    <div className="flex items-center rounded-lg border border-white/10 overflow-hidden bg-bg-surface">
                        {(["all", "available", "taken"] as FilterMode[]).map((f) => (
                            <button
                                key={f}
                                onClick={() => setFilter(f)}
                                className={`px-3 py-1.5 text-xs font-medium capitalize transition-colors ${
                                    filter === f
                                        ? "bg-cyan text-bg-base"
                                        : "text-text-muted hover:text-text-secondary"
                                }`}
                            >
                                {f}
                            </button>
                        ))}
                    </div>

                    {/* View toggle */}
                    <div className="flex items-center rounded-lg border border-white/10 overflow-hidden bg-bg-surface">
                        <button
                            onClick={() => setView("list")}
                            className={`w-8 h-8 flex items-center justify-center transition-colors ${
                                view === "list" ? "bg-cyan text-bg-base" : "text-text-muted hover:text-text-secondary"
                            }`}
                        >
                            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                                <rect x="1" y="2" width="12" height="2" rx="1" fill="currentColor"/>
                                <rect x="1" y="6" width="12" height="2" rx="1" fill="currentColor"/>
                                <rect x="1" y="10" width="12" height="2" rx="1" fill="currentColor"/>
                            </svg>
                        </button>
                        <button
                            onClick={() => setView("grid")}
                            className={`w-8 h-8 flex items-center justify-center transition-colors ${
                                view === "grid" ? "bg-cyan text-bg-base" : "text-text-muted hover:text-text-secondary"
                            }`}
                        >
                            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                                <rect x="1" y="1" width="5" height="5" rx="1" fill="currentColor"/>
                                <rect x="8" y="1" width="5" height="5" rx="1" fill="currentColor"/>
                                <rect x="1" y="8" width="5" height="5" rx="1" fill="currentColor"/>
                                <rect x="8" y="8" width="5" height="5" rx="1" fill="currentColor"/>
                            </svg>
                        </button>
                    </div>
                </div>
            </div>

            {/* List view */}
            <AnimatePresence mode="wait">
                {view === "list" && (
                    <motion.div
                        key="list"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.15 }}
                        className="rounded-2xl border border-border-dark overflow-hidden"
                    >
                        {/* Column headers */}
                        <div className="grid grid-cols-[1fr_auto_auto] sm:grid-cols-[1fr_160px_auto_auto] gap-4 px-4 py-2.5 border-b border-border-dark bg-bg-surface/50">
                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">Domain</span>
                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest hidden sm:block">Type</span>
                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">Price</span>
                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">Status</span>
                        </div>

                        {filteredRows.map((row, i) => {
                            const meta = TLD_META[row.tld] ?? FALLBACK_META;
                            const isAvailable = row.status === "available";
                            const isTaken = row.status === "taken";
                            const isPrimary = row.isPrimary;

                            return (
                                <motion.div
                                    key={row.tld}
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    transition={{ delay: Math.min(i * 0.02, 0.25) }}
                                    className={`grid grid-cols-[1fr_auto_auto] sm:grid-cols-[1fr_160px_auto_auto] gap-4 items-center px-4 py-3 border-b border-border-dark/60 last:border-b-0 transition-colors ${
                                        isAvailable ? "hover:bg-white/[0.02] cursor-pointer" : ""
                                    } ${isTaken ? "opacity-40" : ""} ${isPrimary ? "bg-cyan/[0.03]" : ""}`}
                                    onClick={() => isAvailable && handleSelect(row)}
                                >
                                    {/* Domain */}
                                    <div className="flex items-center gap-3 min-w-0">
                                        <TldBadge tld={row.tld} size={34} />
                                        <span className="font-mono text-sm font-medium text-text-primary truncate">
                                            {label}
                                            <span style={{ color: meta.color }}>.{row.tld}</span>
                                        </span>
                                    </div>

                                    {/* Type */}
                                    <span className="text-xs text-text-muted hidden sm:block truncate">{meta.label}</span>

                                    {/* Price */}
                                    <div className="flex-shrink-0">
                                        {isAvailable && (
                                            <span className="px-2 py-0.5 rounded-md text-[11px] font-semibold bg-cyan/10 text-cyan border border-cyan/20">
                                                $3/mo
                                            </span>
                                        )}
                                    </div>

                                    {/* Status + action */}
                                    <div className="flex items-center gap-2 flex-shrink-0 justify-end">
                                        <StatusBadge status={row.status} />
                                        {isAvailable && (
                                            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="text-text-muted">
                                                <path d="M5 3L9 7L5 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                                            </svg>
                                        )}
                                        {isTaken && isPrimary && isOwner && (
                                            <button
                                                onClick={(e) => { e.stopPropagation(); handleManage(row); }}
                                                className="px-2.5 py-1 rounded-lg border border-border-cyan text-cyan text-xs font-medium hover:bg-cyan-muted transition-all"
                                            >
                                                Manage
                                            </button>
                                        )}
                                    </div>
                                </motion.div>
                            );
                        })}

                        {/* Load all footer */}
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
                    </motion.div>
                )}

                {/* Grid view */}
                {view === "grid" && (
                    <motion.div
                        key="grid"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.15 }}
                    >
                        <div className="grid grid-cols-2 gap-3">
                            {filteredRows.map((row, i) => {
                                const meta = TLD_META[row.tld] ?? FALLBACK_META;
                                const isAvailable = row.status === "available";
                                const isTaken = row.status === "taken";

                                return (
                                    <motion.div
                                        key={row.tld}
                                        initial={{ opacity: 0, y: 8 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        transition={{ delay: Math.min(i * 0.03, 0.3) }}
                                        onClick={() => isAvailable && handleSelect(row)}
                                        className={`p-4 rounded-2xl border transition-all ${
                                            isAvailable
                                                ? "border-border-dark hover:border-border-cyan bg-bg-surface cursor-pointer"
                                                : "border-border-dark bg-bg-surface opacity-40"
                                        } ${row.isPrimary ? "ring-1 ring-cyan/20" : ""}`}
                                    >
                                        <div className="flex items-center gap-2.5 mb-3">
                                            <TldBadge tld={row.tld} size={32} />
                                            <div className="min-w-0">
                                                <div className="font-mono text-sm font-medium text-text-primary leading-tight truncate">
                                                    {label}
                                                    <span style={{ color: meta.color }}>.{row.tld}</span>
                                                </div>
                                                <div className="text-[11px] text-text-muted mt-0.5">{meta.label}</div>
                                            </div>
                                        </div>

                                        <div className="flex items-center justify-between">
                                            {isAvailable ? (
                                                <span className="px-2 py-0.5 rounded-md text-[11px] font-semibold bg-cyan/10 text-cyan border border-cyan/20">
                                                    $3/mo
                                                </span>
                                            ) : (
                                                <span />
                                            )}
                                            <StatusBadge status={row.status} />
                                        </div>
                                    </motion.div>
                                );
                            })}
                        </div>

                        {!showAll && (
                            <div className="mt-4 text-center">
                                <button
                                    onClick={handleLoadAll}
                                    className="text-xs text-text-muted hover:text-text-secondary transition-colors"
                                >
                                    Check all {SUPPORTED_TLDS.length} TLDs →
                                </button>
                            </div>
                        )}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
