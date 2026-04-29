"use client";

import { useEffect, useState } from "react";
import { useAccount, useConnect } from "wagmi";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import Link from "next/link";
import { Header } from "@/components/layout/Header";
import { oniym, truncateAddress } from "@/lib/oniym";
import type { OwnedName } from "@oniym/sdk";

export default function ProfilePage() {
    const { address, isConnected } = useAccount();
    const { connect, connectors } = useConnect();
    const router = useRouter();

    const [names, setNames] = useState<OwnedName[]>([]);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (!address) return;
        setLoading(true);
        oniym
            .getNames(address)
            .then(setNames)
            .catch(() => setNames([]))
            .finally(() => setLoading(false));
    }, [address]);

    const active = names.filter((n) => !n.expired);
    const expired = names.filter((n) => n.expired);

    return (
        <>
            <Header />
            <main className="min-h-screen pt-20 pb-16 px-4">
                <div className="max-w-2xl mx-auto">
                    {/* Breadcrumb */}
                    <div className="flex items-center gap-2 text-sm text-text-muted mb-8">
                        <Link href="/" className="hover:text-text-secondary transition-colors">
                            oniym
                        </Link>
                        <span>/</span>
                        <span>profile</span>
                        {address && (
                            <>
                                <span>/</span>
                                <span className="font-mono text-text-secondary">
                                    {truncateAddress(address)}
                                </span>
                            </>
                        )}
                    </div>

                    {!isConnected ? (
                        <div className="bg-bg-surface border border-border-dark rounded-2xl p-8 text-center">
                            <p className="text-text-secondary text-sm mb-6">
                                Connect wallet to view your names
                            </p>
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
                        <div className="flex items-center justify-center py-20 gap-3 text-text-secondary text-sm">
                            <span className="w-4 h-4 rounded-full border border-text-muted border-t-transparent animate-spin" />
                            Loading your names…
                        </div>
                    ) : names.length === 0 ? (
                        <div className="bg-bg-surface border border-border-dark rounded-2xl p-8 text-center">
                            <p className="text-text-secondary text-sm mb-4">
                                No names registered yet.
                            </p>
                            <button
                                onClick={() => router.push("/")}
                                className="px-5 py-2 rounded-xl bg-cyan text-bg-base text-sm font-semibold hover:opacity-90 transition-all"
                            >
                                Register your first name
                            </button>
                        </div>
                    ) : (
                        <div className="space-y-6">
                            {/* Active names */}
                            {active.length > 0 && (
                                <div>
                                    <p className="text-xs font-medium text-text-muted uppercase tracking-widest mb-3">
                                        Active · {active.length}
                                    </p>
                                    <div className="space-y-2">
                                        {active.map((name, i) => (
                                            <NameRow key={name.node} name={name} index={i} />
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* Expired names */}
                            {expired.length > 0 && (
                                <div>
                                    <p className="text-xs font-medium text-text-muted uppercase tracking-widest mb-3">
                                        Expired · {expired.length}
                                    </p>
                                    <div className="space-y-2">
                                        {expired.map((name, i) => (
                                            <NameRow
                                                key={name.node}
                                                name={name}
                                                index={i}
                                                expired
                                            />
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </main>
        </>
    );
}

function NameRow({
    name,
    index,
    expired = false,
}: {
    name: OwnedName;
    index: number;
    expired?: boolean;
}) {
    const router = useRouter();

    const expiresAt = new Date(Number(name.expiresAt) * 1000);
    const expiresLabel = expired
        ? `Expired ${expiresAt.toLocaleDateString()}`
        : `Expires ${expiresAt.toLocaleDateString()}`;

    return (
        <motion.div
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2, delay: index * 0.04 }}
            className={`flex items-center justify-between gap-4 px-4 py-3.5 rounded-xl border transition-colors ${
                expired
                    ? "bg-bg-surface border-border-dark opacity-50"
                    : "bg-bg-surface border-border-dark hover:border-border-cyan"
            }`}
        >
            <div className="flex items-center gap-3 min-w-0">
                <span
                    className={`w-2 h-2 rounded-full flex-shrink-0 ${expired ? "bg-border-dark" : "bg-cyan"}`}
                />
                <span className="font-mono text-sm text-text-primary truncate">{name.name}</span>
                <span className="text-xs text-text-muted flex-shrink-0">{expiresLabel}</span>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0">
                {expired ? (
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
}
