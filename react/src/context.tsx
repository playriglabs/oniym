import { createContext, useContext, useMemo, type ReactNode } from "react";
import { Oniym, type OniymConfig } from "@oniym/sdk";

const OniymContext = createContext<Oniym | null>(null);

export function OniymProvider({
    config,
    children,
}: {
    config?: OniymConfig;
    children: ReactNode;
}): ReactNode {
    const oniym = useMemo(() => new Oniym(config ?? {}), [config]);
    return <OniymContext.Provider value={oniym}>{children}</OniymContext.Provider>;
}

export function useOniym(): Oniym {
    const ctx = useContext(OniymContext);
    if (!ctx) throw new Error("useOniym must be used within <OniymProvider>");
    return ctx;
}
