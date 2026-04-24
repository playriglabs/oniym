<div align="center">

# Oniym

**One name, every chain.**

A multichain-native naming service. Register once on Base, resolve anywhere.

A [Playriglabs](https://playriglabs.fun) product.

[![Contracts CI](https://github.com/playriglabs/oniym/actions/workflows/contracts.yml/badge.svg)](https://github.com/playriglabs/oniym/actions/workflows/contracts.yml)
[![TypeScript CI](https://github.com/playriglabs/oniym/actions/workflows/typescript.yml/badge.svg)](https://github.com/playriglabs/oniym/actions/workflows/typescript.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Docs](./docs) · [SDK](./sdk) · [Security](./security) · [ADRs](./docs/adr)

</div>

---

## The problem

Blockchain addresses are user-hostile: `0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0`. One typo and funds are gone forever.

ENS solved this for Ethereum, but the crypto world is no longer single-chain. Today's user holds assets across Ethereum, L2s, Solana, Bitcoin, and Cosmos. Existing solutions are:

- **Expensive** — ENS registrations on L1 can cost $20-100+
- **Siloed** — each chain has its own naming service (.eth, .sol, .bnb)
- **Fragmented** — users end up with multiple disconnected names

## The solution

**Oniym is a naming service built for the multichain era.**

- Choose your TLD: `.id`, `.one`, `.xyz`, `.wagmi`, `.degen` and 57 more — pick the one that fits your identity
- Register `kyy.id` **once** on Base (~$5/year)
- Map it to addresses on Ethereum, Solana, Bitcoin, Sui, BNB, and more — any TLD resolves all chains
- Resolve from any chain via SDK, API, or CCIP-Read
- Cryptographically verify non-EVM address ownership

## Architecture

```
                  ┌──────────────────┐
                  │   oniym.xyz web  │
                  └────────┬─────────┘
                           │
                  ┌────────┴─────────┐
                  │  @oniym/sdk (TS) │
                  └────────┬─────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
   │ Base RPC    │  │ Indexer API │  │ CCIP-Read   │
   │ (direct)    │  │ (fast read) │  │ (L1 gateway)│
   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                  ┌────────┴─────────┐
                  │  Base L2 (chain) │
                  │  ┌────────────┐  │
                  │  │  Registry  │  │
                  │  │  Registrar │  │
                  │  │  Resolver  │  │
                  │  └────────────┘  │
                  └──────────────────┘
```

See [docs/architecture.md](./docs/architecture.md) for a deeper view.

## Repo structure

```
oniym/
├── contracts/         # Solidity contracts (Foundry)
│   ├── src/
│   │   ├── Registry.sol
│   │   ├── TLDManager.sol        # manages 62 web-style TLDs (.id .one .xyz .wagmi …)
│   │   ├── TLDRegistrar.sol      # per-TLD ERC-721 registrar
│   │   ├── RegistrarController.sol
│   │   ├── PublicResolver.sol
│   │   └── lib/Namehash.sol
│   └── test/
├── indexer/           # Ponder indexer (TypeScript)
├── sdk/               # @oniym/sdk (TypeScript + viem)
├── web/               # Next.js frontend
├── docs/              # Architecture, ADRs, specs
│   └── adr/           # Architecture Decision Records
├── security/          # Audit reports, threat model
└── examples/          # Integration examples
```

## Status

**Week 1** — Foundations (in progress)

See the [roadmap](./docs/roadmap.md).

## Principles

1. **Fully decentralized** — ownership is on-chain, period
2. **Cheap by design** — L2-first, CCIP-Read for cross-chain reads
3. **Multichain-native** — not a retrofit; built for 2026 reality
4. **ENS-compatible where sensible** — namehash, SLIP-0044, resolver interface

## Local development

```bash
# Install dependencies
pnpm install

# Contracts
cd contracts
forge install
forge build
forge test

# Indexer
cd ../indexer
pnpm dev

# SDK
cd ../sdk
pnpm build

# Web
cd ../web
pnpm dev
```

## About Playriglabs

Oniym is built by [Playriglabs](https://playriglabs.fun) — a Web3 & AI product consultancy that ships its own products.

We take what we learn from building Oniym and apply it to client work: cross-chain protocol design, smart contract security, indexer architecture, and developer tooling. If you're building something hard in the space, get in touch.

## License

MIT © [Playriglabs](https://playriglabs.fun)
