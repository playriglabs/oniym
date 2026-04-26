# ADR-004: Foundry as contract toolchain

- **Status:** Accepted
- **Date:** 2026-04-22
- **Deciders:** Core team

## Context

Every Solidity project needs a build + test + deploy toolchain. The two mainstream options are:

1. **Foundry** — Rust-based, tests written in Solidity, extremely fast, native fuzzing
2. **Hardhat** — Node.js-based, tests written in JS/TS, large plugin ecosystem

## Decision

**Foundry as the primary contract toolchain. No Hardhat.**

## Rationale

1. **Tests in Solidity** — contract tests written in the same language as the contracts means no type juggling, no ABI serialization in tests, and full access to cheatcodes (`vm.prank`, `vm.expectRevert`, `vm.warp`). This is a meaningful correctness win.

2. **Speed** — `forge test` runs 10-100× faster than Hardhat for equivalent suites. For a project with fuzz + invariant tests running tens of thousands of cases, this matters.

3. **Native fuzzing and invariant testing** — property-based testing is first-class in Foundry. For a naming protocol where "no one can steal another user's name" is an invariant, this is essential.

4. **Gas snapshots built in** — `forge snapshot` tracks gas usage per test, catching regressions in CI automatically.

5. **Active development** — Foundry is the modern default for serious protocols (Uniswap v4, Morpho, Optimism, ENS tooling) and continues to ship improvements.

6. **Simpler mental model** — no separate JS test runner, no `hardhat.config.ts` with plugin juggling. Just `foundry.toml` and `.sol` files.

## Consequences

### Positive
- Fast iteration loop (tests run in under a second for unit suites)
- Property-based testing as a first-class citizen
- Gas benchmarks automated in CI
- Smaller dependency footprint

### Negative
- Deployment scripts written in Solidity can be awkward for complex orchestration
- Less mature plugin ecosystem vs Hardhat (e.g. no equivalent to OpenZeppelin Defender integration)
- Rust toolchain requirement may be novel for some contributors

### Mitigations
- For multi-chain orchestrated deploys, we can supplement with a thin TypeScript deploy script using viem directly — no need to pull in Hardhat
- `foundryup` installer is a single command and well-documented
- Our CI pins a specific Foundry nightly version to avoid drift

## Scope note

This ADR applies to the `contracts/` workspace. TypeScript tooling (for indexer, SDK, web) is unaffected.

## References

- [Foundry Book](https://book.getfoundry.sh)
- [Foundry vs Hardhat comparison (Paradigm)](https://www.paradigm.xyz/2021/12/introducing-the-foundry-ethereum-development-toolbox)
