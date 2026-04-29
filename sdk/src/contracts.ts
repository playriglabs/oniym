import type { Hex } from "viem";

export const CHAIN_IDS = {
    baseSepolia: 84532,
    base: 8453,
} as const;

export type ChainId = (typeof CHAIN_IDS)[keyof typeof CHAIN_IDS];

export const CONTRACT_ADDRESSES: Record<
    ChainId,
    {
        Registry: Hex;
        RegistrarController: Hex;
        PublicResolver: Hex;
        ReverseRegistrar: Hex;
        PriceOracle: Hex;
        USDC: Hex;
    }
> = {
    [CHAIN_IDS.baseSepolia]: {
        Registry: "0xc937e37c1fa78b78b154ba5a76249e58c7d9d694",
        RegistrarController: "0xb0d499a5c8e3dc9db30b7c3f685b2d5d8d62f69a",
        PublicResolver: "0xe951ce73da1d75730e56df79844bfa745fa589d3",
        ReverseRegistrar: "0x15536f4306c06cf14fbd1b76385ea35fb31f4fa4",
        PriceOracle: "0x7ff70ea1a39fb0b46e986f6c8aae5f9dc9c11e28",
        USDC: "0x036cbd53842c5426634e7929541ec2318f3dcf7e",
    },
    [CHAIN_IDS.base]: {
        // Sprint 8: mainnet deploy
        Registry: "0x0000000000000000000000000000000000000000",
        RegistrarController: "0x0000000000000000000000000000000000000000",
        PublicResolver: "0x0000000000000000000000000000000000000000",
        ReverseRegistrar: "0x0000000000000000000000000000000000000000",
        PriceOracle: "0x0000000000000000000000000000000000000000",
        USDC: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
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
            { name: "paymentToken", type: "address" },
        ],
        outputs: [],
        stateMutability: "payable",
    },
    {
        type: "function",
        name: "renew",
        inputs: [
            { name: "name", type: "string" },
            { name: "tld", type: "bytes32" },
            { name: "duration", type: "uint256" },
            { name: "paymentToken", type: "address" },
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

export const priceOracleAbi = [
    {
        type: "function",
        name: "priceUsdc",
        inputs: [
            { name: "name", type: "string" },
            { name: "expires", type: "uint256" },
            { name: "duration", type: "uint256" },
        ],
        outputs: [{ name: "usdcAmount", type: "uint256" }],
        stateMutability: "view",
    },
] as const;

export const erc20Abi = [
    {
        type: "function",
        name: "approve",
        inputs: [
            { name: "spender", type: "address" },
            { name: "amount", type: "uint256" },
        ],
        outputs: [{ type: "bool" }],
        stateMutability: "nonpayable",
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
