# ADR-005: Playriglabs-first branding

- **Status:** Accepted
- **Date:** 2026-04-22
- **Deciders:** Core team

## Context

Oniym is being built by [Playriglabs](https://playriglabs.fun), a Web3 & AI product consultancy. At the point of public launch, we need to decide how Oniym is branded and attributed:

1. **Oniym as standalone brand** — Playriglabs invisible in public surface
2. **Oniym by Playriglabs** — co-branded, both visible
3. **Playriglabs-first** — Oniym as a product line within the Playriglabs portfolio

This affects:

- GitHub org and repo URL
- NPM scope
- Copyright attribution
- Landing page messaging
- Social presence and launch narrative

## Decision

**Playriglabs-first: Oniym is positioned as a product line within the Playriglabs portfolio.**

- Repo lives at `github.com/playriglabs/oniym`
- Copyright held by Playriglabs
- Landing page and README explicitly attribute to Playriglabs
- NPM scope remains `@oniym/*` for product-level discoverability
- Domain `oniym.xyz` is retained for product identity

## Rationale

1. **Builds Playriglabs as a "builder, not just consultant" brand.** Shipping a real production protocol is the strongest possible proof point for a consultancy. Clients evaluating Playriglabs see evidence of shipped work, not just deck-ware.

2. **Unifies future products under one umbrella.** If Playriglabs ships additional products in the future, they fit cleanly into the same portfolio without fragmenting brand equity.

3. **Simplifies legal and operational surface area.** One copyright holder, one liability boundary, one set of legal documents reusable across products.

4. **Enhances the team's storytelling.** Public narrative becomes "Playriglabs ships Oniym" rather than "solo side project." This matters for team credibility, hiring, and client trust.

5. **Preserves product-level identity where it matters.** NPM scope `@oniym/*` and domain `oniym.xyz` ensure developers and users still interact with the product on its own terms. Branding attribution happens at the README, landing page, and footer level — not at the import path.

### Positive

- Playriglabs gains a concrete case study
- Oniym benefits from Playriglabs' professional association
- Clear hierarchy for future products under the same org
- Single legal entity simplifies revenue handling and contracts

### Negative

- Users must make two connections ("Oniym" and "Playriglabs") to understand provenance
- If Oniym outgrows Playriglabs as a standalone venture, a future brand split requires migration work

### Mitigations

- Co-branding at visible surfaces (README, landing page footer, launch posts) keeps both identities clear
- NPM scope and domain are independent of company — future spin-off is possible without changing developer-facing identifiers
- ADR is revisited if product traction warrants separation

## References

- [Playriglabs](https://playriglabs.fun)
- [Oniym product site](https://oniym.xyz)
