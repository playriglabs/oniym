"use client";

import { useEffect, useState } from "react";
import { useAccount, useConnect } from "wagmi";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { Header } from "@/components/layout/Header";
import { oniym, truncateAddress } from "@/lib/oniym";
import type { OwnedName } from "@oniym/sdk";

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

type ViewMode = "list" | "grid";
type FilterMode = "all" | "active" | "expired";

function getTld(name: string): string {
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(dot + 1) : "";
}

function getLabel(name: string): string {
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(0, dot) : name;
}

function TldBadge({ tld, size = 40 }: { tld: string; size?: number }) {
    const meta = TLD_META[tld] ?? FALLBACK_META;
    const short = tld.length > 4 ? tld.slice(0, 4) : tld;
    return (
        <div
            className="rounded-xl flex items-center justify-center flex-shrink-0 text-[11px] font-mono font-bold"
            style={{ width: size, height: size, background: meta.bg, color: meta.color }}
        >
            .{short}
        </div>
    );
}

function ExpiryLabel({ expiresAt, expired }: { expiresAt: bigint; expired: boolean }) {
    const date = new Date(Number(expiresAt) * 1000);
    const formatted = date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    return (
        <span className={`text-xs ${expired ? "text-error/70" : "text-text-muted"}`}>
            {expired ? "Expired" : "Expires"} {formatted}
        </span>
    );
}

