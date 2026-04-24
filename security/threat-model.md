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

- Length-based pricing (3-char names cost 100× more than 10-char)
- Annual renewal requirement (squatters pay ongoing costs)
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
- No external calls in resolver read paths
- OpenZeppelin `ReentrancyGuard` on payable entrypoints

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

### 8. Cross-chain binding impersonation (week 7)

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

## Out of scope

- Private key compromise of individual users (not our layer)
- Phishing sites pretending to be oniym.xyz (DNS/brand issue)
- Attacks on user wallets (Phantom, MetaMask, etc.)
- Side-channel attacks on user devices

## Disclosure policy

Responsible disclosures to `security@playriglabs.fun`. Hall of fame for valid findings. Bounty program TBD post-launch.
