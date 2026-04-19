# 0002 — Use SeaweedFS (not MinIO) for S3-compatible object storage

- **Status:** Accepted (2026-04-18)
- **Deciders:** Eric
- **Depends on:** [0001 (AGPL licensing)](./0001-open-source-license-agpl-3.md)

## Context

We need an S3-compatible object store (local for now, self-hosted or cloud later) to hold raw video uploads and transcoded HLS segments. The abstraction matters: writing against the S3 SDK means we can migrate between AWS S3, Cloudflare R2, Backblaze B2, or a self-hosted instance by changing an endpoint rather than refactoring.

Originally the plan called for MinIO. MinIO is the most widely deployed self-hosted S3 implementation, well-documented, single-binary, and operationally proven. However:

- MinIO is licensed **AGPL-3.0**
- MinIO Inc. has been enforcing AGPL obligations against commercial users aggressively in 2025-2026
- Since Lifestream Learn's own code is going open source under AGPL (decision 0001), the "we're open source too" defence does not cleanly extend to the storage operator's obligations

## Decision

**Use [SeaweedFS](https://github.com/seaweedfs/seaweedfs) (Apache-2.0) as the object store.** Single-binary deploy, native S3 API (`weed -s3`), active project, permissive license.

## Consequences

- Less industry familiarity than MinIO; fewer Stack Overflow answers and fewer ops-oriented war stories
- Accept a Phase 1 smoke-test risk: if SeaweedFS proves operationally painful, fall back to filesystem-backed storage behind an S3-compatible shim (same abstraction surface)
- No AGPL exposure from the storage layer; cleanest legal posture for the hosted service
- Migration target unchanged: AWS S3 / R2 / B2 if and when self-hosting becomes the wrong tradeoff

## Alternatives considered

- **MinIO** — rejected on licensing risk for a commercial SaaS
- **Garage** (garagehq.deuxfleurs.fr) — AGPL, community-run, smaller footprint but less mature S3 API coverage
- **Ceph RGW** — overkill at MVP scale; operator burden far exceeds benefit
- **Plain filesystem + S3-compatible shim** (e.g. `s3proxy`) — possible fallback if SeaweedFS underperforms

## References

- [SeaweedFS repo](https://github.com/seaweedfs/seaweedfs)
- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §2 Technology Decisions
