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
- **Reserved for eventual prod:** 3101 — bookkeeping only, so the value's settled when we do tackle deploy.

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
