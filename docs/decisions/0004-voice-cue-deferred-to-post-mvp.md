# 0004 — Defer voice-capture pronunciation cue to post-MVP

- **Status:** Accepted (2026-04-18)
- **Deciders:** Eric

## Context

Four interactive cue types were scoped for the MVP: multiple-choice, matching, fill-in-the-blank, and voice capture for pronunciation scoring. Voice capture is materially more complex than the other three:

- Requires microphone permission UX and edge-case handling (denied, revoked, bluetooth devices)
- Needs pronunciation **scoring**, not just transcription; no viable open-source option runs on-device in 2026 (sherpa-onnx / whisper.cpp do ASR only; Kaldi GOP is server-side and operationally heavy)
- Introduces a paid third-party runtime dependency (Azure Pronunciation Assessment, ~$0.02/60s attempt) for anything usable out-of-the-box
- Adds storage, retention, and GDPR considerations for user audio that the other cue types do not

Shipping all four in MVP would push the closed-beta timeline by ~3-4 days and introduce ongoing Azure cost before we know whether anyone will use voice cues at all.

## Decision

**MVP ships with MCQ, matching, and fill-in-the-blank only.** The `VOICE` enum value is reserved in the database schema (so migrations need not change when voice lands), but:

- The designer cue-authoring UI does not expose `VOICE` as an option
- The backend `POST /api/videos/:id/cues` endpoint returns `501 Not Implemented` for `type: "VOICE"`
- The Flutter cue engine treats an unexpected `VOICE` payload as `unimplemented` and skips gracefully

Voice capture is revisited post-MVP, once product-market fit signals whether it's worth the complexity.

## Consequences

- Closed-beta ships ~3.5–4.5 weeks out instead of ~4–5
- No Azure account needed at launch; no runtime cost per attempt
- Schema stays forward-compatible; no migration required to add voice later
- Language-learning use cases that depend on pronunciation feedback are under-served at MVP; acceptable given the other cue types still support vocabulary + grammar drills

## Alternatives considered

- **Ship all four types at MVP** — rejected on timeline and cost
- **Cut voice from schema entirely** — rejected; re-adding would require a migration and feels like we don't trust the roadmap

## References

- [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) §5 Phases (Phase 6 removed; Phase 7 renumbered)
