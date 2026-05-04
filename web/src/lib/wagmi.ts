import { createConfig, http } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { coinbaseWallet, injected, walletConnect } from "wagmi/connectors";

const projectId = process.env.NEXT_PUBLIC_WC_PROJECT_ID ?? "";

export const wagmiConfig = createConfig({
    chains: [baseSepolia],
    connectors: [
        injected(),
        coinbaseWallet({ appName: "Oniym", appLogoUrl: "" }),
        ...(projectId ? [walletConnect({ projectId })] : []),
    ],
    transports: {
        [baseSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_URL),
    },
    ssr: true,
});
