# @oniym/sdk

TypeScript SDK for [Oniym](https://oniym.xyz) — a multichain naming service built by [Playriglabs](https://playriglabs.fun).

## Install

```bash
pnpm add @oniym/sdk viem
```

## Quick start

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

// Available TLDs (.id .one .wagmi .degen …)
const tlds = await oniym.getTLDs();
```

### Low-level utilities

```typescript
import { namehash, labelhash } from "@oniym/sdk";

// ENSIP-1 namehash (same as viem's namehash)
const node = namehash("kyy.id");  // 0x...
```

## Supported TLDs

62 web-style, chain-neutral TLDs (each ≤ 5 chars):

```
.id   .one  .me   .xyz  .web3 .io   .app  .dev  .onm  .go
.ape  .fud  .hodl .fomo .moon .rekt .wagmi .ngmi .degen .whale
.buidl .dyor .pump .alpha .safu .gm  .lfg  .ser  .fren .goat
.cope .pepe .mint .bear .gas  .dao  .ath  .dex  .cex  .burn
.node .swap .yield .bag  .bags .seed .drop .stake .pool .wrap
.farm .shill .xxx  .regs .main .test .exit .fair .guh  .bots
.vcs  .keys
```

Any TLD name stores and resolves addresses for **all** supported chains — TLD is an identity preference, not a chain restriction.

## Supported chains

| Chain | SLIP-0044 coinType |
|-------|-------------------|
| BTC   | 0 |
| ETH   | 60 |
| SOL   | 501 |
| SUI   | 784 |
| BNB   | 714 |

## Compatibility

- Node.js 24+
- All modern browsers (ES2022)
- ENSIP-1 namehash compatible — drop-in replacement for `viem`'s `namehash()` when you need matching semantics

## License

MIT © [Playriglabs](https://playriglabs.fun)
