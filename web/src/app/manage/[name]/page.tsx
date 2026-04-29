import { notFound } from "next/navigation";
import Link from "next/link";
import { Header } from "@/components/layout/Header";
import { ManageFlow } from "./ManageFlow";
import { parseName } from "@/lib/oniym";
import type { Metadata } from "next";

interface Props {
    params: Promise<{ name: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
    const { name } = await params;
    return { title: `Manage ${decodeURIComponent(name)} — Oniym` };
}

export default async function ManagePage({ params }: Props) {
    const { name } = await params;
    const decoded = decodeURIComponent(name);
    const parsed = parseName(decoded);

    if (!parsed) notFound();
    const { label, tld } = parsed;

    return (
        <>
            <Header />
            <main className="min-h-screen pt-20 pb-16 px-4">
                <div className="max-w-xl mx-auto">
                    {/* Breadcrumb */}
                    <div className="flex items-center gap-2 text-sm text-text-muted mb-8">
                        <Link href="/" className="hover:text-text-secondary transition-colors">
                            oniym
                        </Link>
                        <span>/</span>
                        <span>manage</span>
                        <span>/</span>
                        <span className="font-mono text-text-secondary">
                            {label}.{tld}
                        </span>
                    </div>

                    <div className="bg-bg-surface border border-border-dark rounded-2xl p-6 sm:p-8">
                        <div className="mb-6">
                            <h1 className="text-lg font-semibold text-text-primary">
                                Manage records
                            </h1>
                            <p className="text-sm text-text-secondary mt-1">
                                Set addresses and profile for{" "}
                                <span className="font-mono text-text-primary">
                                    {label}.{tld}
                                </span>
                            </p>
                        </div>
                        <ManageFlow label={label} tld={tld} />
                    </div>

                    <div className="mt-4 flex items-center justify-center gap-4 text-xs text-text-muted">
                        <Link
                            href={`/register/${encodeURIComponent(decoded)}`}
                            className="hover:text-text-secondary transition-colors"
                        >
                            Register another →
                        </Link>
                    </div>
                </div>
            </main>
        </>
    );
}
