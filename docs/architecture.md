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
        │  │ Postgres   │  │    │  │ Registrar  │  │
        │  │ Redis      │  │    │  │ Resolver   │  │
        │  └────────────┘  │    │  └────────────┘  │
        └──────────────────┘    └──────────────────┘
```

## Contracts layer

Three contracts, modeled after ENS with simplifications:

### Registry (`Registry.sol`)

The ownership tree. Each node (namehash) maps to:

```solidity
struct Record {
    address owner;      // Controls this node and subnodes
    address resolver;   // Where to look up data
    uint64  expires;    // Unix timestamp (0 = permanent, e.g. for TLD)
}
mapping(bytes32 node => Record) records;
```

Operations:
- `setOwner(node, owner)` — transfer ownership
- `setResolver(node, resolver)` — point at a resolver
- `setSubnodeOwner(node, label, owner)` — create/reassign subnode
- `owner(node) view returns (address)`
- `resolver(node) view returns (address)`

### Registrar (`BaseRegistrar.sol` + `ETHRegistrarController.sol`)

Issues `.oniym` names as ERC-721 NFTs. Registration uses commit-reveal:

```
t=0   : user submits commit(keccak256(name ‖ owner ‖ secret))
t=60s : user submits register(name, owner, secret, duration)
t=60s : contract verifies commit exists and hash matches
        → mints NFT, sets registry record, charges fee
```

This prevents frontrunning bots from stealing desirable names.

### Resolver (`PublicResolver.sol`)

Stores the actual data per name:

```solidity
// Multichain addresses (SLIP-0044 coinType)
mapping(bytes32 node => mapping(uint256 coinType => bytes)) addresses;

// Text records (avatar, email, url, twitter, etc.)
mapping(bytes32 node => mapping(string key => string value)) texts;

// Content hash (IPFS, Swarm, etc.)
mapping(bytes32 node => bytes) contenthash;
```

`bytes` (not `address`) for addresses — required for non-EVM chains where addresses aren't 20 bytes (Solana: 32, Bitcoin: variable).

## Indexer layer

Off-chain cache. Not source of truth — if the indexer lies, clients can verify against Base directly.

### Schema (simplified)

```
names
  id              (uuid, pk)
  node            (bytes32, unique)
  label           (text)
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

`@oniym/sdk` provides:

```typescript
// Core
resolve(name: string, chain: ChainId): Promise<string | null>
lookup(address: string, chain: ChainId): Promise<string | null>

// Writes (with a wallet client)
register(name: string, duration: number, owner: Address): Promise<Hash>
setAddress(name: string, chain: ChainId, address: string): Promise<Hash>

// Utilities
namehash(name: string): Hex
normalize(name: string): string  // UTS-46
```

SDK tries in order:
1. Indexer API (fast, typically <50ms)
2. Direct Base RPC (trustless fallback)
3. CCIP-Read gateway (for L1 compatibility)

## Cryptography

### Namehash
ENSIP-1. Recursive keccak256, right-to-left label processing. See [`lib/Namehash.sol`](../contracts/src/lib/Namehash.sol).

### Commit-reveal
Standard 60s-minimum-commit scheme to prevent frontrunning.

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
| Indexer              | Up and honest                              | Degraded UX, falls back to RPC|
| CCIP-Read gateway    | Honest signing                             | L1 resolution fails           |
| Ed25519 precompile   | Chain supports / library correct           | Solana binding fails          |

Design principle: **the indexer and gateways can lie, and users are still safe** — all claims are verifiable against on-chain state.
