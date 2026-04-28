<div align="center">

# Oniym

**One name, every chain.**

A multichain-native naming service. Register once on Base, resolve anywhere.

A [Playriglabs](https://playriglabs.fun) product.

[![Contracts CI](https://github.com/playriglabs/oniym/actions/workflows/contracts.yml/badge.svg)](https://github.com/playriglabs/oniym/actions/workflows/contracts.yml)
[![TypeScript CI](https://github.com/playriglabs/oniym/actions/workflows/typescript.yml/badge.svg)](https://github.com/playriglabs/oniym/actions/workflows/typescript.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Docs](./docs) · [SDK](./sdk) · [React](./react) · [ADRs](./docs/pages/adr)

</div>

---

## The problem

Blockchain addresses are user-hostile: `0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0`. One typo and funds are gone forever.

ENS solved this for Ethereum, but the crypto world is no longer single-chain. Today's user holds assets across Ethereum, L2s, Solana, Bitcoin, and Cosmos. Existing solutions are:

- **Expensive** — ENS registrations on L1 can cost $20–100+
- **Siloed** — each chain has its own naming service (`.eth`, `.sol`, `.bnb`)
- **Fragmented** — users end up with multiple disconnected names

## The solution

**Oniym is a naming service built for the multichain era.**

- Choose your TLD: `.id`, `.one`, `.xyz`, `.wagmi`, `.degen`, `.app` and 59 more
- Register `kyy.id` **once** on Base ($3/month or $15/year)
- Map it to addresses on Ethereum, Solana, Bitcoin, Sui, BNB, and more
- Reverse resolution: any address resolves back to its primary name
- Resolve from any app via SDK, REST API, or React hooks

## Architecture

```
                  ┌──────────────────┐
                  │   oniym.xyz web  │
                  └────────┬─────────┘
                           │
               ┌───────────┴────────────┐
               │  @oniym/sdk (TS)       │
               │  @oniym/react (hooks)  │
               └───────────┬────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
   │ Base RPC    │  │ Indexer API │  │ CCIP-Read   │
   │ (direct)    │  │ (fast read) │  │ (L1 gateway)│
   └──────┬──────┘  └──────┬──────┘  └─────────────┘
          │                │
          └────────────────┘
                  │
         ┌────────┴─────────┐
         │  Base L2 (84532) │
         │  ┌─────────────┐ │
         │  │  Registry   │ │
         │  │  TLDManager │ │
         │  │  Registrars │ │  ← 65 TLDs
         │  │  Controller │ │
         │  │  Resolver   │ │
         │  │  Reverse    │ │
         │  └─────────────┘ │
         └──────────────────┘
```

## Repo structure

```
oniym/
├── contracts/          # Solidity contracts (Foundry)
│   ├── src/
│   │   ├── Registry.sol
│   │   ├── TLDManager.sol          # manages 65 TLDs (.id .one .xyz .wagmi …)
│   │   ├── TLDRegistrar.sol        # per-TLD ERC-721 registrar
│   │   ├── RegistrarController.sol # commit-reveal registration + renewals
│   │   ├── PriceOracle.sol         # Chainlink ETH/USD feed
│   │   ├── PublicResolver.sol      # multichain addr + text + contenthash
│   │   ├── ReverseRegistrar.sol    # address → name reverse resolution
│   │   └── lib/
│   │       ├── Namehash.sol
│   │       └── BitcoinAddress.sol
│   ├── script/
│   │   ├── Deploy.s.sol
│   │   └── Register.s.sol
│   ├── test/
│   └── deployments/
│       └── base-sepolia.json       # live contract addresses
├── indexer/            # Ponder indexer (TypeScript)
│   ├── src/
│   │   ├── api/index.ts            # REST API: /resolve /lookup /names
│   │   └── handlers/               # on-chain event handlers
│   └── ponder.config.ts
├── sdk/                # @oniym/sdk (TypeScript + viem)
│   └── src/
│       ├── oniym.ts                # Oniym class
│       ├── contracts.ts            # ABIs + addresses
│       └── namehash.ts             # ENSIP-1 namehash
├── react/              # @oniym/react (TanStack Query hooks)
│   └── src/
│       ├── context.tsx             # OniymProvider
│       └── hooks/index.ts          # useResolve, useName, useNames, useRegister …
├── examples/
│   └── node/           # Node.js integration example
├── docs/               # Vocs documentation site
│   └── pages/
│       ├── sdk/
│       ├── react/
│       ├── contracts/
│       ├── api/
│       └── adr/        # Architecture Decision Records
└── security/           # Audit reports, threat model
```

## Deployments

### Base Sepolia (testnet)

| Contract             | Address                                      |
| -------------------- | -------------------------------------------- |
| Registry             | `0x24ee7fb02cac630e88c74d0a228eb771bc4badcf` |
| TLDManager           | `0xd485431c5056a8f49bf66a58c184649b285d76ac` |
| PriceOracle          | `0x86689215a17ead50cd7b258ffecd08c8f8897ce7` |
| RegistrarController  | `0x8CaD65fb525D709fF32Ec96b020Eb90e3Cb212F0` |
| PublicResolver       | `0xcdE3eD98423FbE098E24Bba9B634dFC3b449AC1C` |
| ReverseRegistrar     | `0x4bcfd49f89971a944badd921d29903e75a393fa4` |

Full registrar list (65 TLDs): [`contracts/deployments/base-sepolia.json`](./contracts/deployments/base-sepolia.json)

## REST API

The indexer exposes a read-only REST API:

| Endpoint                  | Description                              |
| ------------------------- | ---------------------------------------- |
| `GET /resolve/:name`      | Resolve a name to all its records        |
| `GET /lookup/:address`    | Reverse lookup — address to primary name |
| `GET /names/:address`     | All names owned by an address            |

## SDK

```ts
import { Oniym } from "@oniym/sdk";

const oniym = new Oniym({ indexerUrl: "https://api.oniym.xyz" });

// Reverse lookup
const name = await oniym.getName("0x11702b...");        // "kyy.web3"

// Forward resolution
const eth  = await oniym.getAddress("kyy.web3", "eth");
const sol  = await oniym.getAddress("kyy.web3", "sol");

// All names owned by an address
const names = await oniym.getNames("0x11702b...");

// Check availability
const free = await oniym.available("vitalik", "id");

// Register (commit-reveal, ~65s total)
await oniym.register({ name: "kyy", tld: "id", reverseRecord: true }, walletClient);
```

## React hooks

```tsx
import { OniymProvider, useResolve, useName, useNames, useRegister } from "@oniym/react";

function App() {
  return (
    <OniymProvider config={{ indexerUrl: "https://api.oniym.xyz" }}>
      <Profile address="0x11702b..." />
    </OniymProvider>
  );
}

function Profile({ address }: { address: string }) {
  const { data: name }  = useName(address);    // primary name
  const { data: names } = useNames(address);   // all owned names
  const { data: info }  = useResolve(name);    // full record
  // ...
}
```

## Local development

```bash
# Install all dependencies
pnpm install

# Contracts — build & test
cd contracts && forge build && forge test

# Indexer
cd indexer && pnpm dev

# SDK
cd sdk && pnpm build && pnpm test

# Docs
cd docs && pnpm dev
```

### Environment variables

```bash
# contracts/.env
DEPLOYER_ADDRESS=0x...
PRIVATE_KEY=0x...

# indexer/.env
DATABASE_URL=postgresql://...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
REDIS_URL=redis://localhost:6379
```

## Principles

1. **Fully decentralized** — ownership is on-chain, period
2. **Cheap by design** — L2-first, $3/month or $15/year via Chainlink feed
3. **Multichain-native** — not a retrofit; built for the cross-chain reality
4. **ENS-compatible where sensible** — ENSIP-1 namehash, SLIP-0044 coin types, resolver interface

## About Playriglabs

Oniym is built by [Playriglabs](https://playriglabs.fun) — a Web3 & AI product consultancy that ships its own products.

## License

MIT © [Playriglabs](https://playriglabs.fun)
