# Architecture

## Overview

Oniym consists of four layers:

1. **Contracts layer** — on-chain source of truth on Base
2. **Indexer layer** — off-chain cache for fast reads
3. **SDK layer** — developer-facing TypeScript library
4. **Frontend layer** — end-user web application

```
╔══════════════════════════════════════════════════════════════╗
║                      USERS & DEVELOPERS                      ║
╚══════════════════════════════════════════════════════════════╝
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌──────────────┐    ┌──────────────┐     ┌──────────────┐
   │  oniym.xyz   │    │ @oniym/sdk   │     │  Third-party │
   │  (Next.js)   │    │ (TypeScript) │     │  dApps       │
   └──────┬───────┘    └──────┬───────┘     └──────┬───────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                               ▼
               ┌───────────────────────────────┐
               │   Resolution Gateway (3 modes)│
               ├───────────────────────────────┤
               │ 1. Direct Base RPC (trustless)│
               │ 2. Indexer API (fast)         │
               │ 3. CCIP-Read (L1 bridge)      │
               └──────────────┬────────────────┘
                              │
                  ┌───────────┴───────────┐
                  │                       │
                  ▼                       ▼
        ┌──────────────────┐    ┌──────────────────┐
        │   Indexer        │    │   Base L2        │
        │  ┌────────────┐  │    │  ┌────────────┐  │
        │  │ Ponder     │  │◄───┤  │ Registry   │  │
        │  │ Postgres   │  │    │  │ TLDManager │  │
        │  │ Redis      │  │    │  │ Registrars │  │
        │  └────────────┘  │    │  │ Resolver   │  │
        └──────────────────┘    │  └────────────┘  │
                                └──────────────────┘
```

## Contracts layer

Five contracts, modeled after ENS with simplifications and extended for multi-TLD (see ADR-007).

### Registry (`Registry.sol`)

The ownership tree. Each node (namehash) maps to:

```solidity
struct Record {
    address owner;      // Controls this node and subnodes
    address resolver;   // Where to look up data
    uint64  expires;    // Unix timestamp (0 = permanent, e.g. for TLD roots)
}
mapping(bytes32 node => Record) records;
```

TLD-agnostic by design — any TLD root node is just another `bytes32` in the same tree.

Operations:
- `setOwner(node, owner)` — transfer ownership
- `setResolver(node, resolver)` — point at a resolver
- `setSubnodeOwner(node, label, owner)` — create/reassign subnode
- `ownerOf(node) view returns (address)`
- `resolverOf(node) view returns (address)`

### TLD Manager (`TLDManager.sol`)

Protocol-owned contract that manages the live set of TLDs. Owns each TLD root node in the Registry.

```
Launch TLDs (62 total, web-style and chain-neutral, each ≤ 5 chars):
  .id    .one   .me    .xyz   .web3  .io    .app   .dev   .onm   .go
  .ape   .fud   .hodl  .fomo  .moon  .rekt  .wagmi .ngmi  .degen .whale
  .buidl .dyor  .pump  .alpha .safu  .gm    .lfg   .ser   .fren  .goat
  .cope  .pepe  .mint  .bear  .gas   .dao   .ath   .dex   .cex   .burn
  .node  .swap  .yield .bag   .bags  .seed  .drop  .stake .pool  .wrap
  .farm  .shill .xxx   .regs  .main  .test  .exit  .fair  .guh   .bots
  .vcs   .keys
```

TLD choice is a pure identity preference — any TLD name resolves addresses for all supported chains (ETH, SOL, BTC, SUI, BNB). Chain resolution is driven by SLIP-0044 coin type in the resolver, not by TLD label.

New TLDs are added via `addTld(label, registrar)` — no Registry or Resolver changes needed.

### Registrar (`ITLDRegistrar.sol` per TLD)

Each TLD gets its own registrar instance. Issues second-level names as ERC-721 NFTs. Registration uses commit-reveal:

```
t=0   : user submits commit(keccak256(name ‖ tld ‖ owner ‖ secret))
t=60s : user submits register(name, tld, owner, secret, duration)
t=60s : contract verifies commit exists and hash matches
        → mints NFT, sets registry record, charges fee
```

This prevents frontrunning bots from stealing desirable names. The same flow works for any TLD.

### Controller (`RegistrarController.sol`)

Single controller that services all TLDs. `RegisterRequest` carries a `tld` field (namehash of the TLD label) so one contract handles `.id`, `.one`, `.wagmi`, and every other protocol TLD.

### Resolver (`PublicResolver.sol`)

