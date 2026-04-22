# Lifestream Learn — top-level dev task runner.
#
# Collapses the multi-step local-dev workflow (shared backing services,
# infra compose, DB + bucket provisioning, API + worker, Flutter app) into
# a handful of idempotent targets. Local-dev only — no CI, no deploy.
#
# Run `make` or `make help` for the list of targets.

SHELL := bash
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help

# Absolute paths — Make runs each recipe line in a fresh shell, so we can't
# rely on a persistent cwd. Targets that need a subdir must cd && run in a
# single shell invocation.
ROOT     := $(CURDIR)
API_DIR  := $(ROOT)/api
APP_DIR  := $(ROOT)/app
INFRA    := $(ROOT)/infra
SCRIPTS  := $(ROOT)/scripts

# Flutter binaries. Defaults resolve from PATH (`which flutter` / `which dart`).
# Override by exporting FLUTTER / DART or by setting them on the make command
# line, e.g. `FLUTTER=/opt/flutter/bin/flutter make app`. Operators whose
# flutter install lives outside PATH can set these once in a local shell
# profile or a local.mk include. Do NOT commit operator-specific paths here.
FLUTTER  ?= $(shell command -v flutter 2>/dev/null)
DART     ?= $(shell command -v dart 2>/dev/null)
AVD_NAME ?= Medium_Phone_API_36.1

# Nginx fronts the API for the Android emulator (10.0.2.2 -> host). The
# exact host port comes from infra/.env NGINX_HOST_PORT (default 80) — we
# honor whatever the operator set, since :80 often collides with other
# compose stacks (e.g. accounting-nginx) and gets shifted to 8090.
# `$(shell …)` runs at Make parse time.
NGINX_HOST_PORT := $(shell \
	if [ -f "$(INFRA)/.env" ]; then \
		port=$$(grep -E '^NGINX_HOST_PORT=' "$(INFRA)/.env" | tail -1 | cut -d= -f2); \
		echo "$${port:-80}"; \
	else \
		echo "80"; \
	fi)
API_BASE_URL_EMULATOR := http://10.0.2.2:$(NGINX_HOST_PORT)

.PHONY: help bootstrap up down reset api worker app app-deps app-prod seed migrate logs status \
	deploy-prod deploy-prod-dry-run deploy-status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Run first-time developer setup (scripts/bootstrap-dev.sh)
	@"$(SCRIPTS)/bootstrap-dev.sh"

up: ## Bring up infra, provision DBs + buckets, run prisma migrate + seed (idempotent)
	@echo "[up] checking shared accounting-postgres (:5432) and accounting-redis (:6379)..."
	@if ! (nc -z localhost 5432 && nc -z localhost 6379) >/dev/null 2>&1; then \
		echo "ERROR: accounting-postgres / accounting-redis not reachable — start the accounting-api compose stack first." >&2; \
		exit 1; \
	fi
	@echo "[up] ensuring infra/.env exists..."
	@cd "$(INFRA)" && cp -n .env.example .env 2>/dev/null || true
	@echo "[up] docker compose up -d..."
	@cd "$(INFRA)" && docker compose up -d
	@echo "[up] waiting for seaweedfs healthcheck..."
	@cd "$(INFRA)" && for i in $$(seq 1 30); do \
		status=$$(docker compose ps --format json seaweedfs 2>/dev/null | jq -r 'if type=="array" then .[0].Health else .Health end' 2>/dev/null || echo ""); \
		if [ "$$status" = "healthy" ]; then echo "[up] seaweedfs healthy"; break; fi; \
		if [ $$i -eq 30 ]; then echo "ERROR: seaweedfs did not become healthy within 60s" >&2; exit 1; fi; \
		sleep 2; \
	done
	@echo "[up] provisioning learn_api_* databases..."
	@cd "$(INFRA)" && set -a && source .env && set +a && ./scripts/create-databases.sh
	@echo "[up] provisioning seaweedfs buckets..."
	@cd "$(INFRA)" && set -a && source .env && set +a && \
		if command -v aws >/dev/null 2>&1; then \
			./scripts/create-buckets.sh; \
		else \
			echo "[up] aws CLI not found on PATH — falling back to docker wrapper"; \
			printf '#!/bin/bash\nexec docker run --rm --network host -e AWS_ACCESS_KEY_ID=learn_access_key -e AWS_SECRET_ACCESS_KEY=learn_secret_key amazon/aws-cli "$$@"\n' > /tmp/aws-wrapper && \
			chmod +x /tmp/aws-wrapper && \
			S3_ENDPOINT=http://localhost:$${SEAWEEDFS_S3_HOST_PORT:-8333} AWS_CLI=/tmp/aws-wrapper ./scripts/create-buckets.sh; \
		fi
	@echo "[up] running prisma migrations..."
	@cd "$(API_DIR)" && npm run prisma:migrate
	@echo "[up] seeding database..."
	@cd "$(API_DIR)" && npm run prisma:seed
	@echo "[up] done — ready."

down: ## Stop infra compose stack (keeps volumes)
	@cd "$(INFRA)" && docker compose down

reset: ## DESTRUCTIVE: drop infra volumes then re-up (prompts for confirmation)
	@echo "WARNING: this will drop all SeaweedFS volumes (uploaded sources + transcoded HLS)."
	@echo "         learn_api_* databases on the shared accounting-postgres are NOT dropped"
	@echo "         — create-databases.sh is idempotent; run manual DROPs if you want a DB reset."
	@read -r -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || { echo "aborted."; exit 1; }
	@cd "$(INFRA)" && docker compose down -v
	@$(MAKE) up

