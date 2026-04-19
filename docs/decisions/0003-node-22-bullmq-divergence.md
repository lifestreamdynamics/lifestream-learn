# 0003 — Node 22.12+ LTS and BullMQ (divergence from accounting-api baseline)

- **Status:** Accepted (2026-04-18)
- **Deciders:** Eric

## Context

The Lifestream ecosystem standard (set by `accounting-api`) is Node 20 and legacy `bull` ≥4 for background jobs. Lifestream Learn is greenfield, and the relevant upstreams have moved:

- **Node 22** entered Active LTS in October 2024 and is the current recommended version for new services (Maintenance LTS into 2027).
- **Prisma 7** — which we're adopting — requires Node 22.12.0 minimum.
- **`bull` has reached end-of-life in 2026**; only security fixes are accepted, and it does not track newer Node releases. The maintained successor is **BullMQ**, rewritten in TypeScript by the same team.

Matching the old stack on a brand-new service would mean adopting an EOL dependency on day one.

## Decision

- **Node 22.12+ LTS** for the `api` sub-project. Pinned in `.nvmrc` and `engines` field.
- **BullMQ ≥5** for background jobs. No use of `bull`.

## Consequences

- Divergence from `accounting-api` in queue API — BullMQ's `Queue` / `Worker` / `QueueEvents` classes are not the same as Bull's `Queue#process`. Queue code cannot be copy-pasted; it must be rewritten from scratch (already reflected in Phase 2 task list).
- The VPS must run Node 22.12+. VPS is already on 22.22.2 (verified), so no install step is required — only a brief regression check that `accounting-api` and `chatbot-api` still run under Node 22 (they declare `engines.node >= 18.0.0` so they should).
- When the broader ecosystem upgrades, `accounting-api` should migrate to BullMQ — but that is out of scope for this project.

## Alternatives considered

- **Stay on Node 20 + Bull** — would require pinning to Prisma 6 instead of 7 and accepting an EOL queue library. Short-term compatibility, long-term debt. Rejected.
- **Node 24** — current stable but not yet in LTS window for production. Too new for a service we intend to keep online for years.

## References

- [Node.js 22 LTS announcement](https://nodesource.com/blog/Node.js-v22-Long-Term-Support-LTS)
- [Prisma system requirements](https://www.prisma.io/docs/orm/reference/system-requirements)
- [BullMQ docs](https://docs.bullmq.io)
- [Bull vs BullMQ after Bull EOL 2026](https://pocketlantern.dev/briefs/bull-vs-bullmq-node-job-queue-performance-2026)
