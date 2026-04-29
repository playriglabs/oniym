/* eslint-disable @typescript-eslint/no-unnecessary-type-assertion */
/* eslint-disable @typescript-eslint/no-unsafe-argument */
/* eslint-disable @typescript-eslint/no-unsafe-return */
/* eslint-disable @typescript-eslint/explicit-function-return-type */
"use client";

import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { useState, useRef, useEffect } from "react";
import { truncateAddress } from "@/lib/oniym";

function OniymLogo() {
    return (
        <Link href="/" className="flex items-center group">
            <Image
                src="/images/oniym-light.png"
                alt="Oniym"
                width={65}
                height={25}
                className="h-7 w-auto transition-opacity group-hover:opacity-80"
                priority
            />
        </Link>
    );
}

function ConnectButton() {
    const { address, isConnected } = useAccount();
    const { connect, connectors, isPending } = useConnect();
    const { disconnect } = useDisconnect();
    const router = useRouter();
    const [showMenu, setShowMenu] = useState(false);
    const [showConnectors, setShowConnectors] = useState(false);
    const ref = useRef<HTMLDivElement>(null);

    useEffect(() => {
        function handleClick(e: MouseEvent) {
            if (ref.current && !ref.current.contains(e.target as Node)) {
                setShowMenu(false);
                setShowConnectors(false);
            }
        }
        document.addEventListener("mousedown", handleClick);
        return () => {
            document.removeEventListener("mousedown", handleClick);
        };
    }, []);

    if (isConnected && address) {
        return (
            <div ref={ref} className="relative">
                <button
                    onClick={() => setShowMenu(!showMenu)}
                    className="flex items-center gap-2 px-3.5 py-1.5 rounded-lg border border-border-dark bg-bg-surface text-sm font-mono text-text-secondary hover:border-border-cyan hover:text-text-primary transition-all duration-150"
                >
                    <span className="w-1.5 h-1.5 rounded-full bg-cyan flex-shrink-0" />
                    {truncateAddress(address)}
                </button>
                {showMenu && (
                    <div className="absolute top-full right-0 mt-1.5 w-44 bg-bg-elevated border border-border-dark rounded-xl overflow-hidden shadow-card animate-slide-up z-50">
                        <button
                            onClick={() => {
                                router.push("/profile");
                                setShowMenu(false);
                            }}
                            className="w-full px-4 py-2.5 text-sm text-left text-text-secondary hover:text-text-primary hover:bg-bg-surface transition-colors"
                        >
                            My Names
                        </button>
                        <div className="h-px bg-border-dark" />
                        <button
                            onClick={() => {
                                disconnect();
                                setShowMenu(false);
                            }}
                            className="w-full px-4 py-2.5 text-sm text-left text-text-secondary hover:text-error hover:bg-error-muted transition-colors"
                        >
                            Disconnect
                        </button>
                    </div>
                )}
            </div>
        );
    }

    return (
        <div ref={ref} className="relative">
            <button
                onClick={() => setShowConnectors(!showConnectors)}
                disabled={isPending}
                className="px-4 py-1.5 rounded-lg bg-cyan text-bg-base text-sm font-semibold hover:opacity-90 active:scale-95 transition-all duration-150 disabled:opacity-50"
            >
                {isPending ? "Connecting…" : "Connect Wallet"}
            </button>
            {showConnectors && (
                <div className="absolute top-full right-0 mt-1.5 w-52 bg-bg-elevated border border-border-dark rounded-xl overflow-hidden shadow-card animate-slide-up z-50">
                    {connectors.map((connector) => (
                        <button
                            key={connector.id}
                            onClick={() => {
                                connect({ connector });
                                setShowConnectors(false);
                            }}
                            className="w-full px-4 py-2.5 text-sm text-left text-text-secondary hover:text-text-primary hover:bg-bg-surface transition-colors flex items-center gap-2.5"
                        >
                            <span className="w-1.5 h-1.5 rounded-full bg-border-cyan bg-opacity-50 flex-shrink-0" />
                            {connector.name}
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}

export function Header() {
    const [scrolled, setScrolled] = useState(false);

    useEffect(() => {
        function onScroll() {
            setScrolled(window.scrollY > 20);
        }
        window.addEventListener("scroll", onScroll, { passive: true });
        return () => {
            window.removeEventListener("scroll", onScroll);
        };
    }, []);

    return (
        <header
            className={`fixed top-0 left-0 right-0 z-40 transition-all duration-300 ${
                scrolled
                    ? "bg-bg-base/90 backdrop-blur-xl border-b border-border-dark"
                    : "bg-transparent"
            }`}
        >
            <div className="max-w-6xl mx-auto px-4 sm:px-6 h-14 flex items-center justify-between">
                <OniymLogo />
                <nav className="hidden sm:flex items-center gap-6 text-sm text-text-secondary">
                    <Link
                        href="https://docs.oniym.xyz"
                        className="hover:text-text-primary transition-colors"
                    >
                        Docs
                    </Link>
                    <Link
                        href="https://github.com/playriglabs/oniym"
                        className="hover:text-text-primary transition-colors"
                    >
                        GitHub
                    </Link>
                </nav>
                <ConnectButton />
            </div>
        </header>
    );
}
