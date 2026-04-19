# lifestream-learn-api

REST API for Lifestream Learn. Runs at `learn.REDACTED-BRAND-DOMAIN` for the hosted service; self-hosters deploy via [`../infra/`](../infra).

## Stack

- Node **22.12+ LTS**
- TypeScript (strict)
- Express 4
- Prisma 7 + PostgreSQL 15
- Redis 7
- BullMQ 5 (video transcoding queue)
- Zod (input validation)
- JWT (access + refresh) with roles: `ADMIN`, `COURSE_DESIGNER`, `LEARNER`

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
- **Prod:** 3101 (assigned in the Lifestream port registry)

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
