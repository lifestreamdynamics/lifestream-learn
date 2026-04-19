# Docs

Project-wide documentation. Sub-project-specific docs live with the code (`api/README.md`, `app/README.md`, etc.).

## Layout

- [`decisions/`](./decisions) — Architectural Decision Records (ADRs). Numbered, immutable once merged. New decision? New file.
- [`architecture/`](./architecture) — Current-state diagrams and narrative (kept in sync with code; rewrite rather than append).
- [`runbooks/`](./runbooks) — Incident response procedures (created in Phase 7). Private copies live in `ops/runbooks/`.

## Conventions

**Decision records (ADRs)** use the format `NNNN-short-slug.md` with sections: Status, Context, Decision, Consequences, Alternatives considered. Don't edit past ADRs to reflect new decisions — write a new ADR that supersedes the old one.

**Architecture docs** describe what *is*, not what was. If the diagram drifts from reality, fix the diagram.

**Runbooks** answer one question: "something is broken — what do I do?" Keep them tactical; link to deeper context instead of inlining it.
