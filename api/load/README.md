# api/load — k6 baseline load testing

Slice G2 of Phase 7. Local-only. No Grafana, no remote-write — k6's own
summary + a one-shot `/metrics` scrape is enough signal for the baseline
doc (`docs/perf/baseline-2026-04.md`). Deployment-track dashboarding
comes later.

## 1. Install k6

One-shot static binary, no sudo:

```bash
cd /tmp
curl -sSL -o k6.tgz \
  https://github.com/grafana/k6/releases/download/v1.7.1/k6-v1.7.1-linux-amd64.tar.gz
tar -xzf k6.tgz
mkdir -p "$HOME/.local/bin"
mv k6-v1.7.1-linux-amd64/k6 "$HOME/.local/bin/k6"
chmod +x "$HOME/.local/bin/k6"
rm -rf k6.tgz k6-v1.7.1-linux-amd64
k6 version
```

Homebrew on macOS: `brew install k6`. Either way, confirm `k6 version`
reports ≥1.7.

The binary is **not** committed to the repo.

## 2. Prereqs

* `docker compose up -d` in `infra/` — SeaweedFS + tusd + nginx
  must be running, and `learn-uploads` / `learn-vod` buckets must exist
  (`./infra/scripts/create-buckets.sh`).
* `accounting-postgres` + `accounting-redis` running.
* Local API on `:3011`. Enable `/metrics` with `METRICS_ENABLED=true`
  in `api/.env.local` and restart `npm run dev`.
* `learn_api_development` migrated to the latest schema
  (`npm run prisma:migrate`).

## 3. Seed the local stack

```bash
cd api
# Defaults: 200 load-test learners.
npx ts-node -r tsconfig-paths/register --transpile-only load/seed.ts

# Smaller N (quicker seed for smoke runs):
npx ts-node -r tsconfig-paths/register --transpile-only load/seed.ts --learners 10
```

The seeder is idempotent. It refuses to run against `learn_api_test`,
`learn_api_production`, or with `NODE_ENV=production` (the integration
suite owns the test DB; production is obvious).

What it creates:

* `load-designer@example.local` (COURSE_DESIGNER)
* `Load Test Course` (published)
* One `READY` video with a minimal HLS ladder written directly to
  `learn-vod` (it's **not** a real transcode — the pipeline has its own
  integration tests, and coupling the seed to FFmpeg would bloat the
  seed time beyond "quickly reproducible")
* Three cues (MCQ + BLANKS + MATCHING)
* `load-learner-0000 .. load-learner-{N-1}@example.local`, all
  enrolled in the course
* All users share password `CorrectHorseBattery1` (dev-only)

The seeder prints a `---` block of `LEARN_LOAD_*` env vars to stdout.
Copy that block into your shell:

```bash
# Paste the block shown at the end of `seed.ts` output, e.g.:
export LEARN_LOAD_DESIGNER_EMAIL=load-designer@example.local
export LEARN_LOAD_PASSWORD=CorrectHorseBattery1
export LEARN_LOAD_COURSE_ID=<uuid>
export LEARN_LOAD_VIDEO_ID=<uuid>
export LEARN_LOAD_LEARNER_PREFIX=load-learner-
export LEARN_LOAD_LEARNER_COUNT=200
```

### Raise the login rate-limit ceiling for the run

`setup()` logs every VU in at the start of the run. At 200 VU from a
single loopback IP, that punches through the default
`RATE_LIMIT_LOGIN_MAX=5` immediately. Set a higher ceiling in
`api/.env.local` for the duration of the run and restart the dev
server (nodemon picks up `.env` changes only if you touch a `.ts`):

```bash
# api/.env.local
RATE_LIMIT_LOGIN_MAX=500
RATE_LIMIT_LOGIN_WINDOW_MS=300000
```

Put it back to `5` (or omit for default) after the run. The env vars
are Slice-G2 additions; pre-G2 deployments are unaffected.

If you hit 429s anyway (state from an earlier run lingering), drop the
rate-limit keys in Redis directly:

```bash
REDIS_PASS=$(grep -E '^REDIS_URL=' api/.env.local | sed -E 's|.*://:([^@]+)@.*|\1|')
docker exec accounting-redis redis-cli -a "$REDIS_PASS" --no-auth-warning \
  DEL 'learn:rl:auth:login:::ffff:127.0.0.1'
```

## 4. Smoke run (10 VU, 60s)

Prove the scenario works before committing to the full baseline:

```bash
k6 run \
  -e VUS=10 -e DURATION=60s -e RAMP=5s \
  load/k6/learner-session.js
```

Expected: scenario completes with http_req_failed < 1%. p95s will vary
— what we want to see is a clean summary with non-zero counts on every
`endpoint:api` bucket.

## 5. Full baseline (200 VU, 30 min)

**Operator-driven.** Takes the full 30 minutes plus a ~1 minute ramp.
Record the run in `docs/perf/baseline-2026-04.md`.

```bash
# Optional: rate-limit turns into a threat at 200 VU. Slice G2 keeps the
# existing rate-limit config; each VU is pinned to a deterministic
# learner so the signup / login limiters see natural per-IP patterns. If
# you hit login 429s in the summary, note it in the baseline doc and
# revisit in Slice G3.

k6 run \
  --summary-export /tmp/learn-k6-summary.json \
  load/k6/learner-session.js

# Snapshot /metrics once, immediately after:
curl -s http://localhost:3011/metrics > /tmp/learn-metrics-post-run.txt
```

Then paste the k6 end-of-run summary + `/tmp/learn-metrics-post-run.txt`
into `docs/perf/baseline-2026-04.md`.

## 6. Tearing down

The seed is idempotent and leaves rows in `learn_api_development`; those
rows stay for the next run. If you need a clean slate:

```bash
cd api
# Nukes and recreates the dev DB — only do this in local dev.
npm run prisma:migrate -- reset --skip-seed --force
npx ts-node -r tsconfig-paths/register --transpile-only load/seed.ts
```

## 7. Known limitations

* The HLS ladder is written as placeholder bytes. Master playlist parses
  correctly and secure_link validates the path, but the segments are
  single-byte files — this baseline stresses the API + signing + nginx
  header path, **not** SeaweedFS's throughput for real video content.
  Real-content throughput testing belongs to the deployment track.
* Segment fetch is deliberately excluded from the scenario: each segment
  URL needs its own nginx-`secure_link` signature, and the API doesn't
  expose per-segment signing today (only master). The master fetch
  itself exercises the secure_link path end-to-end, which is sufficient
  for the p95<1000ms SLO.
* 200 VU is the plan's nominal target. If the dev box can't sustain it
  (fan noise, event-loop lag > 100ms in `/metrics`), record the actual
  ceiling reached in the baseline doc — SLO thresholds still apply at
  that ceiling. Don't chase numbers that misrepresent reality.
