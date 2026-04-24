# Oniym Roadmap

An 8-week sprint from zero to mainnet launch. Weekly deliverables are hard gates — if a week slips, scope is cut rather than extended.

## Principles

1. **Ship over polish** — a working end-to-end slice beats a gold-plated partial feature
2. **Weekly deliverables are non-negotiable** — if behind at week-end, cut scope
3. **Decentralize ownership, pragmatize reads** — on-chain state is canonical, off-chain indexers are optimizations
4. **ENS-compatible where sensible** — borrow interfaces, don't reinvent

## Timeline

### Week 1 — Foundations ✅ *complete*

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

### Week 2 — Core contracts ✅ *complete*

**Theme:** Ownership layer. Multi-TLD names as NFTs, commit-reveal registration.

- [x] `Registry.sol` — node → owner/resolver/expires mapping
- [x] `TLDManager.sol` — protocol-owned manager for 62 web-style TLDs (`.id`, `.one`, `.wagmi`, …)
- [x] `TLDRegistrar.sol` — ERC-721 registrar (one instance per TLD)
- [x] `PriceOracle.sol` — Chainlink ETH/USD, flat-rate pricing
- [x] `RegistrarController.sol` — TLD-agnostic commit-reveal registration flow
- [x] Full unit tests + fuzz tests
- [x] Deploy initial TLDs to Base Sepolia

**Exit criteria:** End-to-end registration works on Base Sepolia. `forge test` passes with >95% coverage.

### Week 3 — Resolvers + security pass

**Theme:** The multichain payload. Slither/Mythril self-audit.

- [ ] `PublicResolver.sol` — multichain addresses (SLIP-0044 coinTypes), text records, contenthash
- [ ] Reverse resolver (`0x...` → `kyy.id` or any TLD name)
- [ ] ERC-165 interface detection
- [ ] Invariant tests (ownership, name expiry, funds)
- [ ] Self-audit pass (Slither + Mythril)
- [ ] Gas benchmarks vs ENS
- [ ] Threat model in `/security`

**Exit criteria:** Resolver supports ETH/SOL/BTC/SUI/BNB address types with test vectors. Security findings documented and addressed.

### Week 4 — Indexer + API

**Theme:** Fast reads from anywhere.

- [ ] Ponder indexer schema (names, events, resolutions)
- [ ] Event handlers for Registry/Resolver events
- [ ] Reorg handling verified
- [ ] REST API (Hono) — `/resolve/:name`, `/lookup/:address`
- [ ] Redis cache layer
- [ ] Rate limiting
- [ ] Docker Compose for local dev
- [ ] Deploy to Railway

**Exit criteria:** `curl https://api.oniym.xyz/resolve/kyy.id` returns all chain addresses. P99 latency < 200ms.

### Week 5 — SDK

**Theme:** Developer experience.

- [ ] `@oniym/sdk` full impl — `Oniym` class: `getName()`, `getAddress()`, `getAddresses()`, `register()`, `setAddress()`
- [ ] `@oniym/react` — TanStack Query hooks
- [ ] Generated TypeDoc site
- [ ] Example Next.js and Expo apps
- [ ] Published to npm (semantic release)

**Exit criteria:** `pnpm add @oniym/sdk` works, docs site live, 2 working examples.

### Week 6 — Frontend

**Theme:** The product users actually touch.

- [ ] Next.js 15 app with App Router
- [ ] Search + availability check
- [ ] Register flow with commit-reveal UX
- [ ] Manage page (addresses, avatar, text records)
- [ ] Privy wallet connection
- [ ] IPFS avatar upload
- [ ] Mobile responsive, dark mode
- [ ] Deploy to Vercel at `oniym.xyz`

**Exit criteria:** A non-developer can register a name without help.

### Week 7 — "Oh damn" feature

**Theme:** Cryptographic depth. Chosen: **non-EVM reverse resolution via signature verification.**

- [ ] Ed25519 signature verification in Solidity (for Solana)
- [ ] BIP-322 or sighash-based Bitcoin verification
- [ ] Cosmos adr-36 signature verification
- [ ] On-chain storage of proof + claimed name
- [ ] UI flow: "Prove you own this Solana address" → sign message in Phantom → submit proof
- [ ] Test vectors for each chain

**Exit criteria:** Someone with a Solana wallet can prove ownership and bind it to `kyy.id` (or any TLD name).

### Week 8 — Launch

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

If any week is at risk, cut in this priority order:

1. Gas optimization pass (defer to v1.1)
2. GraphQL API (REST is enough)
3. React hooks package (users can write their own on top of core SDK)
4. Avatar IPFS upload (external URL is fine)
5. Cosmos verification (keep EVM + Solana + BTC)

What we never cut: namehash correctness, commit-reveal, on-chain ownership, basic multichain resolution.
