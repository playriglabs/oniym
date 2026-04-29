<!-- code-review-graph MCP tools -->

## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool                        | Use when                                               |
| --------------------------- | ------------------------------------------------------ |
| `detect_changes`            | Reviewing code changes — gives risk-scored analysis    |
| `get_review_context`        | Need source snippets for review — token-efficient      |
| `get_impact_radius`         | Understanding blast radius of a change                 |
| `get_affected_flows`        | Finding which execution paths are impacted             |
| `query_graph`               | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes`     | Finding functions/classes by name or keyword           |
| `get_architecture_overview` | Understanding high-level codebase structure            |
| `refactor_tool`             | Planning renames, finding dead code                    |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

---

## Design Context

### Users
Web3-native users who hold assets across multiple chains (ETH, SOL, BTC, SUI, BNB) and want a single human-readable identity instead of fragmented per-chain addresses. Context: they've felt the pain of copying long hex addresses, possibly lost funds to typos, or have multiple disconnected names (.eth, .sol, etc.). Job to be done: register one name (e.g. `alice.id`) that works everywhere — in wallets, dapps, and payment flows. Emotions to evoke: confidence ("this is legit"), delight ("this is slick"), and clarity ("I understand exactly what I'm getting").

### Brand Personality
**Precise. Native. Open.**
- Voice: direct, technically credible, never hype-y or crypto-bro. Speaks like a well-designed protocol, not a memecoin.
- Logo: geometric bracket/cursor icon + rounded sans wordmark "oniym". Clean, identity-forward.
- Accent: cyan `#14acc3` / `#85efff` — trust and clarity, not aggression.

### Aesthetic Direction
- **Dark mode first.** Near-black backgrounds (`#0a0a0f`, `#0f0f1a`), not pure black.
- **Monochromatic cyan accent only** — no purple gradients, no rainbow. Cyan on dark signals precision, not carnival.
- **ENS reference:** search-first layout, minimal chrome, every pixel earns its place. Trust over flash.
- **Hostinger reference:** conversion-optimized flow, clear pricing cards, step-by-step CTA path. Users know exactly what to do next.
- **Anti-references:** no generic "Web3 dark gradient neon" aesthetic, no floating orbs, no excessive glow effects.
- **Typography:** DM Sans for all prose + UI (already in docs theme). Bold geometric display weight for headlines. Fira Code (monospace) exclusively for domain names, addresses, and code — makes them feel precise and scannable.
- **TLD pre-selected in hero:** `.id` — universal and identity-forward (`alice.id`).

### Tech Stack (web/ app)
- Next.js 15 + App Router, scaffolded in `web/`
- React + TypeScript + Tailwind CSS
- wagmi + viem for wallet connection
- `@oniym/react` hooks for all contract reads/writes (already built in `react/` package)
- `@oniym/sdk` for namehash utilities
- Base Sepolia (testnet) → Base Mainnet

### Design Principles
1. **Search first, everything else follows.** The name search bar is the hero — not the headline, not the marketing copy. Every page element exists to funnel users toward that input.
2. **Names look like names.** Domain names and addresses always render in Fira Code. Never mix them with prose typography. This creates instant visual parsing.
3. **State communicates immediately.** Available = cyan pulse. Taken = muted red. Searching = animated skeleton. No ambiguity about where you are in the flow.
4. **Pricing is the aha moment.** $3/month or $15/year for any name, any length — this is the hook vs. ENS. Surface it early and make the math obvious.
5. **One clear next action.** At every step of the 3-step flow (Search → Select → Register), there is exactly one primary CTA. No option paralysis.
