# lifestream-learn-api

REST API for Lifestream Learn. Backs the Android learner app and the course-designer authoring flow. Pairs with the local stack in [`../infra/`](../infra) (SeaweedFS + tusd + nginx; Postgres + Redis borrowed from accounting-api's compose).

Deployment is deliberately out of scope right now — focus is a fully functional, locally tested API first.

## Stack

- Node **22.12+ LTS**
- TypeScript (strict)
- Express 4
- Prisma 7 + PostgreSQL 15
- Redis 7
- BullMQ 5 (video transcoding queue)
- Zod (input validation)
- JWT (access + refresh) with roles: `ADMIN`, `COURSE_DESIGNER`, `LEARNER`
- **FFmpeg ≥ 6.0** (6.1+ tested) on PATH for the transcode worker. The worker
  logs the detected `ffprobe` version at startup and warns if below 6.x. Install
  via `apt install ffmpeg` on Debian/Ubuntu or the official static build.

## Layout

```
api/
├── prisma/           # schema.prisma, migrations, seed
├── src/
│   ├── index.ts           # entry
│   ├── config/            # env validation
│   ├── middleware/        # auth, rate-limit, error handler
│   ├── routes/            # route definitions (thin)
│   ├── services/          # business logic
│   ├── queues/            # BullMQ queue + worker definitions
│   ├── workers/           # standalone worker entrypoints (e.g. transcode)
│   ├── lib/               # object-store client, signed URLs, etc.
│   └── types/             # shared types
├── tests/
│   ├── unit/
│   └── integration/
├── .env.example
├── .nvmrc
├── package.json
├── tsconfig.json
├── jest.config.js
└── jest.integration.config.js
```

## Local development

```bash
nvm use              # pins Node 22
npm install
cp .env.example .env.local
# edit .env.local — see ENV section below
npm run prisma:migrate
npm run dev
```

## Commands

| Command | Purpose |
|---|---|
| `npm run dev` | Hot-reload API on :3011 |
| `npm run build` | Compile TS → `dist/` |
| `npm start` | Run compiled build |
| `npm test` | Unit tests |
| `npm run test:integration` | Integration tests (needs Postgres + Redis) |
| `npm run lint` / `npm run typecheck` | Static checks |
| `npm run prisma:migrate` | Apply migrations (dev) |
| `npm run prisma:studio` | Prisma Studio GUI |
| `npm run worker:transcode` | Standalone BullMQ transcode worker |

## Environment

See [`.env.example`](./.env.example) for the canonical list. Required at minimum: `DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_UPLOAD_BUCKET`, `S3_VOD_BUCKET`, `HLS_SIGNING_SECRET`.

## Ports

- **Dev:** 3011
- **Prod:** 3101 (reserved per [`IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) §3 to avoid colliding with accounting-api on `:3100` and galaxy-miner on `:3177` on the shared VPS).

## Production

Production environment templates and the deploy runbook live at:

- [`api/.env.production.example`](./.env.production.example) — canonical list of env vars for the VPS-hosted API. Copy to `ops/env/api.production.env` (git-ignored, `chmod 600`) and fill in every `REPLACE_ME` slot.
- [`infra/.env.production.example`](../infra/.env.production.example) — infra-side template covering the SeaweedFS + tusd compose overlay.
- [`infra/docker-compose.prod.yml`](../infra/docker-compose.prod.yml) — production compose overlay (loopback-bound ports, block-storage bind mount, system-nginx-only edge).
- `deploy/README.md` — full operational runbook (first-time VPS prep, TLS issuance, deploy / rollback / log locations). Delivered by the deploy-automation slice; see the top-level `Makefile`'s `deploy-prod`, `deploy-prod-dry-run`, and `deploy-status` targets for entrypoints.

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
