/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/explicit-function-return-type */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
/* eslint-disable @typescript-eslint/no-misused-promises */
"use client";

import { useState, useEffect, useCallback } from "react";
import { useAccount, useConnect, useWalletClient, useSwitchChain } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { motion, AnimatePresence } from "framer-motion";
import { oniym, MONTHLY_DURATION, ANNUAL_DURATION, formatEth, truncateAddress } from "@/lib/oniym";
import type { Hash } from "viem";

type Duration = "monthly" | "annual";
type PaymentToken = "eth" | "usdc";
type Step = "configure" | "committing" | "waiting" | "registering" | "success" | "error";

interface Props {
    label: string;
    tld: string;
}

function StepIndicator({ current }: { current: Step }) {
    const steps = [
        { id: "configure", label: "Configure" },
        { id: "committing", label: "Commit" },
        { id: "waiting", label: "Wait" },
        { id: "registering", label: "Register" },
        { id: "success", label: "Done" },
    ];

    const currentIdx = steps.findIndex((s) => s.id === current);

    return (
        <div className="flex items-center gap-0 mb-8">
            {steps.map((s, i) => (
                <div key={s.id} className="flex items-center">
                    <div
                        className={`flex items-center gap-1.5 ${i <= currentIdx ? "text-cyan" : "text-text-muted"}`}
                    >
                        <span
                            className={`w-5 h-5 rounded-full flex items-center justify-center text-xs font-semibold border transition-colors ${
                                i < currentIdx
                                    ? "bg-cyan border-cyan text-bg-base"
                                    : i === currentIdx
                                      ? "border-cyan text-cyan"
                                      : "border-border-dark"
                            }`}
                        >
                            {i < currentIdx ? "✓" : i + 1}
                        </span>
                        <span className="text-xs hidden sm:block">{s.label}</span>
                    </div>
                    {i < steps.length - 1 && (
                        <div
                            className={`w-8 sm:w-12 h-px mx-2 transition-colors ${i < currentIdx ? "bg-cyan/40" : "bg-border-dark"}`}
                        />
                    )}
                </div>
            ))}
        </div>
    );
}

function Countdown({ totalMs }: { totalMs: number }) {
    const [remaining, setRemaining] = useState(totalMs);

    useEffect(() => {
        const start = Date.now();
        const timer = setInterval(() => {
            const elapsed = Date.now() - start;
            const left = Math.max(0, totalMs - elapsed);
            setRemaining(left);
            if (left === 0) clearInterval(timer);
        }, 200);
        return () => {
            clearInterval(timer);
        };
    }, [totalMs]);

    const secs = Math.ceil(remaining / 1000);
    const pct = ((totalMs - remaining) / totalMs) * 100;

    return (
        <div className="flex flex-col items-center gap-3">
            <div className="relative w-16 h-16">
                <svg className="w-16 h-16 -rotate-90" viewBox="0 0 64 64">
                    <circle cx="32" cy="32" r="28" fill="none" stroke="#1e1e3a" strokeWidth="4" />
                    <circle
                        cx="32"
                        cy="32"
                        r="28"
                        fill="none"
                        stroke="#85efff"
                        strokeWidth="4"
                        strokeLinecap="round"
                        strokeDasharray={`${2 * Math.PI * 28}`}
                        strokeDashoffset={`${2 * Math.PI * 28 * (1 - pct / 100)}`}
                        className="transition-all duration-200"
                    />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center font-mono text-sm font-bold text-cyan">
                    {secs}s
                </span>
            </div>
            <p className="text-sm text-text-secondary text-center">
                Waiting for commit to age on-chain…
                <br />
                <span className="text-text-muted text-xs">
                    This prevents front-running attacks.
                </span>
            </p>
        </div>
    );
}

