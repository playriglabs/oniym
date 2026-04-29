/* eslint-disable @typescript-eslint/no-unnecessary-type-assertion */
/* eslint-disable @typescript-eslint/restrict-plus-operands */
/* eslint-disable @typescript-eslint/no-confusing-void-expression */
/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/no-unsafe-return */
/* eslint-disable @typescript-eslint/no-misused-promises */
/* eslint-disable @typescript-eslint/explicit-function-return-type */
"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
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

type SearchStatus = "idle" | "searching" | "available" | "taken" | "short";

export function SearchBar() {
    const router = useRouter();
    const inputRef = useRef<HTMLInputElement>(null);
    const tldMenuRef = useRef<HTMLDivElement>(null);

    const [query, setQuery] = useState("");
    const [tld, setTld] = useState("id");
    const [showTldMenu, setShowTldMenu] = useState(false);
    const [showAllTlds, setShowAllTlds] = useState(false);
    const [status, setStatus] = useState<SearchStatus>("idle");

    const normalizedQuery = query.toLowerCase().replace(/[^a-z0-9-]/g, "");

    useEffect(() => {
        function handleClick(e: MouseEvent) {
            if (tldMenuRef.current && !tldMenuRef.current.contains(e.target as Node)) {
                setShowTldMenu(false);
            }
        }
        document.addEventListener("mousedown", handleClick);
        return () => {
            document.removeEventListener("mousedown", handleClick);
        };
    }, []);

    useEffect(() => {
        if (!normalizedQuery) {
            setStatus("idle");
            return;
        }
        if (normalizedQuery.length < 3) {
            setStatus("short");
            return;
        }

        setStatus("searching");
        const timer = setTimeout(async () => {
            try {
                const isAvailable = await oniym.available(normalizedQuery, tld);
                setStatus(isAvailable ? "available" : "taken");
            } catch {
                setStatus("idle");
            }
        }, 450);

        return () => {
            clearTimeout(timer);
        };
    }, [normalizedQuery, tld]);

    function handleSearch() {
        if (normalizedQuery.length < 3) return;
        router.push(`/search?q=${encodeURIComponent(normalizedQuery + "." + tld)}`);
    }

    const displayTlds = showAllTlds ? SUPPORTED_TLDS : FEATURED_TLDS;

    return (
        <div className="w-full max-w-2xl mx-auto">
            {/* Search Input */}
            <div
                className={`relative flex items-center rounded-2xl transition-all duration-300 ${
                    status === "available"
                        ? "shadow-cyan-md"
                        : status === "taken"
                          ? "shadow-[0_0_0_1px_rgba(255,107,138,0.3)]"
                          : "shadow-[0_0_0_1px_rgba(255,255,255,0.06)]"
                } bg-bg-surface`}
            >
                {/* Name Input */}
                <input
                    ref={inputRef}
                    type="text"
                    value={query}
                    onChange={(e) =>
                        setQuery(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))
                    }
                    onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                    placeholder="yourname"
                    autoComplete="off"
                    autoCapitalize="none"
                    spellCheck={false}
                    maxLength={6}
                    className="flex-1 bg-transparent px-5 py-4 text-lg font-mono text-text-primary placeholder:text-text-muted outline-none min-w-0"
                />

                {/* TLD Selector */}
                <div ref={tldMenuRef} className="relative flex-shrink-0">
                    <button
                        onClick={() => setShowTldMenu(!showTldMenu)}
                        className="flex items-center gap-1.5 px-4 py-4 text-lg font-mono font-medium text-cyan hover:opacity-80 transition-opacity"
                    >
                        <span>.{tld}</span>
                        <svg
                            width="14"
                            height="14"
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
                                initial={{ opacity: 0, y: -8 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -8 }}
                                transition={{ duration: 0.15 }}
                                className="absolute top-full right-0 mt-2 w-64 bg-bg-elevated border border-border-dark rounded-xl overflow-hidden shadow-card z-50"
                            >
                                <div className="p-2 grid grid-cols-3 gap-1 max-h-64 overflow-y-auto">
                                    {displayTlds.map((t) => (
                                        <button
                                            key={t}
                                            onClick={() => {
                                                setTld(t);
                                                setShowTldMenu(false);
                                            }}
                                            className={`px-3 py-1.5 rounded-lg text-sm font-mono text-left transition-colors ${
                                                t === tld
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
                                        className="w-full px-3 py-1.5 text-xs text-text-muted hover:text-text-secondary transition-colors text-center"
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

                {/* Divider */}
                <div className="w-px h-6 bg-border-dark flex-shrink-0" />

                {/* Search button */}
                <button
                    onClick={handleSearch}
                    disabled={normalizedQuery.length < 3}
                    className="flex-shrink-0 mx-2 px-5 py-2.5 rounded-xl bg-cyan text-bg-base text-sm font-semibold disabled:opacity-30 disabled:cursor-not-allowed hover:opacity-90 active:scale-95 transition-all duration-150"
                >
                    Search
                </button>
            </div>

            {/* Status Result */}
            <AnimatePresence mode="wait">
                {status !== "idle" && (
                    <motion.div
                        key={status}
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -4 }}
                        transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
                        className="mt-3 px-1"
                    >
                        {status === "short" && (
                            <p className="text-sm text-white/50">
                                Name must be at least 3 characters.
                            </p>
                        )}

                        {status === "searching" && (
                            <div className="flex items-center gap-2 text-sm text-text-secondary">
                                <span className="w-3 h-3 rounded-full border border-text-muted border-t-transparent animate-spin" />
                                Checking availability…
                            </div>
                        )}

                        {status === "available" && (
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-2.5">
                                    <span className="flex items-center gap-1.5 text-sm font-medium text-cyan">
                                        <span className="w-2 h-2 rounded-full bg-cyan" />
                                        <span className="font-mono">
                                            {normalizedQuery}.{tld}
                                        </span>
                                        <span className="text-text-secondary font-sans">
                                            is available
                                        </span>
                                    </span>
                                </div>
                                <span className="text-sm text-text-secondary">
                                    $3 <span className="text-text-muted">/ mo</span>
                                </span>
                            </div>
                        )}

                        {status === "taken" && (
                            <div className="flex items-center gap-2.5">
                                <span className="w-2 h-2 rounded-full bg-error flex-shrink-0" />
                                <span className="text-sm text-text-secondary">
                                    <span className="font-mono text-error">
                                        {normalizedQuery}.{tld}
                                    </span>{" "}
                                    is already registered
                                </span>
                            </div>
                        )}
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
