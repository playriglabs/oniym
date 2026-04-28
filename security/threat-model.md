# Oniym threat model

This document enumerates attacks against Oniym and the mitigations for each. Updated as the design evolves; any code change that affects trust assumptions must update this file.

## Assets at risk

| Asset                | Impact if compromised                      |
| -------------------- | ------------------------------------------ |
| Name ownership (NFT) | User loses identity, attacker impersonates |
| Resolution data      | Funds sent to wrong address                |
| Registration fees    | Direct financial loss                      |
| Indexer availability | UX degradation (not security)              |

## Threat actors

- **Squatters** — register desirable names for resale
- **Frontrunners** — sandwich registration txs for valuable names
- **Phishers** — register visually similar names (`vitа𝗅ik.id` with Cyrillic)
- **Protocol-level attackers** — exploit contract bugs
- **Sequencer/L2 attackers** — censor or reorder transactions

## Attack surface

### 1. Registration frontrunning

**Attack:** Bot watches mempool for `register("vitalik", "id", ...)` tx, submits same registration with higher gas.

**Mitigation:** Commit-reveal scheme.

1. User submits `commit(hash(name ‖ tld ‖ owner ‖ secret))` — name is not visible
2. 60-second minimum delay
3. User submits `register(name, owner, secret, ...)` — contract verifies commit

**Residual risk:** Attacker watching reveal tx could submit a competing commit, but the 60s delay means the original committer reveals first.

### 2. Name squatting

**Attack:** Register popular brand names en masse, hold for resale.

**Mitigation:**

- Two-tier pricing ($3/month, $15/year) — squatters pay ongoing holding costs
- Annual renewal requirement (names expire after registration period)
- No mitigation for determined squatters with capital — this is an inherent naming-system problem

### 3. Homograph attacks

**Attack:** Register `vitalik.id` using Cyrillic `а` instead of Latin `a`, trick users into sending funds.

**Mitigation:**

- UTS-46 normalization enforced in SDK (frontend rejects non-canonical forms)
- On-chain storage of raw label bytes — contract cannot enforce normalization itself
- Display clients should highlight mixed-script names

**Residual risk:** Technically sophisticated users can still register homograph names by calling the contract directly. Client-side warnings are the main defense.

### 4. Reentrancy

**Attack:** Malicious token or callback reenters registration/resolver during payment flow.

**Mitigation:**

- Checks-Effects-Interactions pattern in all state-modifying functions
- All state changes happen before external calls (ETH refund is last in `register`)
- `safeTransferFrom` in `RegistrarController.register` triggers `onERC721Received` — controller implements this as a pure no-op, no reentrant path possible
- No external calls in resolver read paths

### 5. Integer overflow/underflow

**Attack:** Manipulate expiry, prices, or counters via arithmetic edge cases.

**Mitigation:**

- Solidity 0.8.28 (checked arithmetic by default)
- Explicit bounds checks on duration inputs
- Fuzz tests with extreme values

### 6. Oracle manipulation

**Attack:** Manipulate ETH/USD price feed to pay less for registrations.

**Mitigation:**

- Chainlink price feed (decentralized oracle)
- Staleness check (`updatedAt` within 1 hour)
- Fallback to cached price if feed fails
- Pricing rounded up to nearest cent to discourage precision arbitrage

### 7. Fake resolver data

**Attack:** Malicious resolver contract returns wrong addresses.

**Mitigation:**

- Registry stores `resolver` address set by name owner — if owner chooses a malicious resolver, that's their choice
- Default resolver (`PublicResolver`) is audited and canonical
- Frontend displays non-default resolvers prominently
- ERC-165 interface check before resolver calls

### 8. Resolver record poisoning

**Attack:** An address that previously owned a name (or was granted resolver-level delegation) sets records pointing to their own addresses, then the name is transferred to a new owner who doesn't notice the stale records.

**Mitigation:**

- `PublicResolver` authorization checks `Registry.ownerOf(node)` at call time — not at delegation time
- After a name transfer, the old owner's registry-level operator approval is tied to the old owner's identity. The new owner's `isApprovedForAll` state is independent
- Resolver-level delegations (`approve()`) are scoped per node. A name transfer does NOT revoke these — the new owner should call `approve(node, oldDelegate, false)` if needed
- **Residual risk:** New owners unaware of active resolver delegates. Frontend should display active delegates prominently on the manage page

### 9. Reverse record spoofing

**Attack:** Alice sets her reverse record to `vitalik.id`, tricking dApps into displaying Vitalik's name for Alice's address.

**Mitigation:**

- Reverse records are permissionless by design — anyone can claim `myaddr.addr.reverse → any name`
- **dApps MUST verify forward resolution**: resolve the claimed name forward and check it includes the address. Only display the name if forward + reverse match
- `ReverseRegistrar` documentation and SDK enforce this verification pattern

### 10. Cross-chain binding impersonation (week 7)

**Attack:** Claim ownership of a Solana address you don't control.

**Mitigation:**

- Ed25519 signature verification on-chain
- Signed message includes namehash + nonce + chain ID (prevents replay across names)
- Verification happens at `setAddress(coinType=501, ...)` time

### 9. Sequencer censorship

**Attack:** Base sequencer censors a specific user's registration.

**Mitigation:**

- Short-term: accept as risk (Coinbase sequencer is reputable)
- Long-term: use Base's forced-inclusion mechanism via L1
- Contract has no ability to freeze funds or names even if sequencer misbehaves

### 10. Governance takeover

**Attack:** Attacker gains control of upgrade multisig.

**Mitigation:**

- Timelock on all upgrades (minimum 2 days)
- Multisig with 3-of-5 reputable signers
- Critical functions (resolver registry, pause) require higher threshold
- Future: migrate to DAO governance post-launch

## Gas benchmarks vs ENS (Base Sepolia, Solidity 0.8.28, optimizer 10 000 runs)

| Operation | Oniym | ENS reference | Delta |
|---|---|---|---|
| `commit()` | 25 510 | ~47 000 | **−46%** |
| `register()` no resolver | 223 392 | ~280 000 | **−20%** |
| `register()` + `setAddr` | 256 102 | ~310 000 | **−17%** |
| `renew()` | 24 584 | ~60 000 | **−59%** |
| `setAddr()` cold | 30 616 | ~45 000 | **−32%** |
| `setAddr()` warm | 8 216 | ~20 000 | **−59%** |
| `setText()` cold | 31 542 | ~46 000 | **−31%** |
| `reclaim()` | 9 476 | ~30 000 | **−68%** |

Oniym is consistently cheaper than ENS across all operations, primarily due to:
- `via_ir = true` + `optimizer_runs = 10 000` in `foundry.toml`
- Simpler storage layout (no ENS legacy structs)
- No DNSSEC integration overhead

## Out of scope

- Private key compromise of individual users (not our layer)
- Phishing sites pretending to be oniym.xyz (DNS/brand issue)
- Attacks on user wallets (Phantom, MetaMask, etc.)
- Side-channel attacks on user devices

## Disclosure policy

Responsible disclosures to `security@playriglabs.fun`. Hall of fame for valid findings. Bounty program TBD post-launch.
