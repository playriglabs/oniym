/* eslint-disable @typescript-eslint/explicit-function-return-type */
import { notFound } from "next/navigation";
import Link from "next/link";
import { Header } from "@/components/layout/Header";
import { RegisterFlow } from "./RegisterFlow";
import { parseName } from "@/lib/oniym";
import type { Metadata } from "next";

interface Props {
    params: Promise<{ name: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
    const { name } = await params;
    const decoded = decodeURIComponent(name);
    return {
        title: `Register ${decoded} — Oniym`,
        description: `Register the multichain name ${decoded} on Oniym. From $3/month.`,
    };
}

export default async function RegisterPage({ params }: Props) {
    const { name } = await params;
    const decoded = decodeURIComponent(name);
    const parsed = parseName(decoded);

    if (!parsed) notFound();

    const { label, tld } = parsed;

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
                        <span>register</span>
                        <span>/</span>
                        <span className="font-mono text-text-secondary">
                            {label}.{tld}
                        </span>
                    </div>

                    {/* Card */}
                    <div className="bg-bg-surface border border-border-dark rounded-2xl p-6 sm:p-8">
                        <h1 className="text-lg font-semibold text-text-primary mb-6">
                            Register name
                        </h1>
                        <RegisterFlow label={label} tld={tld} />
                    </div>

                    {/* How it works note */}
                    <div className="mt-6 p-4 rounded-xl border border-border-dark bg-bg-surface/50">
                        <p className="text-xs font-semibold text-text-muted uppercase tracking-widest mb-3">
                            How registration works
                        </p>
                        <ol className="space-y-2">
                            {[
                                "Commit — a hash is stored on-chain to prevent front-running",
                                "Wait 60 seconds — the minimum commitment age",
                                "Register — your name is minted and resolver data is set",
                            ].map((step, i) => (
                                <li
                                    key={i}
                                    className="flex items-start gap-2.5 text-xs text-text-secondary"
                                >
                                    <span className="w-4 h-4 rounded-full bg-bg-elevated border border-border-dark flex items-center justify-center text-[10px] text-text-muted flex-shrink-0 mt-0.5">
                                        {i + 1}
                                    </span>
                                    {step}
                                </li>
                            ))}
                        </ol>
                    </div>
                </div>
            </main>
        </>
    );
}
