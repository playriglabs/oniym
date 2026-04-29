# Oniym Roadmap

An 8-sprint journey from zero to mainnet launch. Deliverables are hard gates — if a sprint slips, scope is cut rather than extended.

## Principles

1. **Ship over polish** — a working end-to-end slice beats a gold-plated partial feature
2. **Deliverables are non-negotiable** — if behind at sprint-end, cut scope
3. **Decentralize ownership, pragmatize reads** — on-chain state is canonical, off-chain indexers are optimizations
4. **ENS-compatible where sensible** — borrow interfaces, don't reinvent

## Timeline

### 1 — Foundations ✅ _complete_

**Theme:** Prove cryptographic foundations, establish CI and project structure.

- [x] Monorepo scaffold (pnpm workspaces)
- [x] Foundry project + `foundry.toml`
- [x] `Namehash.sol` library with full test suite
- [x] TypeScript `namehash()` in SDK with matching vectors
- [x] GitHub Actions CI (contracts + TS)
- [x] ADRs 001-007 (001-004 foundations, 005 branding, 006 pricing, 007 multi-TLD pivot)
- [x] Multi-TLD interfaces (ITLDManager, ITLDRegistrar, IRegistrarController)
- [x] SDK skeleton — `Oniym` class with Clusters-style API stubs
- [x] Architecture diagram (SVG)
- [x] Slither baseline (run locally: `pnpm contracts:slither`)
- [x] Domain + npm scope + GitHub org secured

**Exit criteria:** Public repo green on CI, namehash parity test passes, ADRs merged.

### 2 — Core contracts ✅ _complete_

**Theme:** Ownership layer. Multi-TLD names as NFTs, commit-reveal registration.

- [x] `Registry.sol` — node → owner/resolver/expires mapping
- [x] `TLDManager.sol` — protocol-owned manager for 62 web-style TLDs (`.id`, `.one`, `.wagmi`, …)
- [x] `TLDRegistrar.sol` — ERC-721 registrar (one instance per TLD)
- [x] `PriceOracle.sol` — Chainlink ETH/USD, flat-rate pricing
- [x] `RegistrarController.sol` — TLD-agnostic commit-reveal registration flow
- [x] Full unit tests + fuzz tests
- [x] Deploy initial TLDs to Base Sepolia

**Exit criteria:** End-to-end registration works on Base Sepolia. `forge test` passes with >95% coverage.

### 3 — Resolvers + security pass ✅ _complete_

**Theme:** The multichain payload. Slither/Mythril self-audit.

- [x] `PublicResolver.sol` — multichain addresses (SLIP-0044 coinTypes), text records, contenthash
- [x] Reverse resolver (`0x...` → `kyy.id` or any TLD name)
- [x] ERC-165 interface detection
- [x] Invariant tests (ownership, name expiry, funds) — 5 invariants × 128 000 calls each
- [x] Self-audit pass (Slither baseline in `/security`)
- [x] Gas benchmarks vs ENS — Oniym 17–68% cheaper across all operations
- [x] Threat model in `/security`

**Exit criteria:** Resolver supports ETH/SOL/BTC/SUI/BNB address types with test vectors. Security findings documented and addressed.

### 4 — Indexer + API

**Theme:** Fast reads from anywhere.

- [x] Ponder indexer schema (names, events, resolutions)
- [x] Event handlers for Registry/Resolver events
- [x] Reorg handling verified (Ponder handles reorgs automatically)
- [x] REST API (Hono) — `/resolve/:name`, `/lookup/:address`
- [x] Redis cache layer
- [x] Rate limiting
- [x] Docker Compose for local dev
- [ ] Deploy to cloudflare

**Exit criteria:** `curl https://api.oniym.xyz/resolve/kyy.id` returns all chain addresses. P99 latency < 200ms.

### 5 — SDK ✅ _complete_

**Theme:** Developer experience.

- [x] `@oniym/sdk` full impl — `Oniym` class: `getName()`, `getAddress()`, `getAddresses()`, `register()`, `setAddress()`
- [x] `@oniym/react` — wagmi-based hooks (`useOniym`, context provider)
- [x] Generated TypeDoc site
- [ ] Published to npm (semantic release)

**Exit criteria:** `pnpm add @oniym/sdk` works, docs site live, 2 working examples.

### 6 — Frontend ✅ _complete_

**Theme:** The product users actually touch.

- [x] Next.js 15 app with App Router
- [x] Search + availability check (live debounced, animated states)
- [x] Register flow with commit-reveal UX
- [x] Manage page (multichain addresses, text records)
- [x] Profile page
- [x] Wallet connection (wagmi + Reown AppKit — injected, Coinbase, WalletConnect)
- [x] Mobile responsive, dark mode
- [ ] IPFS avatar upload
- [ ] Deploy to Cloudflare pages at `oniym.xyz`

**Exit criteria:** A non-developer can register a name without help.

### 7 — "Oh damn" feature

**Theme:** Cryptographic depth. Chosen: **non-EVM reverse resolution via signature verification.**

- [ ] Ed25519 signature verification in Solidity (for Solana)
- [ ] BIP-322 or sighash-based Bitcoin verification
- [ ] Cosmos adr-36 signature verification
- [ ] On-chain storage of proof + claimed name
- [ ] UI flow: "Prove you own this Solana address" → sign message in Phantom → submit proof
- [ ] Test vectors for each chain

**Exit criteria:** Someone with a Solana wallet can prove ownership and bind it to `kyy.id` (or any TLD name).

### 8 — Launch

**Theme:** Real humans use real product.

- [ ] Final security pass + optional external review
- [ ] Deploy contracts to Base mainnet
- [ ] Verify on Basescan
- [ ] Pricing tested end-to-end
- [ ] Launch blog post (technical deep-dive)
- [ ] Twitter/X thread with architecture diagram
- [ ] Submit to Base ecosystem + ENS directory
- [ ] Show HN post
- [ ] Metrics dashboard public

**Exit criteria:** 10 real registrations by 10 distinct wallets. Zero critical security issues reported in first week.

## Post-launch backlog (v2+)

Explicitly out of scope for v1 but planned:

- DAO governance token
- Cross-chain name transfer (LayerZero)
- Cross-TLD identity bundle (claim `kyy.*` across all TLDs in one tx)
- Subname marketplace
- ZK-based private names (Noir/Circom)
- Mobile app
- Account abstraction integration (ERC-4337 paymaster for free registrations)

## Cutting scope

If any sprint is at risk, cut in this priority order:

1. Gas optimization pass (defer to v1.1)
2. GraphQL API (REST is enough)
3. React hooks package (users can write their own on top of core SDK)
4. Avatar IPFS upload (external URL is fine)
5. Cosmos verification (keep EVM + Solana + BTC)

What we never cut: namehash correctness, commit-reveal, on-chain ownership, basic multichain resolution.
