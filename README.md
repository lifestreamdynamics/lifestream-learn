# Lifestream Learn

Short-form educational video platform. Learners scroll a TikTok-style vertical feed of course videos that pause mid-play for interactive exercises — multiple choice, matching, fill-in-the-blank. Course Designers author courses, upload videos, and place interactive cues on a timeline.

**Hosted by Lifestream Dynamics at [learn.lifestreamdynamics.com](https://learn.lifestreamdynamics.com)** · **Source available under AGPL-3.0**

---

## Repositories

This is a multi-project workspace. Each subdirectory is published as its own public repository when we cut 1.0.

| Path | Purpose | License |
|---|---|---|
| [`api/`](./api) | Node 22 / Express / Prisma / Postgres REST API | AGPL-3.0 |
| [`app/`](./app) | Flutter Android app (iOS later) — learner + course-designer UI | AGPL-3.0 |
| [`infra/`](./infra) | Docker Compose + Ansible templates for self-hosters | AGPL-3.0 |
| [`ops/`](./ops) | **Private** — production secrets, VPS-specific deploy configs. Git-ignored at the top level; tracked in a separate private repo. |
| [`docs/`](./docs) | Architecture decisions, design notes, runbooks | — |

The canonical implementation plan lives at [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

---

## Business model

Open-source core, commercial SaaS. The code is public under AGPL-3.0. The content (videos, cues, course metadata) and user data are served only through the authenticated API run by Lifestream Dynamics. Anyone can self-host for their own content; paid subscriptions on the hosted service support development.

---

## Tech stack at a glance

- **Mobile:** Flutter, Android-first, forked from [`FlutterWiz/flutter_video_feed`](https://github.com/FlutterWiz/flutter_video_feed) (MIT) for the feed shell
- **Backend:** Node 22.12+ · TypeScript (strict) · Express 4 · Prisma 7 · PostgreSQL 15 · Redis 7 · BullMQ
- **Storage:** SeaweedFS (S3-compatible, Apache-2.0)
- **Upload:** tusd (resumable)
- **Streaming:** FFmpeg → HLS (CMAF fMP4) → Nginx with `secure_link` HMAC tokens
- **Deploy:** PM2 · Nginx · Certbot on a single VPS; designed for seamless migration to S3 + CDN later

---

## Status

Pre-alpha. Phase 0 (decisions + scaffolding) in progress. See [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) §5 for current phase and exit criteria.

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). By contributing you agree your changes are licensed under AGPL-3.0. For commercial licensing inquiries, contact `eric@digitalartifacts.ca`.