Stores the actual data per name node. TLD-agnostic — uses `bytes32 node` throughout:

```solidity
// Multichain addresses (SLIP-0044 coinType)
mapping(bytes32 node => mapping(uint256 coinType => bytes)) addresses;

// Text records (avatar, email, url, twitter, etc.)
mapping(bytes32 node => mapping(string key => string value)) texts;

// Content hash (IPFS, Swarm, etc.)
mapping(bytes32 node => bytes) contenthash;
```

`bytes` (not `address`) for addresses — required for non-EVM chains where addresses aren't 20 bytes (Solana: 32, Bitcoin: variable).

**Key insight (Clusters-style):** TLD is an identity preference, not a chain restriction. A `.degen` name stores ETH, BTC, SOL, SUI, and BNB addresses in the same resolver node.

## Indexer layer

Off-chain cache. Not source of truth — if the indexer lies, clients can verify against Base directly.

### Schema (simplified)

```
names
  id              (uuid, pk)
  node            (bytes32, unique)
  label           (text)
  tld             (text, indexed)      -- e.g. "id", "one", "wagmi"
  owner           (address, indexed)
  resolver        (address)
  expires_at      (timestamp)
  registered_at   (timestamp)

resolutions
  id              (uuid, pk)
  node            (bytes32, indexed)
  coin_type       (int, indexed)
  address         (bytes)
  updated_at      (timestamp)

tlds
  label           (text, pk)
  node            (bytes32, unique)
  registrar       (address)
  active          (bool)

events
  id              (uuid, pk)
  block_number    (bigint, indexed)
  tx_hash         (bytes32)
  log_index       (int)
  event_name      (text)
  node            (bytes32, indexed)
  data            (jsonb)
```

### Reorg handling

Ponder handles this natively via block-level rollbacks. On reorg:
1. Events from orphaned blocks are marked invalid
2. Indexer re-applies canonical chain
3. API reads are paused briefly if they cross the reorg boundary

## SDK layer

`@oniym/sdk` exposes a Clusters-style API:

```typescript
import { Oniym } from "@oniym/sdk";

const oniym = new Oniym();

// Reverse: address → primary name (like clusters.getName)
const name = await oniym.getName("0x123...");           // "kyy.id"

// Forward: name → address on a specific chain
const addr = await oniym.getAddress("kyy.id", "sol");   // "..."

// All addresses for a name (multichain bundle)
const all = await oniym.getAddresses("kyy.id");
// { eth: "0x...", sol: "...", btc: "...", sui: "...", bnb: "..." }

// Available TLDs
const tlds = await oniym.getTLDs();
// [{ label: "id", node: "0x...", active: true }, ...]

// Writes (requires wallet)
await oniym.register("kyy", "id", 365 * 86400, ownerAddress);
await oniym.setAddress("kyy.id", "sol", solanaAddress);
```

SDK resolution order:
1. Indexer API (fast, typically <50ms)
2. Direct Base RPC (trustless fallback)
3. CCIP-Read gateway (for L1 compatibility)

## Cryptography

### Namehash
ENSIP-1. Recursive keccak256, right-to-left label processing. See [`lib/Namehash.sol`](../contracts/src/lib/Namehash.sol).

Example:
```
namehash("kyy.id") = keccak256(namehash("id") ‖ keccak256("kyy"))
namehash("id")     = keccak256(0x00…00 ‖ keccak256("id"))
```

### Commit-reveal
Standard 60s-minimum-commit scheme to prevent frontrunning. Works identically across all TLDs.

### Non-EVM address proofs (week 7)

For a user to bind a Solana address to their name, they must sign:

```
"I authorize oniym name <node> to resolve to this address. chain=solana nonce=<N>"
```

The signature is verified on-chain using ed25519. This prevents users from claiming addresses they don't control.

## Trust model

| Component            | Trust assumption                           | Failure mode                  |
|----------------------|--------------------------------------------|-------------------------------|
| Base sequencer       | Honest censorship resistance (short-term)  | Temporary censorship          |
| Registry contract    | Code is correct (audited)                  | Catastrophic if buggy         |
| TLDManager           | Owner multisig is honest                   | TLD activation/deactivation   |
| Indexer              | Up and honest                              | Degraded UX, falls back to RPC|
| CCIP-Read gateway    | Honest signing                             | L1 resolution fails           |
| Ed25519 precompile   | Chain supports / library correct           | Solana binding fails          |

Design principle: **the indexer and gateways can lie, and users are still safe** — all claims are verifiable against on-chain state.
