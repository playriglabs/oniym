import type { Metadata } from "next";
import { DM_Sans, Fira_Code } from "next/font/google";
import { Providers } from "@/providers/Providers";
import "./globals.css";

const dmSans = DM_Sans({
    subsets: ["latin"],
    variable: "--font-sans",
    display: "swap",
});

const firaCode = Fira_Code({
    subsets: ["latin"],
    variable: "--font-mono",
    display: "swap",
});

export const metadata: Metadata = {
    title: "Oniym — One name. Every chain.",
    description:
        "Register once on Base. Resolve to Ethereum, Solana, Bitcoin, and beyond. 65 TLDs from $3/month.",
    openGraph: {
        title: "Oniym — One name. Every chain.",
        description:
            "Multichain-native naming service. Register .id, .me, .wagmi, .degen, and 61 more.",
        url: "https://oniym.xyz",
        siteName: "Oniym",
        images: [{ url: "https://oniym.xyz/og.png", width: 1200, height: 630 }],
        type: "website",
    },
    twitter: {
        card: "summary_large_image",
        title: "Oniym — One name. Every chain.",
        description: "Multichain-native naming service. From $3/month.",
        site: "@oniymxyz",
    },
    metadataBase: new URL("https://oniym.xyz"),
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
    return (
        <html lang="en" className={`${dmSans.variable} ${firaCode.variable}`}>
            <body
                className="font-sans text-text-primary antialiased"
                style={{
                    background:
                        "radial-gradient(ellipse at 50% 30%, #0d2b32 0%, #091520 50%, #060a10 100%) fixed, #060a10",
                }}
            >
                <Providers>{children}</Providers>
            </body>
        </html>
    );
}
