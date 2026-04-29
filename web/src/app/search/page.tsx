import { redirect } from "next/navigation";
import { Header } from "@/components/layout/Header";
import { SearchResults } from "./SearchResults";
import { parseName } from "@/lib/oniym";
import type { Metadata } from "next";

interface Props {
    searchParams: Promise<{ q?: string }>;
}

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
    const { q } = await searchParams;
    return { title: q ? `${q} — Oniym` : "Search — Oniym" };
}

export default async function SearchPage({ searchParams }: Props) {
    const { q } = await searchParams;
    if (!q) redirect("/");

    const parsed = parseName(decodeURIComponent(q));
    if (!parsed) redirect("/");

    return (
        <>
            <Header />
            <main className="min-h-screen pt-20 pb-16 px-4">
                <SearchResults label={parsed.label} tld={parsed.tld} />
            </main>
        </>
    );
}