export default function ProfilePage() {
    const { address, isConnected } = useAccount();
    const { connect, connectors } = useConnect();
    const router = useRouter();

    const [names, setNames] = useState<OwnedName[]>([]);
    const [loading, setLoading] = useState(false);
    const [view, setView] = useState<ViewMode>("list");
    const [filter, setFilter] = useState<FilterMode>("all");

    useEffect(() => {
        if (!address) return;
        setLoading(true);
        void oniym
            .getNames(address)
            .then(setNames)
            .catch(() => setNames([]))
            .finally(() => setLoading(false));
    }, [address]);

    const active = names.filter((n) => !n.expired);
    const expired = names.filter((n) => n.expired);

    const filteredNames = names.filter((n) => {
        if (filter === "active") return !n.expired;
        if (filter === "expired") return n.expired;
        return true;
    });

    return (
        <>
            <Header />
            <main className="min-h-screen pt-20 pb-16 px-4">
                <div className="max-w-3xl mx-auto">
                    {/* Breadcrumb */}
                    <div className="flex items-center gap-2 text-xs text-text-muted mb-6">
                        <Link href="/" className="hover:text-text-secondary transition-colors">oniym</Link>
                        <span>/</span>
                        <Link href="/profile" className="hover:text-text-secondary transition-colors">profile</Link>
                        {address && (
                            <>
                                <span>/</span>
                                <span className="font-mono text-text-secondary">{truncateAddress(address)}</span>
                            </>
                        )}
                    </div>

                    {!isConnected ? (
                        <div className="bg-bg-surface border border-border-dark rounded-2xl p-10 text-center">
                            <div className="w-12 h-12 rounded-2xl bg-cyan-muted border border-border-cyan flex items-center justify-center mx-auto mb-5">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                                    <rect x="2" y="6" width="16" height="11" rx="2" stroke="#85efff" strokeWidth="1.5"/>
                                    <path d="M6 6V5a4 4 0 0 1 8 0v1" stroke="#85efff" strokeWidth="1.5" strokeLinecap="round"/>
                                    <circle cx="10" cy="12" r="1.5" fill="#85efff"/>
                                </svg>
                            </div>
                            <p className="text-text-primary font-medium mb-1">Connect your wallet</p>
                            <p className="text-text-muted text-sm mb-6">View and manage your registered names</p>
                            <div className="flex flex-col gap-2 max-w-xs mx-auto">
                                {connectors.slice(0, 3).map((c) => (
                                    <button
                                        key={c.id}
                                        onClick={() => connect({ connector: c })}
                                        className="w-full py-2.5 rounded-xl border border-border-dark bg-bg-elevated text-sm text-text-secondary hover:border-border-cyan hover:text-text-primary transition-all flex items-center justify-center gap-2"
                                    >
                                        <span className="w-1.5 h-1.5 rounded-full bg-border-dark" />
                                        {c.name}
                                    </button>
                                ))}
                            </div>
                        </div>
                    ) : loading ? (
                        <div className="flex items-center justify-center py-24 gap-3 text-text-secondary text-sm">
                            <span className="w-4 h-4 rounded-full border border-text-muted border-t-transparent animate-spin" />
                            Loading your names…
                        </div>
                    ) : names.length === 0 ? (
                        <div className="bg-bg-surface border border-border-dark rounded-2xl p-10 text-center">
                            <p className="text-text-secondary text-sm mb-4">No names registered yet.</p>
                            <button
                                onClick={() => router.push("/")}
                                className="px-5 py-2.5 rounded-xl bg-cyan text-bg-base text-sm font-semibold hover:opacity-90 transition-all"
                            >
                                Register your first name
                            </button>
                        </div>
                    ) : (
                        <div>
                            {/* Stats */}
                            <div className="grid grid-cols-3 gap-3 mb-6">
                                {[
                                    { label: "Total", value: names.length },
                                    { label: "Active", value: active.length, accent: true },
                                    { label: "Expired", value: expired.length, warn: expired.length > 0 },
                                ].map((s) => (
                                    <div
                                        key={s.label}
                                        className="p-4 rounded-2xl bg-bg-surface border border-border-dark text-center"
                                    >
                                        <div className={`text-2xl font-bold font-mono ${s.accent ? "text-cyan" : s.warn ? "text-error" : "text-text-primary"}`}>
                                            {s.value}
                                        </div>
                                        <div className="text-xs text-text-muted mt-0.5">{s.label}</div>
                                    </div>
                                ))}
                            </div>

                            {/* Toolbar */}
                            <div className="flex items-center justify-between mb-4">
                                <div className="flex items-center rounded-lg border border-white/10 overflow-hidden bg-bg-surface">
                                    {(["all", "active", "expired"] as FilterMode[]).map((f) => (
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

                                <div className="flex items-center rounded-lg border border-white/10 overflow-hidden bg-bg-surface">
                                    <button
                                        onClick={() => setView("list")}
                                        className={`w-8 h-8 flex items-center justify-center transition-colors ${view === "list" ? "bg-cyan text-bg-base" : "text-text-muted hover:text-text-secondary"}`}
                                    >
                                        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                                            <rect x="1" y="2" width="12" height="2" rx="1" fill="currentColor"/>
                                            <rect x="1" y="6" width="12" height="2" rx="1" fill="currentColor"/>
                                            <rect x="1" y="10" width="12" height="2" rx="1" fill="currentColor"/>
                                        </svg>
                                    </button>
                                    <button
                                        onClick={() => setView("grid")}
                                        className={`w-8 h-8 flex items-center justify-center transition-colors ${view === "grid" ? "bg-cyan text-bg-base" : "text-text-muted hover:text-text-secondary"}`}
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

                            {/* Names */}
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
                                        <div className="grid grid-cols-[1fr_auto_auto] sm:grid-cols-[1fr_140px_auto_auto] gap-4 px-4 py-2.5 border-b border-border-dark bg-bg-surface/50">
                                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">Name</span>
                                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest hidden sm:block">Expiry</span>
                                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest">Status</span>
                                            <span className="text-[11px] font-semibold text-text-muted uppercase tracking-widest"></span>
                                        </div>

                                        {filteredNames.map((name, i) => {
                                            const tld = getTld(name.name);
                                            const label = getLabel(name.name);
                                            const meta = TLD_META[tld] ?? FALLBACK_META;

                                            return (
                                                <motion.div
                                                    key={name.node}
                                                    initial={{ opacity: 0 }}
                                                    animate={{ opacity: 1 }}
                                                    transition={{ delay: Math.min(i * 0.04, 0.3) }}
                                                    className={`grid grid-cols-[1fr_auto_auto] sm:grid-cols-[1fr_140px_auto_auto] gap-4 items-center px-4 py-3 border-b border-border-dark/60 last:border-b-0 hover:bg-white/[0.02] transition-colors ${name.expired ? "opacity-50" : ""}`}
                                                >
                                                    <div className="flex items-center gap-3 min-w-0">
                                                        <TldBadge tld={tld} size={34} />
                                                        <div className="min-w-0">
                                                            <div className="font-mono text-sm font-medium text-text-primary truncate">
                                                                {label}
                                                                <span style={{ color: meta.color }}>.{tld}</span>
                                                            </div>
                                                            <div className="text-[11px] text-text-muted">{meta.label}</div>
                                                        </div>
                                                    </div>

                                                    <div className="hidden sm:block">
                                                        <ExpiryLabel expiresAt={name.expiresAt} expired={name.expired} />
                                                    </div>

                                                    <div>
                                                        {name.expired ? (
                                                            <span className="text-[11px] font-bold tracking-widest uppercase text-error/70">Expired</span>
                                                        ) : (
                                                            <span className="text-[11px] font-bold tracking-widest uppercase text-cyan">Active</span>
                                                        )}
                                                    </div>

                                                    <div>
                                                        {name.expired ? (
                                                            <button
                                                                onClick={() => router.push(`/register/${encodeURIComponent(name.name)}`)}
                                                                className="px-3 py-1 rounded-lg bg-cyan text-bg-base text-xs font-semibold hover:opacity-90 active:scale-95 transition-all"
                                                            >
                                                                Renew
                                                            </button>
                                                        ) : (
                                                            <button
                                                                onClick={() => router.push(`/manage/${encodeURIComponent(name.name)}`)}
                                                                className="px-3 py-1 rounded-lg border border-border-cyan text-cyan text-xs font-medium hover:bg-cyan-muted active:scale-95 transition-all"
                                                            >
                                                                Manage
                                                            </button>
                                                        )}
                                                    </div>
                                                </motion.div>
                                            );
                                        })}
                                    </motion.div>
                                )}

                                {view === "grid" && (
                                    <motion.div
                                        key="grid"
                                        initial={{ opacity: 0 }}
                                        animate={{ opacity: 1 }}
                                        exit={{ opacity: 0 }}
                                        transition={{ duration: 0.15 }}
                                        className="grid grid-cols-2 gap-3"
                                    >
                                        {filteredNames.map((name, i) => {
                                            const tld = getTld(name.name);
                                            const label = getLabel(name.name);
                                            const meta = TLD_META[tld] ?? FALLBACK_META;

                                            return (
                                                <motion.div
                                                    key={name.node}
                                                    initial={{ opacity: 0, y: 8 }}
                                                    animate={{ opacity: 1, y: 0 }}
                                                    transition={{ delay: Math.min(i * 0.05, 0.3) }}
                                                    className={`p-4 rounded-2xl border border-border-dark bg-bg-surface transition-colors hover:border-border-cyan ${name.expired ? "opacity-50" : ""}`}
                                                >
                                                    <div className="flex items-center gap-3 mb-4">
                                                        <TldBadge tld={tld} size={36} />
                                                        <div className="min-w-0">
                                                            <div className="font-mono text-sm font-medium text-text-primary truncate">
                                                                {label}
                                                                <span style={{ color: meta.color }}>.{tld}</span>
                                                            </div>
                                                            <div className="text-[11px] text-text-muted mt-0.5">{meta.label}</div>
                                                        </div>
                                                    </div>

                                                    <ExpiryLabel expiresAt={name.expiresAt} expired={name.expired} />

                                                    <div className="flex items-center justify-between mt-3">
                                                        {name.expired ? (
                                                            <span className="text-[11px] font-bold tracking-widest uppercase text-error/70">Expired</span>
                                                        ) : (
                                                            <span className="text-[11px] font-bold tracking-widest uppercase text-cyan">Active</span>
                                                        )}
                                                        {name.expired ? (
                                                            <button
                                                                onClick={() => router.push(`/register/${encodeURIComponent(name.name)}`)}
                                                                className="px-3 py-1 rounded-lg bg-cyan text-bg-base text-xs font-semibold hover:opacity-90 active:scale-95 transition-all"
                                                            >
                                                                Renew
                                                            </button>
                                                        ) : (
                                                            <button
                                                                onClick={() => router.push(`/manage/${encodeURIComponent(name.name)}`)}
                                                                className="px-3 py-1 rounded-lg border border-border-cyan text-cyan text-xs font-medium hover:bg-cyan-muted active:scale-95 transition-all"
                                                            >
                                                                Manage
                                                            </button>
                                                        )}
                                                    </div>
                                                </motion.div>
                                            );
                                        })}
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>
                    )}
                </div>
            </main>
        </>
    );
}
