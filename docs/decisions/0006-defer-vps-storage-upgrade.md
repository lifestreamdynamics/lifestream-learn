# 0006 — Storage-conscious guardrails (duration cap + delete raw on transcode)

- **Status:** Accepted (2026-04-19, updated to remove deployment framing)
- **Deciders:** Eric

## Context

Wherever this project eventually runs, storage for raw uploads + HLS ladders will be finite. Even at MVP scale, a few carelessly long 1080p uploads can exhaust a small disk. We want storage-conscious behaviour baked into the app's design rather than discovered under pressure.

## Decision

Two guardrails live in the app itself, independent of deployment:

1. **Video duration cap at the API layer.** Reject uploads whose metadata declares a duration longer than a configurable cap (default: 180 seconds). Enforced in Phase 3 when `POST /api/videos` lands.
2. **Delete the raw upload after successful transcode.** The transcode worker removes the source object from `learn-uploads/` once the HLS ladder is published to `learn-vod/`. Re-transcoding a video therefore requires re-upload — acceptable at this scale, and roughly halves per-video storage cost.

A third guardrail — a disk-usage alert — lives in `infra/scripts/disk-alert.sh`. It's written and tested but isn't wired into any scheduler today; that's a deployment concern and picks up when we tackle deploy.

## Consequences

- App behaviour is self-limiting in storage footprint regardless of the hosting target.
- Re-transcoding requires re-upload. Accept this for MVP; if it becomes a real pain point, revisit (keep raw for 24h, archive tier, etc.).
- The duration cap needs a matching client-side hint in the Flutter uploader so designers aren't surprised by a late reject.

## Alternatives considered

- **No app-level guardrails, rely entirely on operator alerts.** Rejected — turns a design problem into a paging problem, and every self-hoster has to solve it themselves.
- **Keep raw uploads forever, pay for more storage.** Not a design question; defer to whoever runs the instance.
- **Aggressive transcode tiering / cold storage.** Premature. Revisit only if actual usage makes it worth the complexity.

## References

- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §Phase 3 (Upload + Transcode Pipeline)
- [`infra/scripts/disk-alert.sh`](../../infra/scripts/disk-alert.sh) — standalone watchdog, wired later
