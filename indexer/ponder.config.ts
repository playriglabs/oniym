import { createConfig } from "ponder";
import { http } from "viem";

import deployments from "../contracts/deployments/base-sepolia.json";

const START_BLOCK = 40711233;

const registrarControllerAbi = [
    {
        type: "event",
        name: "NameRegistered",
        inputs: [
            { name: "name", type: "string", indexed: false },
            { name: "tld", type: "bytes32", indexed: true },
            { name: "label", type: "bytes32", indexed: true },
            { name: "owner", type: "address", indexed: true },
            { name: "baseCost", type: "uint256", indexed: false },
            { name: "premium", type: "uint256", indexed: false },
            { name: "expires", type: "uint256", indexed: false },
        ],
    },
    {
        type: "event",
        name: "NameRenewed",
        inputs: [
            { name: "name", type: "string", indexed: false },
            { name: "tld", type: "bytes32", indexed: true },
            { name: "label", type: "bytes32", indexed: true },
            { name: "cost", type: "uint256", indexed: false },
            { name: "expires", type: "uint256", indexed: false },
        ],
    },
] as const;

const publicResolverAbi = [
    {
        type: "event",
        name: "AddrChanged",
        inputs: [
            { name: "node", type: "bytes32", indexed: true },
            { name: "coinType", type: "uint256", indexed: false },
            { name: "addr", type: "bytes", indexed: false },
        ],
    },
    {
        type: "event",
        name: "TextChanged",
        inputs: [
            { name: "node", type: "bytes32", indexed: true },
            { name: "indexedKey", type: "string", indexed: true },
            { name: "key", type: "string", indexed: false },
            { name: "value", type: "string", indexed: false },
        ],
    },
    {
        type: "event",
        name: "ContenthashChanged",
        inputs: [
            { name: "node", type: "bytes32", indexed: true },
            { name: "hash", type: "bytes", indexed: false },
        ],
    },
] as const;

const reverseRegistrarAbi = [
    {
        type: "event",
        name: "ReverseClaimed",
        inputs: [
            { name: "addr", type: "address", indexed: true },
            { name: "node", type: "bytes32", indexed: true },
        ],
    },
] as const;

const registryAbi = [
    {
        type: "event",
        name: "Transfer",
        inputs: [
            { name: "node", type: "bytes32", indexed: true },
            { name: "owner", type: "address", indexed: false },
        ],
    },
    {
        type: "event",
        name: "NewResolver",
        inputs: [
            { name: "node", type: "bytes32", indexed: true },
            { name: "resolver", type: "address", indexed: false },
        ],
    },
] as const;

export default createConfig({
    networks: {
        baseSepolia: {
            chainId: 84532,
            transport: http(process.env.BASE_SEPOLIA_RPC_URL),
        },
    },
    contracts: {
        RegistrarController: {
            network: "baseSepolia",
            abi: registrarControllerAbi,
            address: deployments.core.RegistrarController as `0x${string}`,
            startBlock: START_BLOCK,
        },
        PublicResolver: {
            network: "baseSepolia",
            abi: publicResolverAbi,
            address: deployments.core.PublicResolver as `0x${string}`,
            startBlock: START_BLOCK,
        },
        ReverseRegistrar: {
            network: "baseSepolia",
            abi: reverseRegistrarAbi,
            address: deployments.core.ReverseRegistrar as `0x${string}`,
            startBlock: START_BLOCK,
        },
        Registry: {
            network: "baseSepolia",
            abi: registryAbi,
            address: deployments.core.Registry as `0x${string}`,
            startBlock: START_BLOCK,
        },
    },
});
