/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/no-unnecessary-type-assertion */
/* eslint-disable @typescript-eslint/no-confusing-void-expression */
/* eslint-disable @typescript-eslint/explicit-function-return-type */

"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { useAccount } from "wagmi";
import { motion, AnimatePresence } from "framer-motion";
import { oniym } from "@/lib/oniym";
import { SUPPORTED_TLDS } from "@oniym/sdk";

const FEATURED_TLDS = [
    "id",
    "me",
    "web3",
    "xyz",
    "app",
    "wagmi",
    "degen",
    "gm",
    "one",
    "co",
] as const;

interface Props {
    label: string;
    tld: string;
}

type RowStatus = "loading" | "available" | "taken" | "error";

interface TldRow {
    tld: string;
    status: RowStatus;
}

const SUGGESTION_TLDS = [
    "id",
    "me",
    "web3",
    "xyz",
    "app",
    "co",
    "one",
    "wagmi",
    "degen",
    "gm",
    "io",
    "dev",
    "pro",
];

const BATCH_SIZE = 3;
const BATCH_DELAY = 150; // ms between batches

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

export function SearchResults({ label, tld }: Props) {
    const router = useRouter();
    const inputRef = useRef<HTMLInputElement>(null);
    const tldMenuRef = useRef<HTMLDivElement>(null);

    const [query, setQuery] = useState(label);
    const [selectedTld, setSelectedTld] = useState(tld);
    const [showTldMenu, setShowTldMenu] = useState(false);
    const [showAllTlds, setShowAllTlds] = useState(false);
    const { address } = useAccount();
    const [mainStatus, setMainStatus] = useState<RowStatus>("loading");
    const [isOwner, setIsOwner] = useState(false);
    const [suggestions, setSuggestions] = useState<TldRow[]>([]);

    const suggestionTlds = SUGGESTION_TLDS.filter((t) => t !== tld).slice(0, 12);

    useEffect(() => {
        function handleClick(e: MouseEvent) {
            if (tldMenuRef.current && !tldMenuRef.current.contains(e.target as Node)) {
                setShowTldMenu(false);
            }
        }
        document.addEventListener("mousedown", handleClick);
        return () => document.removeEventListener("mousedown", handleClick);
    }, []);

    useEffect(() => {
        setMainStatus("loading");
        setIsOwner(false);

        oniym
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
    }, [label, tld]);

    function handleSearch() {
        const q = query.toLowerCase().replace(/[^a-z0-9-]/g, "");
        if (q.length < 3) return;
        router.push(`/search?q=${encodeURIComponent(q + "." + selectedTld)}`);
    }

    return (
        <div className="max-w-2xl mx-auto">
            {/* Search bar */}
            <div className="flex items-center gap-2 mb-8">
                <div className="flex-1 flex items-center bg-bg-surface border border-border-dark rounded-xl">
                    <input
                        ref={inputRef}
                        type="text"
                        value={query}
                        onChange={(e) => {
                            setQuery(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""));
                        }}
                        onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                        spellCheck={false}
                        autoCapitalize="none"
                        maxLength={6}
                        className="flex-1 bg-transparent px-4 py-3 text-sm font-mono text-text-primary outline-none"
                    />
                    <div ref={tldMenuRef} className="relative flex-shrink-0">
                        <button
                            onClick={() => setShowTldMenu(!showTldMenu)}
                            className="flex items-center gap-1 px-3 py-3 text-sm font-mono font-medium text-cyan hover:opacity-80 transition-opacity"
                        >
                            <span>.{selectedTld}</span>
                            <svg
                                width="12"
                                height="12"
                                viewBox="0 0 14 14"
                                fill="none"
                                className={`transition-transform duration-150 ${showTldMenu ? "rotate-180" : ""}`}
                            >
                                <path
                                    d="M3 5L7 9L11 5"
                                    stroke="currentColor"
                                    strokeWidth="1.5"
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                />
                            </svg>
                        </button>
                        <AnimatePresence>
                            {showTldMenu && (
                                <motion.div
                                    initial={{ opacity: 0, y: -6 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    exit={{ opacity: 0, y: -6 }}
                                    transition={{ duration: 0.15 }}
                                    className="absolute top-full right-0 mt-1.5 w-56 bg-bg-elevated border border-border-dark rounded-xl overflow-hidden shadow-card z-50"
                                >
                                    <div className="p-2 grid grid-cols-3 gap-1 max-h-52 overflow-y-auto">
                                        {(showAllTlds ? SUPPORTED_TLDS : FEATURED_TLDS).map((t) => (
                                            <button
                                                key={t}
                                                onClick={() => {
                                                    setSelectedTld(t);
                                                    setShowTldMenu(false);
                                                }}
                                                className={`px-2 py-1.5 rounded-lg text-xs font-mono text-left transition-colors ${
                                                    t === selectedTld
                                                        ? "bg-cyan-muted text-cyan border border-border-cyan"
                                                        : "text-text-secondary hover:text-text-primary hover:bg-bg-surface"
                                                }`}
                                            >
                                                .{t}
                                            </button>
                                        ))}
                                    </div>
                                    <div className="border-t border-border-dark p-2">
                                        <button
                                            onClick={() => setShowAllTlds(!showAllTlds)}
                                            className="w-full px-2 py-1 text-xs text-text-muted hover:text-text-secondary transition-colors text-center"
                                        >
                                            {showAllTlds
                                                ? "Show fewer"
                                                : `See all ${SUPPORTED_TLDS.length} TLDs`}
                                        </button>
                                    </div>
                                </motion.div>
                            )}
                        </AnimatePresence>
                    </div>
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
                    className={`rounded-xl border p-4 mb-6 flex items-center justify-between gap-4 ${
                        mainStatus === "available"
                            ? "border-border-cyan bg-cyan-muted"
                            : mainStatus === "taken"
                              ? "border-error/30 bg-error-muted"
                              : "border-border-dark bg-bg-surface"
                    }`}
                >
                    <div className="flex items-center gap-3 min-w-0">
                        {mainStatus === "loading" ? (
                            <span className="w-3 h-3 rounded-full border border-text-muted border-t-transparent animate-spin flex-shrink-0" />
                        ) : (
                            <span
                                className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${
                                    mainStatus === "available" ? "bg-cyan" : "bg-error"
                                }`}
                            />
                        )}
                        <span className="font-mono text-text-primary truncate">
                            {label}.{tld}
                        </span>
                        {mainStatus !== "loading" && (
                            <span className="text-sm text-text-secondary flex-shrink-0">
                                {mainStatus === "available" ? "is available" : "is already taken"}
                            </span>
                        )}
                    </div>

                    <div className="flex items-center gap-3 flex-shrink-0">
                        {mainStatus === "available" && (
                            <span className="text-sm text-text-secondary">
                                $3 <span className="text-text-muted">/ mo</span>
                            </span>
                        )}
                        {mainStatus === "available" && (
                            <button
                                onClick={() =>
                                    router.push(`/register/${encodeURIComponent(label + "." + tld)}`)
                                }
                                className="px-4 py-1.5 rounded-lg bg-cyan text-bg-base text-sm font-semibold hover:opacity-90 active:scale-95 transition-all"
                            >
                                Register
                            </button>
                        )}
                        {mainStatus === "taken" && isOwner && (
                            <button
                                onClick={() =>
                                    router.push(`/manage/${encodeURIComponent(label + "." + tld)}`)
                                }
                                className="px-4 py-1.5 rounded-lg border border-border-cyan text-cyan text-sm font-medium hover:bg-cyan-muted active:scale-95 transition-all"
                            >
                                Manage
                            </button>
                        )}
                    </div>
                </motion.div>
            </AnimatePresence>

            {/* Suggestions */}
            <div>
                <p className="text-xs font-medium text-text-muted uppercase tracking-widest mb-3">
                    More options
                </p>
                <div className="space-y-1.5">
                    {suggestions.map((row, i) => (
                        <motion.div
                            key={row.tld}
                            initial={{ opacity: 0, y: 6 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ duration: 0.2, delay: i * 0.03 }}
                            className="flex items-center justify-between gap-4 px-4 py-3 rounded-xl bg-bg-surface border border-border-dark hover:border-border-cyan transition-colors"
                        >
                            <div className="flex items-center gap-3 min-w-0">
                                {row.status === "loading" ? (
                                    <span className="w-2 h-2 rounded-full border border-text-muted border-t-transparent animate-spin flex-shrink-0" />
                                ) : (
                                    <span
                                        className={`w-2 h-2 rounded-full flex-shrink-0 ${
                                            row.status === "available"
                                                ? "bg-cyan"
                                                : "bg-border-dark"
                                        }`}
                                    />
                                )}
                                <span
                                    className={`font-mono text-sm ${
                                        row.status === "taken"
                                            ? "text-text-muted line-through"
                                            : "text-text-primary"
                                    }`}
                                >
                                    {label}.{row.tld}
                                </span>
                            </div>

                            <div className="flex items-center gap-3 flex-shrink-0">
                                {row.status === "available" && (
                                    <span className="text-xs text-text-secondary">
                                        $3 <span className="text-text-muted">/ mo</span>
                                    </span>
                                )}
                                {row.status === "taken" && (
                                    <span className="text-xs text-text-muted">Taken</span>
                                )}
                                {row.status === "available" && (
                                    <button
                                        onClick={() => {
                                            router.push(
                                                `/register/${encodeURIComponent(label + "." + row.tld)}`,
                                            );
                                        }}
                                        className="px-3 py-1 rounded-lg border border-border-cyan text-cyan text-xs font-medium hover:bg-cyan-muted active:scale-95 transition-all"
                                    >
                                        Register
                                    </button>
                                )}
                            </div>
                        </motion.div>
                    ))}
                </div>

                {/* See all TLDs */}
                <div className="mt-4 text-center">
                    <p className="text-xs text-text-muted">
                        {SUPPORTED_TLDS.length} TLDs available ·{" "}
                        <button
                            onClick={() => {
                                const all = SUPPORTED_TLDS.filter((t) => t !== tld);
                                // only add TLDs not already in the list
                                setSuggestions((prev) => {
                                    const existing = new Set(prev.map((r) => r.tld));
                                    const newTlds = all.filter((t) => !existing.has(t));
                                    const appended = [
                                        ...prev,
                                        ...newTlds.map((t) => ({
                                            tld: t,
                                            status: "loading" as RowStatus,
                                        })),
                                    ];
                                    void checkBatched(label, newTlds, (t, status) => {
                                        setSuggestions((s) =>
                                            s.map((row) =>
                                                row.tld === t ? { ...row, status } : row,
                                            ),
                                        );
                                    });
                                    return appended;
                                });
                            }}
                            className="text-text-secondary hover:text-text-primary transition-colors"
                        >
                            Check all TLDs
                        </button>
                    </p>
                </div>
            </div>
        </div>
    );
}
