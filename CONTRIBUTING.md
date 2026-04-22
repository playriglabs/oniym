# Contributing to Oniym

Thanks for your interest. Oniym is still in early development, but contributions are welcome — especially around security review, test coverage, and SDK ergonomics.

## Development setup

**Prerequisites:**

- Node.js 24+
- pnpm 9+
- Foundry (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)

**Bootstrap:**

```bash
git clone https://github.com/playriglabs/oniym.git
cd oniym
pnpm install
cd contracts && forge install && cd ..
cp .env.example .env
```

**Run everything:**

```bash
# Contracts
pnpm contracts:build
pnpm contracts:test

# TypeScript workspaces
pnpm typecheck
pnpm test
```

## Branch strategy

- `main` — always deployable, all tests green
- `feat/*` — feature branches, squash-merge into main
- `fix/*` — bug fixes
- `docs/*` — documentation only

## Commit style

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(contracts): add commit-reveal to registrar
fix(sdk): handle empty label in namehash
docs(adr): clarify CCIP-Read rationale
chore: bump foundry to nightly-2026-04-22
```

## PR checklist

- [ ] All CI passes (contracts + TypeScript)
- [ ] Tests added for new behavior
- [ ] Gas snapshot updated if contracts changed
- [ ] ADR written if making an architectural decision
- [ ] Docs updated if public API changed

## Security

Please do NOT open a public issue for security vulnerabilities. Email `security@playriglabs.fun` instead.

## Code style

- **Solidity:** formatted by `forge fmt`, line length 100
- **TypeScript:** formatted by Prettier, strict mode, `noUncheckedIndexedAccess`
- **Commits:** conventional commits (enforced in CI eventually)
