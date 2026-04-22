# ADR-003: Monorepo with pnpm workspaces

- **Status:** Accepted
- **Date:** 2026-04-22
- **Deciders:** Core team

## Context

Oniym has four deliverable artifacts:

1. **Smart contracts** — Solidity + Foundry
2. **Indexer** — TypeScript + Ponder + Postgres
3. **SDK** — TypeScript library for developers
4. **Web app** — Next.js frontend

These artifacts share types, ABIs, and constants. Options:

- **Multi-repo** — one repo per artifact, publish shared packages to npm
- **Monorepo (pnpm)** — all artifacts in one repo, use workspace protocol
- **Monorepo (Turborepo/Nx)** — heavier orchestration tooling

## Decision

**Single monorepo with pnpm workspaces. No Turborepo/Nx initially.**

## Rationale

1. **Type safety across boundaries** — generated contract ABIs and types flow directly from `contracts/` → `sdk/` → `web/` without a publish cycle.

2. **Atomic changes** — a contract change + matching SDK update + UI update is one PR, not three.

3. **Simpler for a solo/small team** — no cross-repo PR coordination, no version skew.

4. **pnpm is fast enough** — for our project size, we don't need Turborepo's caching. We can add it later if build times grow.

5. **Standard tooling** — `pnpm -r build` orchestrates all workspaces. No custom task runner config.

## Consequences

### Positive
- Single `pnpm install` bootstraps everything
- Shared `tsconfig`, `prettier`, `eslint` config at root
- Contract ABIs consumed directly via workspace protocol (`workspace:*`)
- CI can test the whole system in one job

### Negative
- Repo is larger (clone takes longer)
- Contributors see all artifacts even if they only care about one
- Published packages need careful `files` field in `package.json` to avoid leaking internal code

### Mitigations
- `files` allowlist in each package's `package.json`
- Clear README in each workspace explaining its scope
- GitHub CODEOWNERS (future) for per-area review

## Structure

```
oniym/
├── contracts/       # Foundry project (not a pnpm workspace)
├── indexer/         # Workspace
├── sdk/             # Workspace (published to npm as @oniym/sdk)
├── web/             # Workspace (not published)
├── examples/*       # Workspaces (not published)
├── docs/
├── security/
├── package.json     # Root, workspaces config
├── pnpm-workspace.yaml
└── .github/workflows/
```

Note: `contracts/` is managed by Foundry (not pnpm) — it has its own dependency system via `forge install`. We coordinate via build scripts.

## References

- [pnpm workspaces](https://pnpm.io/workspaces)
