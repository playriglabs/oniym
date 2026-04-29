"use client";

import { useState, useEffect } from "react";
import { useAccount, useConnect, useWalletClient, useSwitchChain } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { motion, AnimatePresence } from "framer-motion";
import { oniym, truncateAddress } from "@/lib/oniym";
import type { SupportedChain } from "@oniym/sdk";
import type { Hash } from "viem";

interface Props {
    label: string;
    tld: string;
}

type TxState = "idle" | "pending" | "success" | "error";

interface FieldState {
    value: string;
    saved: string;
    txState: TxState;
    txHash: Hash | null;
    error: string | null;
}

type Tab = "addresses" | "profile";

const CHAIN_ICONS: Record<SupportedChain, string> = {
    eth: "/images/chains/eth.svg",
    btc: "/images/chains/btc.svg",
    sol: "/images/chains/sol.svg",
    sui: "/images/chains/sui.svg",
    bnb: "/images/chains/bnb.svg",
};

const CHAINS: { key: SupportedChain; label: string; placeholder: string }[] = [
    { key: "eth", label: "Ethereum", placeholder: "0x..." },
    { key: "btc", label: "Bitcoin", placeholder: "bc1q... or 1..." },
    { key: "sol", label: "Solana", placeholder: "Base58 address..." },
    { key: "sui", label: "Sui", placeholder: "0x..." },
    { key: "bnb", label: "BNB Chain", placeholder: "0x..." },
];

const SOCIALS: {
    key: string;
    label: string;
    placeholder: string;
    icon: React.ReactNode;
    prefix?: string;
}[] = [
    {
        key: "twitter",
        label: "X / Twitter",
        placeholder: "@handle",
        icon: (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.744l7.73-8.835L1.254 2.25H8.08l4.253 5.622zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
        ),
    },
    {
        key: "github",
        label: "GitHub",
        placeholder: "username",
        icon: (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0C5.374 0 0 5.373 0 12c0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23A11.509 11.509 0 0112 5.803c1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576C20.566 21.797 24 17.3 24 12c0-6.627-5.373-12-12-12z" />
            </svg>
        ),
    },
    {
        key: "discord",
        label: "Discord",
        placeholder: "username or user#0000",
        icon: (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z" />
            </svg>
        ),
    },
    {
        key: "telegram",
        label: "Telegram",
        placeholder: "@username",
        icon: (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z" />
            </svg>
        ),
    },
    {
        key: "url",
        label: "Website",
        placeholder: "https://yoursite.com",
        icon: (
            <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
            >
                <circle cx="12" cy="12" r="10" />
                <path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
            </svg>
        ),
    },
    {
        key: "email",
        label: "Email",
        placeholder: "you@example.com",
        icon: (
            <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
            >
                <rect x="2" y="4" width="20" height="16" rx="2" />
                <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
            </svg>
        ),
    },
    {
        key: "description",
        label: "Bio",
        placeholder: "A short description about you…",
        icon: (
            <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
            >
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14,2 14,8 20,8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
                <polyline points="10,9 9,9 8,9" />
            </svg>
        ),
    },
];