api: ## Run the API in dev mode (hot reload on :3011)
	@cd "$(API_DIR)" && npm run dev

worker: ## Run the transcode worker in dev mode
	@cd "$(API_DIR)" && npm run worker:transcode:dev

app: ## Launch Android emulator (if needed), then flutter run (dev flavor)
	@echo "[app] checking for running emulator..."
	@if adb devices 2>/dev/null | grep -qE '^emulator-[0-9]+[[:space:]]+device$$'; then \
		echo "[app] emulator already running — skipping launch"; \
	else \
		echo "[app] launching AVD '$(AVD_NAME)' in background..."; \
		$(FLUTTER) emulators --launch $(AVD_NAME) >/dev/null 2>&1 & \
		echo "[app] waiting for device..."; \
		adb wait-for-device; \
		echo "[app] waiting for boot to complete..."; \
		adb shell 'while [[ -z $$(getprop sys.boot_completed) ]]; do sleep 1; done'; \
		echo "[app] emulator ready"; \
	fi
	@cd "$(APP_DIR)" && $(FLUTTER) run --flavor dev --dart-define=API_BASE_URL=$(API_BASE_URL_EMULATOR)

app-deps: ## Install Flutter deps + run build_runner codegen
	@cd "$(APP_DIR)" && $(FLUTTER) pub get && $(DART) run build_runner build --delete-conflicting-outputs

seed: ## Re-run prisma seed (idempotent)
	@cd "$(API_DIR)" && npm run prisma:seed

migrate: ## Run prisma migrate dev
	@cd "$(API_DIR)" && npm run prisma:migrate

logs: ## Tail infra compose logs
	@cd "$(INFRA)" && docker compose logs -f

status: ## One-line status report for local services
	@probe() { code=$$(curl -s -m 2 -o /dev/null -w '%{http_code}' "$$1" 2>/dev/null); \
		if [ -z "$$code" ] || [ "$$code" = "000" ]; then echo "unreachable"; else echo "HTTP $$code"; fi; }; \
	echo "API    (:3011/health)        : $$(probe http://localhost:3011/health)"; \
	echo "nginx  (:$(NGINX_HOST_PORT)/health)        : $$(probe http://localhost:$(NGINX_HOST_PORT)/health)"; \
	echo "nginx  (:$(NGINX_HOST_PORT)/api/health)    : $$(probe http://localhost:$(NGINX_HOST_PORT)/api/health)"; \
	devices=$$(adb devices 2>/dev/null | awk 'NR>1 && $$2=="device"{print $$1}' | paste -sd',' - || true); \
	echo "AVD (adb devices)            : $${devices:-none}"; \
	echo "Flutter API_BASE_URL         : $(API_BASE_URL_EMULATOR)"

# ---------------------------------------------------------------------------
# Production deploy targets
#
# These are thin wrappers around deploy/deploy-production.sh. The real
# deploy logic — SSH ControlMaster, atomic release swap, nginx reload,
# health check — lives in that script. These targets exist so operators
# get the same muscle-memory entrypoint (`make`) for local and remote
# work, and so the prod-flavor Flutter build recipe lives next to the
# dev-flavor one.
#
# The deploy script itself is delivered by a parallel slice (see
# the Phasing section of the production-deploy plan). Running these
# targets before that script lands will print a friendly error.
# ---------------------------------------------------------------------------

# Extra args forwarded to deploy/deploy-production.sh (e.g. --skip-tests,
# --skip-ssl, --sync-env, --rollback). Example:
#   make deploy-prod DEPLOY_ARGS="--skip-tests --sync-env"
DEPLOY_ARGS ?=
DEPLOY_SCRIPT := $(ROOT)/deploy/deploy-production.sh

app-prod: ## Build the production-flavor Flutter APK (release, prod API URL)
	@cd "$(APP_DIR)" && $(FLUTTER) build apk --flavor prod --release \
		--dart-define=API_BASE_URL=https://learn-api.REDACTED-BRAND-DOMAIN

deploy-prod: ## Run the production deploy script (SSH, atomic release swap, nginx reload)
	@if [ ! -x "$(DEPLOY_SCRIPT)" ]; then \
		echo "ERROR: $(DEPLOY_SCRIPT) not found or not executable." >&2; \
		echo "       The deploy script is delivered by the deploy-automation slice." >&2; \
		exit 1; \
	fi
	@"$(DEPLOY_SCRIPT)" $(DEPLOY_ARGS)

deploy-prod-dry-run: ## Print the deploy plan without making remote changes
	@if [ ! -x "$(DEPLOY_SCRIPT)" ]; then \
		echo "ERROR: $(DEPLOY_SCRIPT) not found or not executable." >&2; \
		echo "       The deploy script is delivered by the deploy-automation slice." >&2; \
		exit 1; \
	fi
	@"$(DEPLOY_SCRIPT)" --dry-run $(DEPLOY_ARGS)

deploy-status: ## SSH to the VPS and show pm2 status for learn-api + transcode worker
	@if [ ! -x "$(DEPLOY_SCRIPT)" ]; then \
		echo "ERROR: $(DEPLOY_SCRIPT) not found or not executable." >&2; \
		echo "       The deploy script is delivered by the deploy-automation slice." >&2; \
		exit 1; \
	fi
	@"$(DEPLOY_SCRIPT)" --status
