import type { Hex } from "viem";

export const CHAIN_IDS = {
    baseSepolia: 84532,
    base: 8453,
} as const;

export type ChainId = (typeof CHAIN_IDS)[keyof typeof CHAIN_IDS];

export const CONTRACT_ADDRESSES: Record<
    ChainId,
    { Registry: Hex; RegistrarController: Hex; PublicResolver: Hex; ReverseRegistrar: Hex }
> = {
    [CHAIN_IDS.baseSepolia]: {
        Registry: "0x4d0203cf6188247c282f1ee1b866ea55f71aabe4",
        RegistrarController: "0xF14E154633EFf408a99d3E6c9b01f918F93Ba5b1",
        PublicResolver: "0xA37eD413181537c60586317a70f612a304EB0681",
        ReverseRegistrar: "0xa5d904401d5f3ed1eb19188ce9de28bef3c083b9",
    },
    [CHAIN_IDS.base]: {
        // Sprint 8: mainnet deploy
        Registry: "0x0000000000000000000000000000000000000000",
        RegistrarController: "0x0000000000000000000000000000000000000000",
        PublicResolver: "0x0000000000000000000000000000000000000000",
        ReverseRegistrar: "0x0000000000000000000000000000000000000000",
    },
} as const;

export const registrarControllerAbi = [
    {
        type: "function",
        name: "MIN_COMMITMENT_AGE",
        inputs: [],
        outputs: [{ type: "uint256" }],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "makeCommitment",
        inputs: [
            {
                name: "req",
                type: "tuple",
                components: [
                    { name: "name", type: "string" },
                    { name: "tld", type: "bytes32" },
                    { name: "owner", type: "address" },
                    { name: "duration", type: "uint256" },
                    { name: "secret", type: "bytes32" },
                    { name: "resolver", type: "address" },
                    { name: "resolverData", type: "bytes[]" },
                    { name: "reverseRecord", type: "bool" },
                ],
            },
        ],
        outputs: [{ type: "bytes32" }],
        stateMutability: "pure",
    },
    {
        type: "function",
        name: "commit",
        inputs: [{ name: "commitment", type: "bytes32" }],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "commitments",
        inputs: [{ name: "commitment", type: "bytes32" }],
        outputs: [{ type: "uint256" }],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "register",
        inputs: [
            {
                name: "req",
                type: "tuple",
                components: [
                    { name: "name", type: "string" },
                    { name: "tld", type: "bytes32" },
                    { name: "owner", type: "address" },
                    { name: "duration", type: "uint256" },
                    { name: "secret", type: "bytes32" },
                    { name: "resolver", type: "address" },
                    { name: "resolverData", type: "bytes[]" },
                    { name: "reverseRecord", type: "bool" },
                ],
            },
        ],
        outputs: [],
        stateMutability: "payable",
    },
    {
        type: "function",
        name: "rentPrice",
        inputs: [
            { name: "name", type: "string" },
            { name: "tld", type: "bytes32" },
            { name: "duration", type: "uint256" },
        ],
        outputs: [
            { name: "base", type: "uint256" },
            { name: "premium", type: "uint256" },
        ],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "available",
        inputs: [
            { name: "name", type: "string" },
            { name: "tld", type: "bytes32" },
        ],
        outputs: [{ type: "bool" }],
        stateMutability: "view",
    },
] as const;

export const publicResolverAbi = [
    {
        type: "function",
        name: "setAddr",
        inputs: [
            { name: "node", type: "bytes32" },
            { name: "coinType", type: "uint256" },
            { name: "addr", type: "bytes" },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "addr",
        inputs: [
            { name: "node", type: "bytes32" },
            { name: "coinType", type: "uint256" },
        ],
        outputs: [{ type: "bytes" }],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "setText",
        inputs: [
            { name: "node", type: "bytes32" },
            { name: "key", type: "string" },
            { name: "value", type: "string" },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "text",
        inputs: [
            { name: "node", type: "bytes32" },
            { name: "key", type: "string" },
        ],
        outputs: [{ type: "string" }],
        stateMutability: "view",
    },
] as const;

export const registryAbi = [
    {
        type: "function",
        name: "setResolver",
        inputs: [
            { name: "node", type: "bytes32" },
            { name: "resolver", type: "address" },
        ],
        outputs: [],
        stateMutability: "nonpayable",
    },
    {
        type: "function",
        name: "resolver",
        inputs: [{ name: "node", type: "bytes32" }],
        outputs: [{ type: "address" }],
        stateMutability: "view",
    },
    {
        type: "function",
        name: "owner",
        inputs: [{ name: "node", type: "bytes32" }],
        outputs: [{ type: "address" }],
        stateMutability: "view",
    },
] as const;
