# Phase 3 — Upload, Transcode, Playback

**Status:** Current (Phase 3 in flight, exit criteria all green or polish-only as of 2026-04-20).
**Authoritative source files:** see [Pointers](#pointers) at the bottom.

## Purpose

Describes the pipeline that takes a raw video a course designer uploads from the Flutter app and turns it into an HLS ladder a learner's app can play back behind signed URLs. Written at "architect reading new code" level of detail — if you can follow this doc, you can find the exact lines in `api/src/` that implement each step.

## Pipeline at a glance

```
 Flutter App (designer)                Local compose stack
 ────────────────────                  ──────────────────────────────────
                                      ┌────────────────────────────┐
  POST /api/videos ─────────────────► │ learn-api :3011            │
                                      │  └ Video row (UPLOADING)   │
     { videoId, uploadUrl,            │                            │
       sourceKey }                    │                            │
                                      └──────┬─────────────────────┘
                                             │ returns {videoId,
                                             │  uploadUrl, headers}
 tus POST + PATCH ──────────────────► ┌──────▼─────────┐
                                      │ tusd :1080     │
                                      │   (resumable)  │
                                      │   writes to    │
                                      │   SeaweedFS    │
                                      └──────┬─────────┘
                                             │  pre-finish hook
                                             ▼
                                      ┌──────────────────────────────┐
                                      │ POST /internal/hooks/tusd    │
                                      │   (shared-secret,            │
                                      │    rate-limited)             │
                                      │  └ enqueueTranscode()        │
                                      └──────┬───────────────────────┘
                                             │ learn:transcode job
                                             ▼
                                      ┌──────────────────────────────┐
                                      │ learn-transcode-worker       │
                                      │  1. download source          │
                                      │  2. ffprobe                  │
                                      │  3. FFmpeg CMAF fMP4 HLS     │
                                      │     ladder (360/540/720/1080)│
                                      │  4. upload variants first,   │
                                      │     master.m3u8 last         │
                                      │  5. status → READY           │
                                      │  6. delete source            │
                                      └──────┬───────────────────────┘
                                             │
 GET /api/videos/:id/playback ──────► ┌──────▼─────────┐
     (auth + enrollment check)         │ signPlaybackUrl │
                                       │   md5 secure_link│
                                       │   TTL 2h        │
                                       └──────┬──────────┘
  { masterPlaylistUrl } ◄──────────────────── │
                                              │
  GET {masterPlaylistUrl} ────────────► ┌─────▼────────────┐
                                        │ nginx :8090/hls/ │
                                        │  secure_link     │
                                        │  validation      │
                                        └─────┬────────────┘
                                              │ if md5 ok, proxy
  HLS variant + segments ◄─────────────       │ to SeaweedFS
                                        ┌─────▼───────────┐
                                        │ SeaweedFS       │
                                        │  learn-vod      │
                                        │  bucket         │
                                        └─────────────────┘
```

## Upload

**Endpoint:** `POST /api/videos` — `COURSE_DESIGNER | ADMIN` only.

1. Caller submits `{courseId, title, orderIndex}`. Authorization is enforced via `hasCourseAccess(role, userId, course, 'WRITE')` — admin, course owner, or collaborator.
2. The controller generates a fresh UUID up-front (`randomUUID()`) and writes a `Video` row with `status=UPLOADING` and `sourceKey='uploads/<videoId>'`. This pre-commits the storage key so tusd's write lands deterministically.
3. The response includes `uploadUrl` (the public tusd URL), `uploadHeaders` (Tus-Resumable + Upload-Metadata carrying the videoId in base64), and the `sourceKey` for diagnostic logging.

The Flutter client uses `tus_client_dart` for a resumable upload of chunks to `uploads/<videoId>` in the `learn-uploads` SeaweedFS bucket.

## tusd pre-finish hook

**Endpoint:** `POST /internal/hooks/tusd` — service-to-service, never exposed to clients.

Authentication: shared-secret `TUSD_HOOK_SECRET`. Comparison uses SHA-256 digest + `timingSafeEqual` so missing/short/long tokens all hit the same code path — no length-branch side channel. The `?token=` query-param fallback is honoured only in non-production; in prod the `X-Tusd-Hook-Token` header is the only accepted conduit.

Rate limit: Redis-backed `express-rate-limit` at 60 deliveries / minute / IP. A leaked secret can't translate into unbounded transcode enqueues.

Validated payload:
- `Type === 'pre-finish'` is the actionable event. Other types (`post-finish`, etc.) are 200 no-ops.
- `Event.Upload.MetaData.videoId` must be a UUID (regex-checked before Prisma lookup).
- `Event.Upload.Storage.Key` (or fallback `Event.Upload.ID`) is the object key tusd wrote to.

Action: `enqueueTranscode({videoId, sourceKey})` writes a job to the `learn:transcode` BullMQ queue, keyed by `videoId` (so retries/duplicates collapse to one job).

## Transcode worker

Separate Node process (`npm run worker:transcode:dev`). Does not share an event loop with the API. Boot-time it logs the detected `ffprobe` version and warns if below 6.0.

For each job the pipeline:

1. Transitions the `Video` row `UPLOADING → TRANSCODING`. Idempotent: a Prisma `P2025` (already moved by a prior attempt) is swallowed.
2. Downloads the source via `ObjectStore.downloadToFile` into a per-job temp directory.
3. `ffprobe` checks duration against `VIDEO_MAX_DURATION_MS`. Too-long sources short-circuit to `FAILED`.
4. `FFmpeg` produces an H.264 + AAC CMAF fMP4 HLS ladder. The ladder is filtered by source height — no upscaling. Rungs live in `src/services/ffmpeg/ladder.ts` (360/540/720/1080 currently).
5. Upload order is load-bearing: all variant segments + `index.m3u8` first, **master.m3u8 last**. A client polling early never reads an incomplete master. Not atomic — a crash mid-master-upload leaves a 0-byte master, which nginx 404s and the client retries.
6. On success: `Video.status=READY`, `hlsPrefix=vod/<videoId>`, `durationMs` set, raw source deleted from `learn-uploads` (ADR 0006 retention policy).
7. On failure after `attempts=3` + exponential backoff, BullMQ's `failed` event handler sets `Video.status=FAILED`.

## Playback URL issuance

**Endpoint:** `GET /api/videos/:id/playback` — any authenticated user. Returns a signed master URL plus expiry.

Authorization: `videoService.canAccessVideo` → `hasCourseAccess(..., 'READ')`. Allowed for: admin, course owner, collaborator, or **enrolled** learner. Returns 403 on miss, 404 on missing video, 409 if `status !== READY`.

Signing: `signPlaybackUrl(path)` in `api/src/utils/hls-signer.ts`:
- Computes MD5 over `${expires}${path} ${HLS_SIGNING_SECRET}` (the space separator + secret position are mandated by nginx's stock `secure_link_md5` directive).
- Base64-url encodes the digest, strips padding.
- Appends `?md5=<hash>&expires=<unix_timestamp>` to `HLS_BASE_URL` + path.
- TTL = `HLS_SIGNING_TTL_SECONDS` (default 7200s).

The `HLS_SIGNING_SECRET` env var has a 32-byte minimum to keep brute-force out of reach.

## nginx secure_link validation

Every request under `/hls/` passes through nginx's `secure_link_md5`. If the computed hash doesn't match `$arg_md5` → 403. If `$arg_expires` is in the past → 410. Validation is per-request: the master, every variant playlist, and every segment all need their own signature. The client library (`video_player` + ExoPlayer on Android) handles the plumbing.

The positive path is exercised end-to-end by `tests/integration/transcode-e2e.test.ts` (signed master + variant + segment fetch). The tamper/expiry paths are exercised by `tests/integration/secure-link.test.ts` against the nginx layer directly.

## Migration seams

Three interfaces keep this pipeline portable without rewrites (see `IMPLEMENTATION_PLAN.md` §7):

- **`ObjectStore`** — wraps all S3 SDK calls. Swap `S3_ENDPOINT` → R2, S3, Backblaze, etc. without code changes.
- **`VideoTranscoder`** — `transcode(sourceKey) → hlsPrefix` contract. The FFmpeg-in-BullMQ implementation can be replaced with AWS MediaConvert or Cloudflare Stream by swapping the pipeline only.
- **`getPlaybackUrl` / `signPlaybackUrl`** — single function to replace for CloudFront, Cloudflare Stream tokens, etc.

CMAF fMP4 output is also portable across CloudFront, Cloudflare, Bunny, Fastly.

## Authorization model

All course-scoped access is gated through `api/src/services/course-access.ts#hasCourseAccess`. Two tiers:

| Access level | Admin | Owner | Collaborator | Enrolled learner | Stranger |
|---|---|---|---|---|---|
| `READ` (playback, cue listing, attempt submission) | ✓ | ✓ | ✓ | ✓ | ✗ |
| `WRITE` (video create, cue create/update/delete) | ✓ | ✓ | ✓ | ✗ | ✗ |

The explicit enforcement that "enrollment implies READ, never WRITE" is covered by integration tests in `tests/integration/cues-api.test.ts` under `IDOR regression`.

## Security posture

- Refresh tokens rotate on every `/api/auth/refresh`; the old `jti` is revoked in Redis (`learn:refresh-revoked:<jti>`, 30d TTL). Replay is rejected.
- Access tokens carry an `aud: 'learn-api'` claim, validated on decode. Claim payload shape is Zod-validated after `jwt.verify` succeeds.
- tusd hook: SHA-256-digest timing-safe compare, rate-limited.
- Helmet CSP is restricted (JSON API, no inline scripts, no frame ancestors). `frameguard: deny`.
- No user input reaches `$queryRaw` / `$executeRaw`. All Prisma calls are parameterized.
- Grading happens server-side only — cue payload's correct answer is never returned to the client.

## Known gaps (polish, non-blocking)

- Bull Board / BullMQ dashboard not mounted.
- Master-playlist upload is best-effort-atomic (not fsync-then-rename). Acceptable today; client retries cover it.
- SHA-256 secure_link upgrade is available in newer nginx builds; not adopted yet (ADR 0002 documents the migration path).

## Pointers

| Concern | File |
|---|---|
| Video create + playback controller | `api/src/controllers/videos.controller.ts` |
| Video service (authz + state transitions) | `api/src/services/video.service.ts` |
| Course-access predicate | `api/src/services/course-access.ts` |
| tusd hook | `api/src/controllers/tusd-hooks.controller.ts`, `api/src/routes/internal-hooks.routes.ts` |
| Rate limiters | `api/src/middleware/rate-limit.ts` |
| Transcode queue | `api/src/queues/transcode.queue.ts`, `api/src/queues/transcode.types.ts` |
| Transcode worker entrypoint | `api/src/workers/transcode.ts` |
| Transcode pipeline (unit-testable) | `api/src/workers/transcode.pipeline.ts` |
| FFmpeg args + ladder + version check | `api/src/services/ffmpeg/*` |
| ObjectStore interface | `api/src/services/object-store.ts` |
| HLS signer | `api/src/utils/hls-signer.ts` |
| JWT utilities | `api/src/utils/jwt.ts` |
| Refresh-token revocation | `api/src/services/refresh-token-store.ts` |
| nginx secure_link config | `infra/nginx/local.conf`, `infra/nginx/secure_link.conf.inc` |
| Signed-URL shell helper | `infra/scripts/sign-hls-url.sh` |
| Integration: upload→transcode→playback | `api/tests/integration/transcode-e2e.test.ts` |
| Integration: worker kill/resume | `api/tests/integration/transcode-resilience.test.ts` |
| Integration: secure_link edge cases | `api/tests/integration/secure-link.test.ts` |
| Integration: IDOR regressions | `api/tests/integration/videos-api.test.ts`, `cues-api.test.ts`, `attempts-api.test.ts` |