export function RegisterFlow({ label, tld }: Props) {
    const { address, isConnected, chainId } = useAccount();
    const { connect, connectors } = useConnect();
    const { switchChain, isPending: isSwitching } = useSwitchChain();
    const { data: walletClient, isLoading: isWalletClientLoading } = useWalletClient({
        chainId: baseSepolia.id,
    });

    const isWrongChain = isConnected && chainId !== baseSepolia.id;

    const [duration, setDuration] = useState<Duration>("annual");
    const [paymentToken, setPaymentToken] = useState<PaymentToken>("eth");
    const [reverseRecord, setReverseRecord] = useState(true);
    const [step, setStep] = useState<Step>("configure");
    const [waitMs, setWaitMs] = useState(0);
    const [txHash, setTxHash] = useState<Hash | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [ethPrice, setEthPrice] = useState<bigint | null>(null);

    const durationSecs = duration === "monthly" ? MONTHLY_DURATION : ANNUAL_DURATION;

    useEffect(() => {
        oniym.rentPrice(label, tld, durationSecs).then(setEthPrice);
    }, [label, tld, durationSecs]);

    const handleRegister = useCallback(async () => {
        if (!walletClient) {
            setError("Wallet client unavailable — check your wallet connection.");
            return;
        }
        setError(null);

        try {
            setStep("committing");
            const hash = await oniym.register(
                {
                    name: label,
                    tld,
                    duration: durationSecs,
                    paymentToken,
                    reverseRecord,
                    addresses: { eth: walletClient.account.address },
                    onCommit: () => null,
                    onWaiting: (ms) => {
                        setWaitMs(ms);
                        setStep("waiting");
                    },
                },
                walletClient,
            );
            setStep("registering");
            setTxHash(hash);
            setStep("success");
        } catch (err) {
            const msg = err instanceof Error ? err.message : "Transaction failed";
            setError(msg.length > 120 ? msg.slice(0, 120) + "…" : msg);
            setStep("error");
        }
    }, [walletClient, label, tld, durationSecs, paymentToken, reverseRecord]);

    if (step === "success" && txHash) {
        return (
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-center py-8"
            >
                <div className="w-16 h-16 rounded-full bg-cyan-muted border border-border-cyan flex items-center justify-center mx-auto mb-6">
                    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                        <path
                            d="M6 14L11 19L22 9"
                            stroke="#85efff"
                            strokeWidth="2"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        />
                    </svg>
                </div>
                <h2 className="text-2xl font-bold text-text-primary mb-2">
                    <span className="font-mono text-cyan">
                        {label}.{tld}
                    </span>{" "}
                    is yours
                </h2>
                <p className="text-text-secondary mb-6">Registration confirmed on Base.</p>
                <a
                    href={`https://sepolia.basescan.org/tx/${txHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 text-sm text-cyan hover:opacity-80 transition-opacity font-mono"
                >
                    {txHash.slice(0, 10)}…{txHash.slice(-8)} ↗
                </a>
            </motion.div>
        );
    }

    return (
        <div>
            <StepIndicator current={step} />

            {/* Name display */}
            <div className="mb-8 p-5 rounded-2xl bg-bg-surface border border-border-dark">
                <p className="text-xs text-text-muted mb-1.5">Registering</p>
                <p className="text-2xl font-mono font-bold text-text-primary">
                    {label}
                    <span className="text-cyan">.{tld}</span>
                </p>
            </div>

            <AnimatePresence mode="wait">
                {step === "configure" && (
                    <motion.div
                        key="configure"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="space-y-6"
                    >
                        {/* Duration */}
                        <div>
                            <p className="text-sm font-medium text-text-secondary mb-3">Duration</p>
                            <div className="grid grid-cols-2 gap-3">
                                {(
                                    [
                                        ["monthly", "30 days", "$3"],
                                        ["annual", "365 days", "$15"],
                                    ] as const
                                ).map(([d, days, price]) => (
                                    <button
                                        key={d}
                                        onClick={() => {
                                            setDuration(d);
                                        }}
                                        className={`p-4 rounded-xl border text-left transition-all duration-150 ${
                                            duration === d
                                                ? "border-border-cyan bg-cyan-muted"
                                                : "border-border-dark bg-bg-surface hover:border-border-cyan"
                                        }`}
                                    >
                                        <span className="block text-xs text-text-muted capitalize mb-1">
                                            {days}
                                        </span>
                                        <span
                                            className={`text-xl font-bold ${duration === d ? "text-cyan" : "text-text-primary"}`}
                                        >
                                            {price}
                                        </span>
                                        <span className="text-text-muted text-xs">
                                            {" "}
                                            / {d === "monthly" ? "mo" : "yr"}
                                        </span>
                                        {d === "annual" && (
                                            <span className="block text-xs text-cyan mt-1 font-medium">
                                                Save 2 months
                                            </span>
                                        )}
                                    </button>
                                ))}
                            </div>
                        </div>

                        {/* Payment */}
                        <div>
                            <p className="text-sm font-medium text-text-secondary mb-3">Payment</p>
                            <div className="grid grid-cols-2 gap-3">
                                {(
                                    [
                                        ["eth", "ETH", "Price varies with market"],
                                        ["usdc", "USDC", "Exact $3 or $15 — no slippage"],
                                    ] as const
                                ).map(([token, label, desc]) => (
                                    <button
                                        key={token}
                                        onClick={() => {
                                            setPaymentToken(token);
                                        }}
                                        className={`p-4 rounded-xl border text-left transition-all duration-150 ${
                                            paymentToken === token
                                                ? "border-border-cyan bg-cyan-muted"
                                                : "border-border-dark bg-bg-surface hover:border-border-cyan"
                                        }`}
                                    >
                                        <span
                                            className={`block text-sm font-mono font-semibold mb-1 ${paymentToken === token ? "text-cyan" : "text-text-primary"}`}
                                        >
                                            {label}
                                        </span>
                                        <span className="block text-xs text-text-muted leading-snug">
                                            {desc}
                                        </span>
                                    </button>
                                ))}
                            </div>
                        </div>

                        {/* Reverse record */}
                        <div>
                            <button
                                onClick={() => {
                                    setReverseRecord(!reverseRecord);
                                }}
                                className="flex items-center gap-3 w-full p-4 rounded-xl border border-border-dark bg-bg-surface hover:border-border-cyan transition-colors text-left"
                            >
                                <span
                                    className={`w-4 h-4 rounded border flex items-center justify-center flex-shrink-0 transition-colors ${
                                        reverseRecord ? "bg-cyan border-cyan" : "border-border-dark"
                                    }`}
                                >
                                    {reverseRecord && (
                                        <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                                            <path
                                                d="M2 5L4.5 7.5L8 3"
                                                stroke="#0a0a0f"
                                                strokeWidth="1.5"
                                                strokeLinecap="round"
                                                strokeLinejoin="round"
                                            />
                                        </svg>
                                    )}
                                </span>
                                <div>
                                    <p className="text-sm font-medium text-text-primary">
                                        Set as primary name
                                    </p>
                                    <p className="text-xs text-text-muted mt-0.5">
                                        Maps your wallet address → this name (reverse resolution)
                                    </p>
                                </div>
                            </button>
                        </div>

                        {/* Price summary */}
                        {ethPrice !== null && paymentToken === "eth" && (
                            <div className="flex items-center justify-between p-4 rounded-xl bg-bg-surface border border-border-dark">
                                <span className="text-sm text-text-secondary">Total</span>
                                <span className="font-mono text-text-primary font-semibold">
                                    {formatEth(ethPrice)} ETH
                                    <span className="text-text-muted font-normal text-xs ml-1.5">
                                        (~{duration === "monthly" ? "$3" : "$15"})
                                    </span>
                                </span>
                            </div>
                        )}
                        {paymentToken === "usdc" && (
                            <div className="flex items-center justify-between p-4 rounded-xl bg-bg-surface border border-border-dark">
                                <span className="text-sm text-text-secondary">Total</span>
                                <span className="font-mono text-text-primary font-semibold">
                                    {duration === "monthly" ? "3.00" : "15.00"} USDC
                                </span>
                            </div>
                        )}

                        {/* Error banner */}
                        {error && (
                            <div className="p-3 rounded-xl bg-error-muted border border-error/20 text-xs text-error font-mono break-all">
                                {error}
                            </div>
                        )}

                        {/* CTA */}
                        {isConnected && address ? (
                            <div className="space-y-3">
                                {isWrongChain ? (
                                    <button
                                        onClick={() => {
                                            switchChain({ chainId: baseSepolia.id });
                                        }}
                                        disabled={isSwitching}
                                        className="w-full py-3.5 rounded-xl bg-error/10 border border-error/30 text-error text-sm font-semibold hover:bg-error/20 transition-all duration-150 disabled:opacity-50"
                                    >
                                        {isSwitching ? "Switching…" : "Switch to Base Sepolia"}
                                    </button>
                                ) : (
                                    <button
                                        onClick={handleRegister}
                                        disabled={isWalletClientLoading}
                                        className="w-full py-3.5 rounded-xl bg-cyan text-bg-base font-semibold hover:opacity-90 active:scale-[0.99] transition-all duration-150 disabled:opacity-50 flex items-center justify-center gap-2"
                                    >
                                        {isWalletClientLoading ? (
                                            <>
                                                <span className="w-4 h-4 rounded-full border-2 border-bg-base/40 border-t-bg-base animate-spin" />
                                                Loading…
                                            </>
                                        ) : (
                                            <>
                                                Register {label}.{tld}
                                            </>
                                        )}
                                    </button>
                                )}
                                <p className="text-center text-xs text-text-muted font-mono">
                                    {truncateAddress(address)}
                                </p>
                            </div>
                        ) : (
                            <div className="space-y-3">
                                <p className="text-sm text-text-muted text-center mb-3">
                                    Connect your wallet to register
                                </p>
                                {connectors.slice(0, 3).map((c) => (
                                    <button
                                        key={c.id}
                                        onClick={() => {
                                            connect({ connector: c });
                                        }}
                                        className="w-full py-3 rounded-xl border border-border-dark bg-bg-surface text-sm font-medium text-text-secondary hover:border-border-cyan hover:text-text-primary transition-all duration-150 flex items-center justify-center gap-2"
                                    >
                                        <span className="w-1.5 h-1.5 rounded-full bg-border-dark" />
                                        {c.name}
                                    </button>
                                ))}
                            </div>
                        )}
                    </motion.div>
                )}

                {(step === "committing" || step === "registering") && (
                    <motion.div
                        key="progress"
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="flex flex-col items-center py-12 gap-4"
                    >
                        <div className="w-10 h-10 rounded-full border-2 border-cyan border-t-transparent animate-spin" />
                        <p className="text-text-secondary text-sm">
                            {step === "committing" ? "Submitting commitment…" : "Registering name…"}
                        </p>
                        <p className="text-xs text-text-muted">
                            Check your wallet for a signing prompt
                        </p>
                    </motion.div>
                )}

                {step === "waiting" && (
                    <motion.div
                        key="waiting"
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="flex flex-col items-center py-8"
                    >
                        <Countdown totalMs={waitMs} />
                    </motion.div>
                )}

                {step === "error" && (
                    <motion.div
                        key="error"
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="space-y-4"
                    >
                        <div className="p-4 rounded-xl bg-error-muted border border-error/20">
                            <p className="text-sm text-error font-medium mb-1">
                                Registration failed
                            </p>
                            <p className="text-xs text-text-secondary font-mono break-all">
                                {error}
                            </p>
                        </div>
                        <button
                            onClick={() => {
                                setStep("configure");
                            }}
                            className="w-full py-3 rounded-xl border border-border-dark text-sm text-text-secondary hover:border-border-cyan hover:text-text-primary transition-all"
                        >
                            Try again
                        </button>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}