export function ManageFlow({ label, tld }: Props) {
    const fullName = `${label}.${tld}`;
    const { address, isConnected, chainId } = useAccount();
    const { connect, connectors } = useConnect();
    const { data: walletClient } = useWalletClient({ chainId: baseSepolia.id });
    const { switchChain, isPending: isSwitching } = useSwitchChain();
    const isWrongChain = isConnected && chainId !== baseSepolia.id;

    const [tab, setTab] = useState<Tab>("addresses");
    const [loading, setLoading] = useState(true);

    const [chainStates, setChainStates] = useState<Record<SupportedChain, FieldState>>(
        () =>
            Object.fromEntries(
                CHAINS.map((c) => [
                    c.key,
                    { value: "", saved: "", txState: "idle", txHash: null, error: null },
                ]),
            ) as Record<SupportedChain, FieldState>,
    );

    const [textStates, setTextStates] = useState<Record<string, FieldState>>(() =>
        Object.fromEntries(
            SOCIALS.map((s) => [
                s.key,
                { value: "", saved: "", txState: "idle", txHash: null, error: null },
            ]),
        ),
    );

    useEffect(() => {
        Promise.all([oniym.getAddresses(fullName), oniym.resolve(fullName)])
            .then(([addrs, result]) => {
                setChainStates((prev) => {
                    const next = { ...prev };
                    for (const c of CHAINS) {
                        const addr = addrs[c.key] ?? "";
                        next[c.key] = { ...next[c.key], value: addr, saved: addr };
                    }
                    return next;
                });
                if (result?.texts) {
                    setTextStates((prev) => {
                        const next = { ...prev };
                        for (const s of SOCIALS) {
                            const val = result.texts[s.key] ?? "";
                            next[s.key] = { ...next[s.key], value: val, saved: val };
                        }
                        return next;
                    });
                }
            })
            .catch(() => null)
            .finally(() => {
                setLoading(false);
            });
    }, [fullName]);

    function setChainField(chain: SupportedChain, value: string) {
        setChainStates((prev) => ({
            ...prev,
            [chain]: { ...prev[chain], value, txState: "idle", error: null },
        }));
    }

    function setTextField(key: string, value: string) {
        setTextStates((prev) => ({
            ...prev,
            [key]: { ...prev[key], value, txState: "idle", error: null },
        }));
    }

    async function handleSaveChain(chain: SupportedChain) {
        if (!walletClient) return;
        const addr = chainStates[chain].value.trim();
        if (!addr) return;

        setChainStates((prev) => ({
            ...prev,
            [chain]: { ...prev[chain], txState: "pending", error: null },
        }));

        try {
            const hash = await oniym.setAddress(fullName, chain, addr, walletClient);
            setChainStates((prev) => ({
                ...prev,
                [chain]: { ...prev[chain], txState: "success", txHash: hash, saved: addr },
            }));
        } catch (err) {
            const msg = err instanceof Error ? err.message : "Transaction failed";
            setChainStates((prev) => ({
                ...prev,
                [chain]: {
                    ...prev[chain],
                    txState: "error",
                    error: msg.length > 100 ? msg.slice(0, 100) + "…" : msg,
                },
            }));
        }
    }

    async function handleSaveText(key: string) {
        if (!walletClient) return;
        const val = textStates[key].value.trim();

        setTextStates((prev) => ({
            ...prev,
            [key]: { ...prev[key], txState: "pending", error: null },
        }));

        try {
            const hash = await oniym.setText(fullName, key, val, walletClient);
            setTextStates((prev) => ({
                ...prev,
                [key]: { ...prev[key], txState: "success", txHash: hash, saved: val },
            }));
        } catch (err) {
            const msg = err instanceof Error ? err.message : "Transaction failed";
            setTextStates((prev) => ({
                ...prev,
                [key]: {
                    ...prev[key],
                    txState: "error",
                    error: msg.length > 100 ? msg.slice(0, 100) + "…" : msg,
                },
            }));
        }
    }

    const switchChainBtn = (
        <button
            onClick={() => {
                switchChain({ chainId: baseSepolia.id });
            }}
            disabled={isSwitching}
            className="px-3 py-2 rounded-lg text-xs text-error border border-error/30 bg-error-muted hover:bg-error/15 transition-colors flex-shrink-0 disabled:opacity-50"
        >
            Switch chain
        </button>
    );

    if (loading) {
        return (
            <div className="flex items-center justify-center py-16 gap-3 text-text-secondary text-sm">
                <span className="w-4 h-4 rounded-full border border-text-muted border-t-transparent animate-spin" />
                Loading current records…
            </div>
        );
    }

    return (
        <div className="space-y-4">
            {/* Tabs */}
            <div className="flex gap-1 p-1 bg-bg-elevated rounded-xl border border-border-dark">
                {(["addresses", "profile"] as Tab[]).map((t) => (
                    <button
                        key={t}
                        onClick={() => {
                            setTab(t);
                        }}
                        className={`flex-1 py-1.5 rounded-lg text-sm font-medium transition-all duration-150 capitalize ${
                            tab === t
                                ? "bg-bg-surface text-text-primary shadow-sm border border-border-dark"
                                : "text-text-muted hover:text-text-secondary"
                        }`}
                    >
                        {t}
                    </button>
                ))}
            </div>

            <AnimatePresence mode="wait">
                {tab === "addresses" && (
                    <motion.div
                        key="addresses"
                        initial={{ opacity: 0, y: 6 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -6 }}
                        transition={{ duration: 0.15 }}
                        className="space-y-3"
                    >
                        {CHAINS.map((c) => {
                            const state = chainStates[c.key];
                            const dirty = state.value !== state.saved;
                            const canSave =
                                isConnected &&
                                !isWrongChain &&
                                walletClient &&
                                dirty &&
                                state.value.trim().length > 0;

                            return (
                                <div
                                    key={c.key}
                                    className="p-4 rounded-xl bg-bg-surface border border-border-dark hover:border-border-cyan transition-colors duration-150"
                                >
                                    <div className="flex items-center gap-2 mb-3">
                                        <img
                                            src={CHAIN_ICONS[c.key]}
                                            width={18}
                                            height={18}
                                            alt={c.label}
                                            style={{ objectFit: "contain" }}
                                        />
                                        <span className="text-sm font-medium text-text-primary">
                                            {c.label}
                                        </span>
                                    </div>

                                    <div className="flex gap-2">
                                        <input
                                            type="text"
                                            value={state.value}
                                            onChange={(e) => {
                                                setChainField(c.key, e.target.value);
                                            }}
                                            placeholder={c.placeholder}
                                            spellCheck={false}
                                            autoCapitalize="none"
                                            className="flex-1 bg-bg-elevated border border-border-dark rounded-lg px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-muted outline-none focus:border-border-cyan transition-colors min-w-0"
                                        />
                                        {isWrongChain ? (
                                            switchChainBtn
                                        ) : (
                                            <button
                                                onClick={() => handleSaveChain(c.key)}
                                                disabled={!canSave || state.txState === "pending"}
                                                className="px-4 py-2 rounded-lg text-sm font-medium bg-cyan text-bg-base hover:opacity-90 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed flex-shrink-0 flex items-center gap-1.5"
                                            >
                                                {state.txState === "pending" ? (
                                                    <>
                                                        <span className="w-3 h-3 rounded-full border-2 border-bg-base/30 border-t-bg-base animate-spin" />
                                                        Saving…
                                                    </>
                                                ) : (
                                                    "Save"
                                                )}
                                            </button>
                                        )}
                                    </div>

                                    <AnimatePresence>
                                        {state.txState === "success" && state.txHash && (
                                            <motion.div
                                                initial={{ opacity: 0, height: 0 }}
                                                animate={{ opacity: 1, height: "auto" }}
                                                exit={{ opacity: 0, height: 0 }}
                                                className="mt-2 overflow-hidden"
                                            >
                                                <a
                                                    href={`https://sepolia.basescan.org/tx/${state.txHash}`}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="text-xs text-cyan font-mono hover:opacity-80 transition-opacity"
                                                >
                                                    ✓ Saved · {state.txHash.slice(0, 10)}…
                                                    {state.txHash.slice(-6)} ↗
                                                </a>
                                            </motion.div>
                                        )}
                                        {state.txState === "error" && state.error && (
                                            <motion.p
                                                initial={{ opacity: 0, height: 0 }}
                                                animate={{ opacity: 1, height: "auto" }}
                                                exit={{ opacity: 0, height: 0 }}
                                                className="mt-2 text-xs text-error font-mono overflow-hidden"
                                            >
                                                {state.error}
                                            </motion.p>
                                        )}
                                    </AnimatePresence>
                                </div>
                            );
                        })}
                    </motion.div>
                )}

                {tab === "profile" && (
                    <motion.div
                        key="profile"
                        initial={{ opacity: 0, y: 6 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -6 }}
                        transition={{ duration: 0.15 }}
                        className="space-y-3"
                    >
                        {SOCIALS.map((s) => {
                            const state = textStates[s.key];
                            const dirty = state.value !== state.saved;
                            const canSave = isConnected && !isWrongChain && walletClient && dirty;

                            return (
                                <div
                                    key={s.key}
                                    className="p-4 rounded-xl bg-bg-surface border border-border-dark hover:border-border-cyan transition-colors duration-150"
                                >
                                    <div className="flex items-center gap-2 mb-3">
                                        <span className="text-text-muted flex-shrink-0">
                                            {s.icon}
                                        </span>
                                        <span className="text-sm font-medium text-text-primary">
                                            {s.label}
                                        </span>
                                        <span className="text-xs font-mono text-text-muted ml-auto">
                                            {s.key}
                                        </span>
                                    </div>

                                    <div className="flex gap-2">
                                        <input
                                            type={s.key === "email" ? "email" : "text"}
                                            value={state.value}
                                            onChange={(e) => {
                                                setTextField(s.key, e.target.value);
                                            }}
                                            placeholder={s.placeholder}
                                            spellCheck={false}
                                            className="flex-1 bg-bg-elevated border border-border-dark rounded-lg px-3 py-2 text-sm text-text-primary placeholder:text-text-muted outline-none focus:border-border-cyan transition-colors min-w-0"
                                        />
                                        {isWrongChain ? (
                                            switchChainBtn
                                        ) : (
                                            <button
                                                onClick={() => handleSaveText(s.key)}
                                                disabled={!canSave || state.txState === "pending"}
                                                className="px-4 py-2 rounded-lg text-sm font-medium bg-cyan text-bg-base hover:opacity-90 active:scale-95 transition-all disabled:opacity-30 disabled:cursor-not-allowed flex-shrink-0 flex items-center gap-1.5"
                                            >
                                                {state.txState === "pending" ? (
                                                    <>
                                                        <span className="w-3 h-3 rounded-full border-2 border-bg-base/30 border-t-bg-base animate-spin" />
                                                        Saving…
                                                    </>
                                                ) : (
                                                    "Save"
                                                )}
                                            </button>
                                        )}
                                    </div>

                                    <AnimatePresence>
                                        {state.txState === "success" && state.txHash && (
                                            <motion.div
                                                initial={{ opacity: 0, height: 0 }}
                                                animate={{ opacity: 1, height: "auto" }}
                                                exit={{ opacity: 0, height: 0 }}
                                                className="mt-2 overflow-hidden"
                                            >
                                                <a
                                                    href={`https://sepolia.basescan.org/tx/${state.txHash}`}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="text-xs text-cyan font-mono hover:opacity-80 transition-opacity"
                                                >
                                                    ✓ Saved · {state.txHash.slice(0, 10)}…
                                                    {state.txHash.slice(-6)} ↗
                                                </a>
                                            </motion.div>
                                        )}
                                        {state.txState === "error" && state.error && (
                                            <motion.p
                                                initial={{ opacity: 0, height: 0 }}
                                                animate={{ opacity: 1, height: "auto" }}
                                                exit={{ opacity: 0, height: 0 }}
                                                className="mt-2 text-xs text-error font-mono overflow-hidden"
                                            >
                                                {state.error}
                                            </motion.p>
                                        )}
                                    </AnimatePresence>
                                </div>
                            );
                        })}
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Wallet footer */}
            <div className="pt-2">
                {isConnected && address ? (
                    <p className="text-center text-xs text-text-muted font-mono">
                        {truncateAddress(address)}
                    </p>
                ) : (
                    <div className="space-y-2">
                        <p className="text-xs text-text-muted text-center">
                            Connect wallet to save changes
                        </p>
                        {connectors.slice(0, 3).map((c) => (
                            <button
                                key={c.id}
                                onClick={() => {
                                    connect({ connector: c });
                                }}
                                className="w-full py-2.5 rounded-xl border border-border-dark bg-bg-surface text-sm text-text-secondary hover:border-border-cyan hover:text-text-primary transition-all flex items-center justify-center gap-2"
                            >
                                <span className="w-1.5 h-1.5 rounded-full bg-border-dark" />
                                {c.name}
                            </button>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
