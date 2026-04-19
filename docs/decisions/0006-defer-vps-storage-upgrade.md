# 0006 — Defer VPS storage upgrade to post-MVP

- **Status:** Accepted (2026-04-19)
- **Deciders:** Eric

## Context

The VPS prerequisite check on 2026-04-18 found 38 GB free on a single 79 GB volume, below the plan's 100 GB target. The recommended mitigation was attaching a Linode Block Storage volume (~$10/mo) before Phase 1. However, MVP content volume will be small — a handful of test/demo videos totalling a few GB at most during the closed beta.

## Decision

**Ship MVP on the existing 38 GB free space.** No block-storage volume attached at this phase. Storage scaling — attaching a dedicated SeaweedFS volume — is revisited post-MVP when real content volume or learner traffic justifies the cost and operational change.

Guardrails for staying inside current headroom:

- Enforce a conservative video duration cap (e.g. 90-180 seconds) at the API layer; tune as we learn.
- Keep raw uploads only until a successful transcode, then delete the source (saves ~50% per video).
- Add a dashboard / alert that flags when `/var/lib/seaweedfs` crosses 25 GB (two-thirds of free space) so we get early warning.

## Consequences

- MVP launch cost stays at current VPS subscription — no incremental infra spend
- Closed beta capacity ceiling is real: roughly 40-60 short videos depending on duration and ladder. Sufficient for pilot content; insufficient for public launch
- Post-MVP storage-upgrade work is written down as a follow-up task and sized ahead of time, not discovered under pressure
- Retaining raw uploads is dropped from the MVP scope; re-transcoding a video requires re-upload. Worth it at this scale

## Alternatives considered

- **Attach Linode Block Storage volume (~$10/mo) now** — recommended by the prereq report. Rejected for MVP given small content volume; keep as the primary upgrade path
- **Aggressive duration cap + keep raw uploads** — more complexity for marginal gain; cap alone is simpler
- **Move HLS output to a cheaper cold-storage tier** — premature optimisation for MVP

## References

- [`ops/vps-prereq-check-2026-04-18.md`](../../ops/vps-prereq-check-2026-04-18.md) — source findings (private)
- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §Phase 1
