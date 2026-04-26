import { defineConfig } from "vocs";

export default defineConfig({
    title: "Oniym",
    description: "One name, all chains. Multichain-native naming service.",
    logoUrl: "/logo.svg",
    iconUrl: "/icon.svg",
    ogImageUrl: "https://oniym.xyz/og.png",
    theme: {
        accentColor: {
            light: "#6366f1",
            dark: "#818cf8",
        },
    },
    socials: [
        {
            icon: "github",
            link: "https://github.com/playriglabs/oniym",
        },
        {
            icon: "x",
            link: "https://x.com/oniymxyz",
        },
    ],
    sidebar: [
        {
            text: "Introduction",
            items: [
                { text: "What is Oniym?", link: "/" },
                { text: "How it works", link: "/how-it-works" },
                { text: "Supported TLDs", link: "/tlds" },
            ],
        },
        {
            text: "SDK",
            items: [
                { text: "Getting started", link: "/sdk/getting-started" },
                { text: "Oniym class", link: "/sdk/oniym" },
                { text: "Resolution", link: "/sdk/resolution" },
                { text: "Registration", link: "/sdk/registration" },
                { text: "Utilities", link: "/sdk/utilities" },
            ],
        },
        {
            text: "React Hooks",
            items: [
                { text: "Getting started", link: "/react/getting-started" },
                { text: "useResolve", link: "/react/use-resolve" },
                { text: "useName", link: "/react/use-name" },
                { text: "useAddresses", link: "/react/use-addresses" },
                { text: "useAvailable", link: "/react/use-available" },
                { text: "useRentPrice", link: "/react/use-rent-price" },
                { text: "useRegister", link: "/react/use-register" },
            ],
        },
        {
            text: "Contracts",
            items: [
                { text: "Architecture", link: "/contracts/architecture" },
                { text: "Registry", link: "/contracts/registry" },
                { text: "RegistrarController", link: "/contracts/registrar-controller" },
                { text: "PublicResolver", link: "/contracts/public-resolver" },
                { text: "ReverseRegistrar", link: "/contracts/reverse-registrar" },
                { text: "Deployments", link: "/contracts/deployments" },
            ],
        },
        {
            text: "Indexer & API",
            items: [
                { text: "Overview", link: "/api/overview" },
                { text: "GET /resolve/:name", link: "/api/resolve" },
                { text: "GET /lookup/:address", link: "/api/lookup" },
            ],
        },
        {
            text: "Design Decisions",
            items: [
                { text: "ADR-001 Base as registry chain", link: "/adr/001" },
                { text: "ADR-002 ENSIP-1 namehash", link: "/adr/002" },
                { text: "ADR-003 Monorepo structure", link: "/adr/003" },
                { text: "ADR-004 Foundry toolchain", link: "/adr/004" },
                { text: "ADR-005 Playriglabs branding", link: "/adr/005" },
                { text: "ADR-006 Pricing & controller design", link: "/adr/006" },
                { text: "ADR-007 Multi-TLD identity", link: "/adr/007" },
            ],
        },
    ],
});
