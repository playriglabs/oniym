# @oniym/sdk

TypeScript SDK for [Oniym](https://oniym.xyz) — a multichain-native naming service built by [Playriglabs](https://playriglabs.fun).

## Install

```bash
pnpm add @oniym/sdk viem
```

## Quick start

```typescript
import { namehash } from "@oniym/sdk";

// Compute the namehash of a name (ENSIP-1 compatible)
const node = namehash("kyy.oniym");
// → 0x...
```

Full client API (`resolve`, `lookup`, `register`) ships in v0.1. The current release exports cryptographic primitives only.

## Compatibility

- Node.js 20+
- All modern browsers (ES2022)
- ENSIP-1 namehash compatible — drop-in replacement for `viem`'s `namehash()` when you need matching semantics

## License

MIT © [Playriglabs](https://playriglabs.fun)
