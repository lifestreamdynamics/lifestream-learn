# Contributing to Lifestream Learn

Thanks for your interest. This project is open source under AGPL-3.0 while being operated commercially as a SaaS. Contributions are welcome under those terms.

## Before you start

- **License:** by opening a PR you agree your contribution is licensed under AGPL-3.0. If you need a different license for your use case, email `eric@REDACTED-DOMAIN` before contributing.
- **Issues first:** for non-trivial changes, open an issue to discuss the approach before writing code. Drive-by refactors will usually be closed.
- **Scope:** this project deliberately keeps a narrow feature surface. New interaction cue types, new auth flows, and major architectural changes should be discussed before implementation.

## Development setup

Each sub-project has its own setup instructions:

- [`api/README.md`](./api/README.md) — backend
- [`app/README.md`](./app/README.md) — Flutter app
- [`infra/README.md`](./infra/README.md) — self-hosting stack

## Pull request expectations

- One logical change per PR
- Tests for any business logic (unit ≥80%, integration ≥85% on the backend)
- Passes the linter and type checker
- No secrets, no hostnames, no personal paths committed — see `.gitignore` and the `gitleaks` pre-push hook
- Sign your commits (`git commit -S`) — required on the protected `main` branch

## Areas where help is welcome

- Additional cue type proposals (e.g. code playground, video response)
- iOS builds of the Flutter app
- Translations of the learner-facing UI
- Accessibility testing (TalkBack on Android)
- Self-hosting documentation improvements in `infra/`

## Code of conduct

See [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
