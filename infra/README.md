# lifestream-learn-infra

Reference infrastructure for running Lifestream Learn — suitable for self-hosters and as a blueprint for the production VPS. The hosted service at `learn.lifestreamdynamics.com` uses the Ansible playbooks here with production-specific overrides kept in the private `ops/` repo.

## Contents

| Path | Purpose |
|---|---|
| `docker-compose.yml` | One-command local stack: postgres, redis, seaweedfs, tusd, nginx |
| `nginx/` | Nginx config templates (TLS, secure_link for HLS, reverse proxies) |
| `ansible/` | Production deployment playbooks (VPS provisioning) |
| `scripts/` | Helper scripts: bootstrap TLS, create DB, provision buckets |

## Quick start (local)

```bash
cp .env.example .env
docker compose up -d
# wait ~30s for SeaweedFS to initialise buckets
./scripts/create-buckets.sh
```

Then point [`../api`](../api) at `S3_ENDPOINT=http://localhost:8333` and start it with `npm run dev`.

## Production (VPS)

```bash
cd ansible
cp inventories/example.yml inventories/yours.yml
# edit host, domain, secrets references
ansible-playbook -i inventories/yours.yml site.yml
```

The playbooks are idempotent; safe to re-run. Secrets are read from Ansible Vault or environment.

## Status

Placeholder. Docker Compose skeleton and Ansible role stubs come in **Phase 1** of the [implementation plan](../IMPLEMENTATION_PLAN.md).

## License

AGPL-3.0. See [`../LICENSE`](../LICENSE).
