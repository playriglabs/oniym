"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { oniym } from "@/lib/oniym";

const DROPDOWN_TLDS = ["id", "me", "web3", "xyz", "app", "wagmi", "degen", "gm", "one", "co"];

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
};

type TldStatus = "idle" | "checking" | "available" | "taken";

interface TldResult {
    tld: string;
    status: TldStatus;
}

export function SearchBar() {
    const router = useRouter();
    const inputRef = useRef<HTMLInputElement>(null);
    const containerRef = useRef<HTMLDivElement>(null);

    const [query, setQuery] = useState("");
    const [focused, setFocused] = useState(false);
    const [results, setResults] = useState<TldResult[]>(
        DROPDOWN_TLDS.map((tld) => ({ tld, status: "idle" })),
    );

    const normalizedQuery = query.toLowerCase().replace(/[^a-z0-9-]/g, "");
    const showDropdown = focused && normalizedQuery.length >= 3;

    useEffect(() => {
        if (normalizedQuery.length < 3) {
            setResults(DROPDOWN_TLDS.map((tld) => ({ tld, status: "idle" })));
            return;
        }

        setResults(DROPDOWN_TLDS.map((tld) => ({ tld, status: "checking" })));

        const timer = setTimeout(() => {
            DROPDOWN_TLDS.forEach((tld) => {
                void oniym.available(normalizedQuery, tld).then((isAvailable) => {
                    setResults((prev) =>
                        prev.map((r) =>
                            r.tld === tld ? { tld, status: isAvailable ? "available" : "taken" } : r,
                        ),
                    );
                }).catch(() => {
                    setResults((prev) =>
                        prev.map((r) => (r.tld === tld ? { tld, status: "idle" } : r)),
                    );
                });
            });
        }, 400);

        return () => clearTimeout(timer);
    }, [normalizedQuery]);

    useEffect(() => {
        function handleClick(e: MouseEvent) {
            if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
                setFocused(false);
            }
        }
        document.addEventListener("mousedown", handleClick);
        return () => document.removeEventListener("mousedown", handleClick);
    }, []);

    function handleSearch() {
        if (normalizedQuery.length < 3) return;
        router.push(`/search?q=${encodeURIComponent(normalizedQuery + ".id")}`);
    }

    function handleSelectTld(tld: string) {
        if (normalizedQuery.length < 3) return;
        router.push(`/register/${encodeURIComponent(normalizedQuery + "." + tld)}`);
    }

    return (
        <div ref={containerRef} className="w-full max-w-2xl mx-auto relative">
            {/* Search input */}
            <div
                className={`relative flex items-center rounded-2xl transition-all duration-200 bg-bg-surface ${
                    focused
                        ? "shadow-[0_0_0_1.5px_rgba(133,239,255,0.35),0_0_24px_rgba(133,239,255,0.06)]"
                        : "shadow-[0_0_0_1px_rgba(255,255,255,0.06)]"
                }`}
            >
                <input
                    ref={inputRef}
                    type="text"
                    value={query}
                    onChange={(e) =>
                        setQuery(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))
                    }
                    onFocus={() => setFocused(true)}
                    onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                    placeholder="yourname"
                    autoComplete="off"
                    autoCapitalize="none"
                    spellCheck={false}
                    className="flex-1 bg-transparent px-5 py-4 text-lg font-mono text-text-primary placeholder:text-text-muted outline-none min-w-0"
                />

                <div className="w-px h-6 bg-border-dark flex-shrink-0" />

                <button
                    onClick={handleSearch}
                    disabled={normalizedQuery.length < 3}
                    className="flex-shrink-0 mx-2 px-5 py-2.5 rounded-xl bg-cyan text-bg-base text-sm font-semibold disabled:opacity-30 disabled:cursor-not-allowed hover:opacity-90 active:scale-95 transition-all duration-150"
                >
                    Search
                </button>
            </div>

            {/* Multi-TLD dropdown */}
            <AnimatePresence>
                {showDropdown && (
                    <motion.div
                        initial={{ opacity: 0, y: -6, scale: 0.99 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: -6, scale: 0.99 }}
                        transition={{ duration: 0.16, ease: [0.16, 1, 0.3, 1] }}
                        className="absolute top-full left-0 right-0 mt-2 bg-bg-elevated border border-border-dark rounded-2xl overflow-hidden z-50"
                        style={{ boxShadow: "0 8px 32px rgba(0,0,0,0.5), 0 1px 0 rgba(255,255,255,0.03) inset" }}
                    >
                        {/* Header */}
                        <div className="px-4 pt-3 pb-2">
                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">
                                Domains
                            </span>
                        </div>

                        {/* Results */}
                        <div className="pb-1">
                            {results.map((result, i) => {
                                const meta = TLD_META[result.tld] ?? TLD_META.id;
                                const isAvailable = result.status === "available";
                                const isTaken = result.status === "taken";
                                const isChecking = result.status === "checking";

                                return (
                                    <motion.button
                                        key={result.tld}
                                        initial={{ opacity: 0 }}
                                        animate={{ opacity: 1 }}
                                        transition={{ delay: i * 0.025 }}
                                        onClick={() => isAvailable && handleSelectTld(result.tld)}
                                        className={`w-full flex items-center gap-3 px-4 py-2.5 transition-colors group ${
                                            isAvailable
                                                ? "hover:bg-white/[0.03] cursor-pointer"
                                                : "cursor-default"
                                        } ${isTaken ? "opacity-40" : ""}`}
                                    >
                                        {/* TLD badge */}
                                        <div
                                            className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 text-[11px] font-mono font-bold"
                                            style={{ background: meta.bg, color: meta.color }}
                                        >
                                            .{result.tld.length > 3 ? result.tld.slice(0, 3) : result.tld}
                                        </div>

                                        {/* Name + label */}
                                        <div className="flex-1 text-left min-w-0">
                                            <div className="text-sm font-mono font-medium text-text-primary leading-tight">
                                                <span>{normalizedQuery}</span>
                                                <span style={{ color: meta.color }}>.{result.tld}</span>
                                            </div>
                                            <div className="text-xs text-text-muted mt-0.5">{meta.label}</div>
                                        </div>

                                        {/* Status */}
                                        <div className="flex items-center gap-2 flex-shrink-0">
                                            {isChecking && (
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

                        {/* Footer */}
                        <div className="border-t border-border-dark px-4 py-3">
                            <button
                                onClick={handleSearch}
                                className="text-xs text-text-muted hover:text-text-secondary transition-colors"
                            >
                                See all results for{" "}
                                <span className="font-mono" style={{ color: "#85efff" }}>
                                    {normalizedQuery}
                                </span>{" "}
                                →
                            </button>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Short query hint */}
            <AnimatePresence>
                {normalizedQuery.length > 0 && normalizedQuery.length < 3 && (
                    <motion.p
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="mt-3 px-1 text-sm text-white/40"
                    >
                        Name must be at least 3 characters.
                    </motion.p>
                )}
            </AnimatePresence>
        </div>
    );
}
