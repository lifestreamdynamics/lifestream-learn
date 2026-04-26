# Findings outside the cycle scope

Surfaced during the 2026-04-26 plan-validation-and-review pass for plan
`examine-the-project-roadmap-sunny-patterson`. These items exist in code
that was either not modified by this cycle's plan, or whose root cause
sits in third-party packages outside our control.

Each entry is captured here for the operator to triage; none are auto-fixed.

## 2026-04-26

### AWS SDK + Jest classic VM: dynamic-import friction in compose-dependent integration tests

- **File**: `api/tests/integration/health.test.ts:13`
- **Category**: TEST_INFRASTRUCTURE
- **Symptom**: `health` (and indirectly `transcode-e2e`, `transcode-resilience`) integration suites fail at runtime with `ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING_FLAG`. The AWS SDK v3 lazily `await import('node:http')` and `await import('@smithy/credential-provider-imds')` inside its middleware chain. Jest's classic VM rejects dynamic imports without `--experimental-vm-modules`.
- **Mitigation already applied** (in scope, did not fix the test): `api/src/config/s3.ts` now eagerly constructs a `NodeHttpHandler` with pre-built http/https Agents and forces `defaultsMode: 'standard'` so the SDK doesn't probe IMDS. This shaves first-request latency in production. The deepest middleware path is still impacted under Jest.
- **Production status**: Unaffected. Manually verified `/health` returns `s3:ok` against the running compose stack (2026-04-26).
- **Next action (Phase 8 backlog)**: Either migrate the integration suite to ESM Jest (`--experimental-vm-modules` + `transformIgnorePatterns` rewrite for `@scure`/`@noble`), or vendor a thinner S3 client. Tracked in `IMPLEMENTATION_PLAN.md` §5 Phase 8 backlog.

### transcode-e2e + transcode-resilience integration suites: require running worker

- **Files**: `api/tests/integration/transcode-e2e.test.ts`, `api/tests/integration/transcode-resilience.test.ts`
- **Category**: TEST_INFRASTRUCTURE
- **Symptom**: Suites fail when only `infra/docker-compose.yml` is up but the BullMQ transcode worker (`npm run worker:transcode:dev`) is not running. tus uploads succeed but transcode jobs sit in the queue.
- **Mitigation**: Documented in `CONTRIBUTING.md` "Required pre-merge local gate" — operator must run `make worker` before invoking these suites.
- **Production status**: Unaffected. PM2 ecosystem (`deploy/pm2/ecosystem.config.cjs`) keeps the worker running on the VPS.
- **Next action**: None for this cycle. Operator-driven local gate is the documented contract.

### Pre-existing fullscreen player infinite-loop bug (FIXED in this cycle)

- **File**: `app/lib/features/player/fullscreen_player_page.dart:165` (was `_exit() => Navigator.of(context).maybePop()`)
- **Status**: **RESOLVED in this cycle** (2026-04-26). Documented here as the trigger for one of the only test failures in the original baseline. Fix: swap `maybePop` → `pop`. The PopScope's `canPop: false` re-fired `onPopInvokedWithResult` → `_exit()` → infinite loop. Now `Navigator.of(context).pop()` is used; PopScope still intercepts the OS back button and routes through `_exit()` once.
- **Tests added**: `app/test/features/player/fullscreen_player_page_test.dart` — `_FakeController` defaults to portrait so the cheap path is exercised; new "landscape source path renders without infinite-loop" test exercises the OrientationBuilder branch with bounded `pump()`.

### sharp transitive optional binaries

- **File**: `api/package.json:57` (`sharp: ^0.34.5`)
- **Category**: DEPENDENCY_FOOTPRINT
- **Symptom**: sharp brings in platform-specific optional dependencies (`@img/sharp-linux-x64`, `@img/sharp-darwin-arm64`, etc., ~50 MB across the matrix). Only the matching one is installed at runtime via `optionalDependencies`. Acceptable trade-off vs. building libvips from source.
- **Mitigation**: None needed. Standard sharp install footprint.
- **Production status**: Unaffected on Linux x64 VPS (the only target).
- **Next action**: None.
