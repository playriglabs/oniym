# ADR-001: Base as primary registry chain

- **Status:** Accepted
- **Date:** 2026-04-22
- **Deciders:** Core team

## Context

Oniym requires a single "home" chain where names are registered and ownership is stored. The choice affects three things:

1. **Cost to users** — registration and address updates
2. **Trust assumptions** — chain security, decentralization
3. **Ecosystem reach** — wallets and dApps that integrate natively

Candidates considered:

| Chain         | Gas cost      | Ecosystem   | Maturity | ENS precedent  |
|---------------|---------------|-------------|----------|----------------|
| Ethereum L1   | Very high     | Largest     | Highest  | ENS lives here |
| Base          | Very low      | Large       | High     | Basenames      |
| Arbitrum      | Very low      | Large       | High     | —              |
| Optimism      | Low           | Medium      | High     | —              |
| Scroll/Linea  | Very low      | Growing     | Medium   | Linea Names    |
| Solana        | Very low      | Large       | High     | Bonfida        |

## Decision

**Primary registry chain: Base.**

## Rationale

1. **Cost** — Base gas is consistently sub-cent for reads and <$0.10 for writes, making registrations affordable globally (critical for users outside the US/EU).

2. **Ecosystem reach** — Base has the largest consumer wallet footprint among L2s (Coinbase Wallet, MetaMask integration, Farcaster). This matches our target: end users, not power users.

3. **EVM-native** — enables Solidity + Foundry tooling, EIP-compatible resolvers, and ENS-interface compatibility where useful.

4. **Precedent** — Basenames proved the L2 naming model at scale. Users and wallets already understand "name lives on Base."

5. **Upgrade path** — Base's OP Stack roots mean eventual decentralization of the sequencer is planned. We avoid chain lock-in by keeping all state readable via standard RPC.

6. **CCIP-Read compatibility** — Base is well-supported by L1 CCIP-Read gateways (planned week 7 feature).

## Consequences

### Positive
- Registration cost target (<$5/year) is easily achievable
- Fast finality for good UX
- Large existing user base
- Foundry/Solidity standard tooling

### Negative
- Base is a relatively young chain (2023) vs Ethereum (2015)
- Centralized sequencer (Coinbase) is a short-term trust assumption
- Potential Coinbase regulatory risk affects operations

### Mitigations
- Contracts are upgradeable via timelock multisig, enabling future migration if needed
- All data is reconstructable from on-chain events — no off-chain dependency
- CCIP-Read gateway (future) allows L1 Ethereum resolution without Base read dependency for users who want maximum decentralization

## References

- [Base docs](https://docs.base.org)
- [Basenames](https://www.base.org/names)
- [EIP-3668 (CCIP-Read)](https://eips.ethereum.org/EIPS/eip-3668)
