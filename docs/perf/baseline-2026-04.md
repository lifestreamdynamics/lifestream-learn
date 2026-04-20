# learn-api performance baseline — 2026-04

Slice G2 deliverable. This is the reference document a future deployment
track will diff against.

**Status:** smoke run complete; full VUS=200 DURATION=30m run awaiting
operator execution on target hardware. Smoke numbers are included as a
sanity check, not as the authoritative baseline.

---

## 1. What this baseline measures

Scenario: a learner's steady-state session loop — login (once per VU
via `setup()`), then repeated:

| Step | Endpoint | Tag |
|---|---|---|
| Feed | `GET /api/feed` | `endpoint:api` |
| Course detail | `GET /api/courses/:id` | `endpoint:api` |
| Playback URL | `GET /api/videos/:id/playback` | `endpoint:api` |
| Master playlist | `GET <signed master.m3u8>` via nginx + SeaweedFS | `endpoint:hls-master` |
| Cue list | `GET /api/videos/:id/cues` | `endpoint:api` |
| Attempt submit | `POST /api/attempts` (MCQ, correct) | `endpoint:api` |
| Think time | `sleep(1..3s)` between iterations | — |

SLO thresholds (from IMPLEMENTATION_PLAN.md §5 Phase 7):

* API p95 &lt; 500ms
* HLS master TTFB p95 &lt; 1000ms
* `http_req_failed` &lt; 1% (k6 aborts the run if this breaches)

Scenario source: [`api/load/k6/learner-session.js`](../../api/load/k6/learner-session.js).

## 2. Stack configuration at measurement time

| Component | Version | Notes |
|---|---|---|
| Node | 22.x | per `.nvmrc` |
| learn-api | `npm run dev` (ts-node) | production build not yet stood up for load |
| prom-client | 15.1.x | `METRICS_ENABLED=true` |
| Postgres | accounting-postgres 17.x | shared container |
| Redis | accounting-redis 7.x | shared container |
| SeaweedFS | latest (per `infra/docker-compose.yml`) | local volume |
| tusd | latest | not exercised in this scenario |
| nginx | latest (per `infra/docker-compose.yml`) | `infra/nginx/local.conf` |
| k6 | v1.7.1 static binary in `~/.local/bin` | |

Tuning knobs applied for this run:

| Knob | Value | Source |
|---|---|---|
| `HTTP_KEEPALIVE_MS` | 65000 | `api/.env.local` |
| `HTTP_HEADERS_TIMEOUT_MS` | 66000 | `api/.env.local` |
| `RATE_LIMIT_LOGIN_MAX` | 500 | `api/.env.local` (raised from prod default 5 for the duration of the run) |
| Prisma pool | default (no `?connection_limit`) | — |
| nginx `worker_connections` | upstream default (not tuned) | `local.conf` is an include, not `nginx.conf`; top-level tuning deferred to deployment track |
| SeaweedFS connection limits | default | no bottleneck observed at smoke scale |

## 3. Smoke run — 2026-04-19

Fast-check the scenario works end-to-end before committing to the full
30-minute baseline. Not intended as the authoritative number.

```bash
cd api
# Raise login ceiling; drop rate-limit state from any prior run.
# (env.local change + nodemon touch of src/config/env.ts applied.)
REDIS_PASS=$(grep -E '^REDIS_URL=' .env.local | sed -E 's|.*://:([^@]+)@.*|\1|')
docker exec accounting-redis redis-cli -a "$REDIS_PASS" --no-auth-warning \
  DEL 'learn:rl:auth:login:::ffff:127.0.0.1' > /dev/null

# Seed.
npx ts-node -r tsconfig-paths/register --transpile-only load/seed.ts --learners 10
# Copy-paste the LEARN_LOAD_* block that seed.ts prints, then run:
k6 run -e VUS=10 -e DURATION=30s -e RAMP=5s load/k6/learner-session.js
```

### Smoke-run results

* **Checks:** 1,134/1,134 pass (0 failures across 189 iterations).
* **`http_req_failed`:** 0.00%.
* **API p95:** 8.67ms (5,778× headroom vs. 500ms threshold).
* **HLS master p95:** 4.16ms (240× headroom vs. 1000ms threshold).
* **Throughput:** 24 req/s sustained from 10 VUs.
* **No UUID cardinality leak** in prometheus labels (verified via `curl /metrics | grep -E '^learn_http_requests_total'`).

