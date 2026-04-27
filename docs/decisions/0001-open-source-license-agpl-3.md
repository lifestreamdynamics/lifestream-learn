# 0001 — Open-source the project under AGPL-3.0

- **Status:** Accepted (2026-04-18)
- **Deciders:** Eric

## Context

Lifestream Learn is planned as a commercial hosted SaaS. The question: should the code be open source, and if so under which license?

## Decision

**All three public sub-projects (`api`, `app`, `infra`) ship under AGPL-3.0-or-later.** The production `ops/` directory is held in a separate private repository and is not part of the public distribution.

## Consequences

- Anyone can self-host Lifestream Learn for their own content at zero license cost
- A competitor running a *modified* hosted version must publish their modifications (this is AGPL's copyleft trigger on network-delivered software — MIT/Apache would not offer this protection)
- The commercial offering is differentiated by the content catalogue, the hosted convenience, and operator support — not by code exclusivity
- Dual-licensing remains available if an enterprise customer requires a non-AGPL grant; keep that option open in CONTRIBUTING.md
- Some corporate contributors avoid AGPL; we accept this friction in exchange for the competitive moat

## Alternatives considered

- **MIT / Apache-2.0** — maximally permissive, but would let a well-funded competitor run a hosted clone against us without reciprocity
- **BSL (Business Source License)** — time-delayed open source, increasingly popular (HashiCorp, Sentry) but not OSI-approved and has real perception cost in the open-source community
- **Source-available proprietary** — loses most benefits of open sourcing (community, trust, self-host market)

## References

- [AGPL-3.0 text](https://www.gnu.org/licenses/agpl-3.0.en.html)
- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §Distribution model
