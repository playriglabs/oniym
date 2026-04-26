/* eslint-disable @typescript-eslint/restrict-template-expressions */
/* eslint-disable @typescript-eslint/no-unsafe-return */
/* eslint-disable @typescript-eslint/no-non-null-assertion */
/* eslint-disable @typescript-eslint/no-redundant-type-constituents */
import {
    useQuery,
    useMutation,
    type UseQueryResult,
    type UseMutationResult,
} from "@tanstack/react-query";
import type { WalletClient } from "viem";
import type {
    ResolveResult,
    LookupResult,
    MultiChainAddresses,
    OwnedName,
    SupportedChain,
    RegisterOptions,
} from "@oniym/sdk";
import { useOniym } from "../context";

export function useResolve(name: string | undefined): UseQueryResult<ResolveResult | null> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "resolve", name],
        queryFn: () => oniym.resolve(name!),
        enabled: !!name,
        staleTime: 30_000,
    });
}

export function useName(address: string | undefined): UseQueryResult<string | null> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "name", address],
        queryFn: async (): Promise<string | null> => {
            const res = await fetch(
                `${(oniym.config.indexerUrl ?? "http://localhost:42069").replace(/\/$/, "")}/lookup/${address!}`,
            );
            if (res.status === 404) return null;
            const data = (await res.json()) as LookupResult;
            return data.name;
        },
        enabled: !!address,
        staleTime: 30_000,
    });
}

export function useNames(address: string | undefined): UseQueryResult<OwnedName[]> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "names", address],
        queryFn: () => oniym.getNames(address!),
        enabled: !!address,
        staleTime: 30_000,
    });
}

export function useAddresses(name: string | undefined): UseQueryResult<MultiChainAddresses> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "addresses", name],
        queryFn: () => oniym.getAddresses(name!),
        enabled: !!name,
        staleTime: 30_000,
    });
}

export function useAddress(
    name: string | undefined,
    chain: SupportedChain,
): UseQueryResult<string | null> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "address", name, chain],
        queryFn: () => oniym.getAddress(name!, chain),
        enabled: !!name,
        staleTime: 30_000,
    });
}

export function useAvailable(
    name: string | undefined,
    tld: string | undefined,
): UseQueryResult<boolean> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "available", name, tld],
        queryFn: () => oniym.available(name!, tld!),
        enabled: !!name && !!tld,
        staleTime: 10_000,
    });
}

export function useRentPrice(
    name: string | undefined,
    tld: string | undefined,
    duration: number,
): UseQueryResult<bigint> {
    const oniym = useOniym();
    return useQuery({
        queryKey: ["oniym", "rentPrice", name, tld, duration],
        queryFn: () => oniym.rentPrice(name!, tld!, duration),
        enabled: !!name && !!tld,
        staleTime: 30_000,
    });
}

export function useRegister(
    walletClient: WalletClient | undefined,
): UseMutationResult<`0x${string}`, Error, RegisterOptions> {
    const oniym = useOniym();
    return useMutation({
        mutationFn: (options: RegisterOptions) => {
            if (!walletClient) throw new Error("Wallet not connected");
            return oniym.register(options, walletClient);
        },
    });
}