The smoke numbers are dominated by localhost network latency, not actual
service work — the scenario's signed HLS fetch reads ~230 bytes from the
SeaweedFS bucket. These numbers prove the scenario *works*; they don't
characterise the system under stress.

## 4. Full baseline — VUS=200 DURATION=30m

**Operator action.** Run on the target dev box, not over CI. Record the
k6 end-of-run summary and a one-shot `/metrics` scrape immediately
after.

```bash
cd api
REDIS_PASS=$(grep -E '^REDIS_URL=' .env.local | sed -E 's|.*://:([^@]+)@.*|\1|')
docker exec accounting-redis redis-cli -a "$REDIS_PASS" --no-auth-warning \
  DEL 'learn:rl:auth:login:::ffff:127.0.0.1' > /dev/null

npx ts-node -r tsconfig-paths/register --transpile-only load/seed.ts --learners 200
# ...copy-paste the LEARN_LOAD_* block...
k6 run --summary-export /tmp/learn-k6-summary.json load/k6/learner-session.js
curl -s http://localhost:3011/metrics > /tmp/learn-metrics-post-run.txt
```

### Full-run results

> _Paste the k6 end-of-run summary block below after the run completes._

```
[ awaiting operator full-scale run ]
```

### `/metrics` snapshot (top families)

> _After the run, paste the output of:_
>
> ```bash
> grep -E '^learn_(http_request_duration_seconds_count|http_request_duration_seconds_bucket|http_requests_total|playback_signed_urls_total|transcode_queue_depth|nodejs_eventloop_lag_p(50|95)_seconds) ' /tmp/learn-metrics-post-run.txt | head -60
> ```

```
[ awaiting operator full-scale run ]
```

### Hardware

> _Record:_
>
> ```
> CPU: <model>
> RAM: <size>
> Disk: <type>
> OS: <uname -a>
> Concurrent services: accounting-{postgres,redis,api}, infra-{seaweedfs,tusd,nginx}
> ```

## 5. Interpretation guidance

When comparing a future run against this baseline:

* **API p95 > 500ms** → investigate Postgres pool saturation (`pg_stat_activity` queue depth), Prisma's default `connection_limit = num_physical_cpus × 2 + 1` may be the ceiling.
* **HLS master p95 > 1000ms** → SeaweedFS S3 read path. Check nginx `proxy_buffering` + SeaweedFS worker count.
* **`http_req_failed > 1%`** → check the top status codes in `/metrics`. 429 suggests `RATE_LIMIT_*` configured lower than the VU count; 401 suggests `setup()` token expiry.
* **Event-loop lag > 100ms** in `/metrics` (`learn_nodejs_eventloop_lag_p95_seconds`) → API is CPU-bound; consider `cluster`/PM2 before deployment.

## 6. Known limitations of this baseline

* **Scenario skips per-segment HLS fetches.** Each segment needs its own
  secure_link signature and the API doesn't expose a per-segment
  signing endpoint (master only). The segment path *is* exercised in
  the nginx BATS suite and — once Slice G3 lands — via a dedicated
  integration test.
* **Seeded HLS content is placeholder bytes.** Master playlist +
  variant playlists parse correctly; segments are single-byte files.
  Real-content throughput testing belongs to the deployment track.
* **Single-IP-source distortion.** All k6 VUs come from `127.0.0.1`,
  so the run stresses a single client-IP codepath (rate-limiting,
  keepalive pool). Distributed load from N client IPs will hit
  different bottlenecks — also deployment-track work.
* **Dev build, not production build.** `npm run dev` runs via ts-node.
  A `npm run build && npm start` comparison is worth running once; it
  typically shifts `avg` down by 10-20% with no effect on p95.

## 7. Changelog

| Date | What changed | Why |
|---|---|---|
| 2026-04-19 | Initial doc (smoke run only) | Slice G2 scaffolding |
| _(pending)_ | Full VUS=200/30m numbers | Operator baseline run |
