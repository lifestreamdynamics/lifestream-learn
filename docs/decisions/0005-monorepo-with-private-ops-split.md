# 0005 — Single workspace with a private `ops/` directory that ships to its own repo

- **Status:** Accepted (2026-04-18)
- **Deciders:** Eric

## Context

Lifestream Learn has four strands that live on different release schedules but share architecture, data model, and a common history of decisions: the API, the Flutter app, the infra templates, and a private scratch area. We needed to pick a repository structure that:

1. Keeps related code discoverable during early development (lots of cross-cutting changes)
2. Does not leak secrets or environment-specific paths when the code goes public
3. Does not force each deliverable into the *same* public repo (they have different audiences and different contribution UX)
4. Is cheap to split later without rewriting history

## Decision

- During development: **one working directory** at `~/Projects/lifestream-learn/` with sub-projects in `api/`, `app/`, `infra/`, `ops/`, and shared `docs/`
- **`ops/` is git-ignored at the top level** and lives in a separate private repository (self-hosted or private GitHub)
- **Before public release:** each public sub-project (`api`, `app`, `infra`) gets split into its own standalone public repo via `git subtree split` or `git filter-repo`, preserving history
- **Shared `docs/` stays in the top-level `lifestream-learn` repo** (the "meta" repo) alongside `IMPLEMENTATION_PLAN.md`. Sub-projects cross-link with relative paths while co-located, and those links get fixed up at split time

## Consequences

- Cross-cutting changes (e.g. adding a cue type that touches schema, API, and Flutter) happen in one PR during development
- Public release requires one-time split work, but history is preserved
- `ops/` can never leak through the public monorepo because it never lived in it (separate repo, separate remote)
- Contributors cloning a single public repo (`lifestream-learn-api`) get a focused codebase without the cognitive load of a monorepo
- The meta `docs/` + `IMPLEMENTATION_PLAN.md` staying top-level means cross-project ADRs have an obvious home

## Alternatives considered

- **Four separate repos from day one** — rejected; premature separation slows down Phase 0-3 cross-cutting work
- **Monolithic public repo with all four sub-projects** — rejected; bundles `ops/` with public code or forces an always-on secret-scan dance; also harder for contributors to clone only what they need
- **`ops/` as a git submodule of the monorepo** — rejected; submodules add friction and leak the existence/path of the private repo

## References

- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §Distribution model
- [`../../README.md`](../../README.md) Repositories table
