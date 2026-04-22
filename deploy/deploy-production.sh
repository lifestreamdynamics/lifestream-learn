#!/usr/bin/env bash

################################################################################
# Production Deployment Script for Lifestream Learn (API + landing)
#
# Zero-downtime deployment via a release directory + symlink flip ("current"
# → releases/<sha>-<ts>). Builds locally, rsyncs to the VPS while the live
# app keeps serving traffic, runs Prisma migrations against the production
# database, then swaps the symlink and reloads PM2.
#
# Modelled on ~/Projects/lifestream-dynamics-vault/scripts/deploy-production.sh
# (the user's explicit template): SSH ControlMaster, shellcheck-clean,
# idempotent nginx, Let's Encrypt webroot, hash-based change detection,
# atomic swap cutover, fast reverse-swap rollback.
#
# Differences from the vault template:
#   - rsync + symlink "current" instead of staging / rollback directory pair
#     (fits multi-release retention; matches the plan's §1 bullet).
#   - Two PM2 apps (learn-api + learn-transcode-worker) via one
#     deploy/pm2/ecosystem.config.cjs.
#   - Two nginx vhosts (learn-api.* + learn.*), each with its own cert.
#   - Static landing-page rsync to /var/www/learn-landing.
#   - Env file lives at /etc/learn-api/.env (outside the release tree), only
#     synced on first deploy or with --sync-env.
#   - No destructive DB work: the plan gates on migrations being additive;
#     --skip-db is NOT an option (we always run `prisma migrate deploy`).
#     `pg_dump` runs before migrations as a safety net.
#
# Usage: ./deploy/deploy-production.sh [options]
#   --rollback [<release-id>]  Flip `current` back to the previous (or named) release
#   --sync-env                 Rsync ops/env/api.production.env → /etc/learn-api/.env
#   --skip-nginx               Skip Nginx configuration deployment
#   --skip-ssl                 Skip SSL certificate setup (Let's Encrypt)
#   --skip-tests               Skip pre-deployment test suite
#   --skip-landing             Skip landing-page rsync
#   --force                    Continue even if local tests fail
#   --dry-run                  Show what would happen without making changes
#   --help                     Show this help and exit 0
#
# Environment overrides (all optional; defaults are publication-safe):
#   REMOTE_HOST                VPS hostname              [mittonvillage.com]
#   REMOTE_USER                SSH user                  [root]
#   SSH_KEY                    SSH private key           [~/.ssh/id_ed25519]
#   REMOTE_APP_DIR             Release-tree root         [/var/www/learn-api]
#   REMOTE_LANDING_DIR         Static landing root       [/var/www/learn-landing]
#   REMOTE_ENV_FILE            Runtime env file          [/etc/learn-api/.env]
#   API_DOMAIN                 Public API hostname       [learn-api.lifestreamdynamics.com]
#   LANDING_DOMAIN             Public landing hostname   [learn.lifestreamdynamics.com]
#   PM2_API_NAME               PM2 app name (API)        [learn-api]
#   PM2_WORKER_NAME            PM2 app name (worker)     [learn-transcode-worker]
#   LE_EMAIL                   Let's Encrypt account     [admin@lifestreamdynamics.com]
#   KEEP_RELEASES              Release retention count   [5]
################################################################################

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ── Resolve real user (handles sudo) ────────────────────────────────
if [ -n "${SUDO_USER:-}" ]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    REAL_HOME="${HOME:-/root}"
fi

# ── Remote server configuration (env-overridable; defaults are publication-safe) ──
# mittonvillage.com is brand-public (already referenced in user's vault
# deploy script and in README.md); specific subdomain hostnames are
# documented in docs/decisions/0001-open-source-license-agpl-3.md.
REMOTE_HOST="${REMOTE_HOST:-mittonvillage.com}"
REMOTE_USER="${REMOTE_USER:-root}"
SSH_KEY="${SSH_KEY:-$REAL_HOME/.ssh/id_ed25519}"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/var/www/learn-api}"
REMOTE_LANDING_DIR="${REMOTE_LANDING_DIR:-/var/www/learn-landing}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-/etc/learn-api/.env}"
API_DOMAIN="${API_DOMAIN:-learn-api.lifestreamdynamics.com}"
LANDING_DOMAIN="${LANDING_DOMAIN:-learn.lifestreamdynamics.com}"
PM2_API_NAME="${PM2_API_NAME:-learn-api}"
PM2_WORKER_NAME="${PM2_WORKER_NAME:-learn-transcode-worker}"
LE_EMAIL="${LE_EMAIL:-admin@lifestreamdynamics.com}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"

# ── Script configuration ────────────────────────────────────────────
ROLLBACK_MODE=false
ROLLBACK_TARGET=""
SYNC_ENV=false
SKIP_NGINX=false
SKIP_SSL=false
SKIP_TESTS=false
SKIP_LANDING=false
FORCE_DEPLOY=false
DRY_RUN=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
LOCK_FILE="/tmp/learn-deploy.lock"

STAGE_ROOT="$SCRIPT_DIR/.deploy-stage"
DEPLOY_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
GIT_SHA=""
RELEASE_ID=""
STAGE_DIR=""

SSH_CONTROL_PATH="/tmp/learn-ssh-ctl-$$"
SSH_BASE_OPTS=(
    -o StrictHostKeyChecking=yes
    -o ConnectTimeout=30
    -o ServerAliveInterval=10
    -o BatchMode=yes
)
SSH_MUX_OPTS=(
    -o "ControlMaster=auto"
    -o "ControlPath=$SSH_CONTROL_PATH"
    -o "ControlPersist=300"
)
SSH_CONTROLMASTER_OPEN=false
CUTOVER_STARTED=false
PREV_RELEASE=""

# ── Logging ─────────────────────────────────────────────────────────

log() {
    # shellcheck disable=SC2059
    # $1 may contain printf escape sequences (\n, color codes); that's
    # intentional — we're using printf-style format strings, not printing
    # untrusted data.
    printf -- "$1\n" | tee -a "$LOG_FILE"
}

log_step()    { log "\n${BLUE}==>${BOLD} $1${NC}"; }
log_success() { log "${GREEN}[ok]${NC} $1"; }
log_warning() { log "${YELLOW}[warn]${NC} $1"; }
log_error()   { log "${RED}[err]${NC} $1"; }
log_info()    { log "${CYAN}[info]${NC} $1"; }
log_dry_run() { log "${YELLOW}[dry-run]${NC} $1"; }

# ── Help ────────────────────────────────────────────────────────────

show_help() {
    cat <<EOF
Usage: $0 [options]

Deploys Lifestream Learn (API + transcode worker + landing) to production.
Builds locally, rsyncs to the VPS, runs Prisma migrations, flips the
"current" symlink, and reloads PM2. <30s downtime on the app swap.

Options:
  --rollback [<release-id>]  Flip \`current\` back to the previous (or
                             named) release under \$REMOTE_APP_DIR/releases.
  --sync-env                 Rsync ops/env/api.production.env to
                             \$REMOTE_ENV_FILE (first-deploy / rotate path).
                             Default behaviour is to leave the remote env alone.
  --skip-nginx               Skip nginx site install + reload
  --skip-ssl                 Skip Let's Encrypt cert provisioning
  --skip-tests               Skip local npm run validate before build
  --skip-landing             Skip landing-page rsync
  --force                    Continue even if local tests fail
  --dry-run                  Print the action plan; make no remote changes.
                             Does NOT require ops/env/api.production.env.
  --help                     Show this help and exit 0

Configuration (env-overridable; defaults shown):
  REMOTE_HOST         = $REMOTE_HOST
  REMOTE_USER         = $REMOTE_USER
  REMOTE_APP_DIR      = $REMOTE_APP_DIR
  REMOTE_LANDING_DIR  = $REMOTE_LANDING_DIR
  REMOTE_ENV_FILE     = $REMOTE_ENV_FILE
  API_DOMAIN          = $API_DOMAIN
  LANDING_DOMAIN      = $LANDING_DOMAIN
  PM2_API_NAME        = $PM2_API_NAME
  PM2_WORKER_NAME     = $PM2_WORKER_NAME
  LE_EMAIL            = $LE_EMAIL
  KEEP_RELEASES       = $KEEP_RELEASES
  SSH_KEY             = $SSH_KEY

Examples:
  $0 --dry-run                               # preview (no remote changes)
  $0                                         # full deploy
  $0 --sync-env                              # first deploy (copies env file)
  $0 --skip-ssl --skip-nginx                 # code-only rollout
  $0 --rollback                              # flip to previous release
  $0 --rollback 20260421-094500-ab12cd34     # flip to a named release

See deploy/README.md for the full runbook (first-time VPS prep, cert
issuance, log locations, rollback recipes).
EOF
}

# ── Argument parsing ────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rollback)
                ROLLBACK_MODE=true
                shift
                # Optional positional release id
                if [[ $# -gt 0 && $1 != --* ]]; then
                    ROLLBACK_TARGET="$1"
                    shift
                fi
                ;;
            --sync-env)
                SYNC_ENV=true
                shift
                ;;
            --skip-nginx)
                SKIP_NGINX=true
                shift
                ;;
            --skip-ssl)
                SKIP_SSL=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-landing)
                SKIP_LANDING=true
                shift
                ;;
            --force)
                FORCE_DEPLOY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                echo "Run '$0 --help' for usage." >&2
                exit 1
                ;;
        esac
    done
}

# ── Lock ────────────────────────────────────────────────────────────

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            log_error "Another deployment is in progress (PID: $lock_pid)"
            log_info "If this is stale, remove: $LOCK_FILE"
            exit 1
        else
            log_warning "Removing stale lock file from PID ${lock_pid:-unknown}"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    log_success "Deployment lock acquired"
}

release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

# ── SSH ControlMaster ───────────────────────────────────────────────

init_ssh_controlmaster() {
    log_step "Opening SSH ControlMaster connection"

    if $DRY_RUN; then
        log_dry_run "Would open persistent SSH connection to $REMOTE_USER@$REMOTE_HOST"
        return
    fi

    ssh -i "$SSH_KEY" "${SSH_BASE_OPTS[@]}" "${SSH_MUX_OPTS[@]}" \
        -MNf "$REMOTE_USER@$REMOTE_HOST"

    SSH_CONTROLMASTER_OPEN=true
    log_success "SSH ControlMaster established (all SSH calls multiplex over this)"
}

close_ssh_controlmaster() {
    if [ "$SSH_CONTROLMASTER_OPEN" = true ] && [ -S "$SSH_CONTROL_PATH" ]; then
        ssh -i "$SSH_KEY" "${SSH_BASE_OPTS[@]}" \
            -o "ControlPath=$SSH_CONTROL_PATH" \
            -O exit "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null || true
        SSH_CONTROLMASTER_OPEN=false
    fi
}

ssh_exec() {
    ssh -i "$SSH_KEY" "${SSH_BASE_OPTS[@]}" "${SSH_MUX_OPTS[@]}" \
        "$REMOTE_USER@$REMOTE_HOST" "$@"
}

rsync_to() {
    rsync -az --delete \
        -e "ssh -i $SSH_KEY ${SSH_BASE_OPTS[*]} -o ControlPath=$SSH_CONTROL_PATH" \
        "$@"
}

# ── Cleanup / emergency rollback ────────────────────────────────────

cleanup() {
    local exit_code=$?

    # Emergency reverse-symlink if cutover started but script died
    if [ "$CUTOVER_STARTED" = true ] && [ $exit_code -ne 0 ] && [ -n "$PREV_RELEASE" ]; then
        log_error "Script failed during cutover — attempting emergency rollback"
        if ssh_exec "test -d $REMOTE_APP_DIR/releases/$PREV_RELEASE" 2>/dev/null; then
            ssh_exec "ln -sfn $REMOTE_APP_DIR/releases/$PREV_RELEASE $REMOTE_APP_DIR/current && \
                      pm2 reload $PM2_API_NAME --update-env 2>/dev/null || true && \
                      pm2 reload $PM2_WORKER_NAME --update-env 2>/dev/null || true" \
                      2>/dev/null || true
            log_warning "Emergency rollback attempted — verify: ssh $REMOTE_USER@$REMOTE_HOST 'pm2 status'"
        fi
    fi

    close_ssh_controlmaster
    release_lock
}

# ── Local prerequisites ─────────────────────────────────────────────

check_local_prerequisites() {
    log_step "Checking local prerequisites"

    local has_errors=false

    # node
    if ! command -v node &>/dev/null; then
        log_error "node is not installed"
        has_errors=true
    else
        local node_version node_major
        node_version=$(node --version)
        node_major=$(echo "$node_version" | sed 's/^v//' | cut -d. -f1)
        if [ "$node_major" -lt 22 ]; then
            log_error "Node >= 22 required (found $node_version)"
            has_errors=true
        else
            log_success "node $node_version"
        fi
    fi

    # npm
    if ! command -v npm &>/dev/null; then
        log_error "npm is not installed"
        has_errors=true
    else
        log_success "npm installed"
    fi

    # rsync
    if ! command -v rsync &>/dev/null; then
        log_error "rsync is not installed (install via: apt install rsync)"
        has_errors=true
    else
        log_success "rsync installed"
    fi

    # ssh
    if ! command -v ssh &>/dev/null; then
        log_error "ssh is not installed"
        has_errors=true
    fi

    # SSH key
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH key not found: $SSH_KEY"
        has_errors=true
    else
        log_success "SSH key present"
    fi

    # api/ must exist
    if [ ! -d "$PROJECT_ROOT/api" ]; then
        log_error "Missing $PROJECT_ROOT/api — are you running from the repo root?"
        has_errors=true
    fi

    # ecosystem file
    if [ ! -f "$SCRIPT_DIR/pm2/ecosystem.config.cjs" ]; then
        log_error "Missing $SCRIPT_DIR/pm2/ecosystem.config.cjs"
        has_errors=true
    fi

    # nginx site files
    if [ ! -f "$SCRIPT_DIR/nginx/learn-api.lifestreamdynamics.com.conf" ]; then
        log_error "Missing nginx site file: deploy/nginx/learn-api.lifestreamdynamics.com.conf"
        has_errors=true
    fi
    if [ ! -f "$SCRIPT_DIR/nginx/learn.lifestreamdynamics.com.conf" ]; then
        log_error "Missing nginx site file: deploy/nginx/learn.lifestreamdynamics.com.conf"
        has_errors=true
    fi
    if [ ! -f "$SCRIPT_DIR/nginx/snippets/secure_link.conf.inc" ]; then
        log_error "Missing nginx snippet: deploy/nginx/snippets/secure_link.conf.inc"
        has_errors=true
    fi

    # Env file check ONLY fires when --sync-env is set. --dry-run deliberately
    # does NOT require ops/env/api.production.env — it's a shape preview, not
    # a first-deploy dress rehearsal.
    if [ "$SYNC_ENV" = true ]; then
        if [ ! -f "$PROJECT_ROOT/ops/env/api.production.env" ]; then
            log_error "ops/env/api.production.env not found (required when --sync-env is passed)"
            log_info "Create it from api/.env.production.example and chmod 600."
            has_errors=true
        else
            log_success "ops/env/api.production.env present"
        fi
    fi

    if [ "$has_errors" = true ]; then
        log_error "Local prerequisite check failed"
        exit 1
    fi
}

resolve_git_sha() {
    if git -C "$PROJECT_ROOT" rev-parse --short=8 HEAD &>/dev/null; then
        GIT_SHA=$(git -C "$PROJECT_ROOT" rev-parse --short=8 HEAD)
    else
        GIT_SHA="nogit"
    fi
    RELEASE_ID="${DEPLOY_TIMESTAMP}-${GIT_SHA}"
    STAGE_DIR="$STAGE_ROOT/$RELEASE_ID"
    log_info "Release id: $RELEASE_ID"
}

# ── SSH connectivity ────────────────────────────────────────────────

check_ssh_connectivity() {
    log_step "Checking SSH connectivity"

    if $DRY_RUN; then
        log_dry_run "Would verify SSH to $REMOTE_USER@$REMOTE_HOST"
        return
    fi

    if ssh_exec "echo ok" &>/dev/null; then
        log_success "SSH to $REMOTE_HOST verified"
    else
        log_error "Cannot reach $REMOTE_USER@$REMOTE_HOST via SSH"
        exit 1
    fi
}

# ── Remote prerequisite probe (single call) ─────────────────────────

check_remote_prerequisites() {
    log_step "Checking remote prerequisites"

    if $DRY_RUN; then
        log_dry_run "Would check remote: node, npm, pm2, nginx, certbot, psql, ffmpeg, redis, aws"
        return
    fi

    local result
    result=$(ssh_exec 'bash -s' <<'PREREQ_CHECK'
errors=""
warnings=""
info=""

if command -v node &>/dev/null; then
    node_major=$(node --version | sed 's/^v//' | cut -d. -f1)
    if [ "$node_major" -lt 22 ]; then
        errors="${errors}Node >= 22 required, found $(node --version)\n"
    else
        info="${info}node:$(node --version)\n"
    fi
else
    errors="${errors}node not installed\n"
fi

command -v npm      &>/dev/null && info="${info}npm:ok\n"      || errors="${errors}npm not installed\n"
command -v pm2      &>/dev/null && info="${info}pm2:ok\n"      || warnings="${warnings}pm2:missing\n"
command -v nginx    &>/dev/null && info="${info}nginx:ok\n"    || errors="${errors}nginx not installed\n"
command -v certbot  &>/dev/null && info="${info}certbot:ok\n"  || warnings="${warnings}certbot:missing\n"
command -v psql     &>/dev/null && info="${info}psql:ok\n"     || warnings="${warnings}psql:missing\n"
command -v pg_dump  &>/dev/null && info="${info}pg_dump:ok\n"  || warnings="${warnings}pg_dump:missing\n"
command -v ffmpeg   &>/dev/null && info="${info}ffmpeg:ok\n"   || warnings="${warnings}ffmpeg:missing (transcode worker will fail)\n"
command -v aws      &>/dev/null && info="${info}aws:ok\n"      || warnings="${warnings}aws:missing\n"

# NOAUTH means Redis is running but requirepass is set — that's healthy.
redis_out=$(redis-cli ping 2>/dev/null || true)
if echo "$redis_out" | grep -q PONG; then
    info="${info}redis:ok\n"
elif echo "$redis_out" | grep -q NOAUTH; then
    info="${info}redis:ok (auth required)\n"
else
    warnings="${warnings}redis:not responding\n"
fi

printf "ERRORS:%b\nWARNINGS:%b\nINFO:%b\n" "$errors" "$warnings" "$info"
PREREQ_CHECK
    )

    local errors warnings info
    errors=$(echo "$result"   | sed -n 's/^ERRORS://p')
    warnings=$(echo "$result" | sed -n 's/^WARNINGS://p')
    info=$(echo "$result"     | sed -n 's/^INFO://p')

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_success "Remote $line"
    done <<< "$info"

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_warning "Remote $line"
    done <<< "$warnings"

    local has_real_errors=false
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        log_error "Remote $line"
        has_real_errors=true
    done <<< "$errors"

    if [ "$has_real_errors" = true ]; then
        log_error "Remote prerequisite check failed"
        exit 1
    fi

    # pm2 install is cheap and safe to auto-provision
    if echo "$warnings" | grep -q '^pm2:'; then
        log_warning "Installing pm2 on remote..."
        ssh_exec "npm install -g pm2"
        log_success "pm2 installed"
    fi

    if echo "$warnings" | grep -q '^ffmpeg:' && [ "$FORCE_DEPLOY" = false ]; then
        log_error "FFmpeg missing on remote — transcode worker will crash on first job."
        log_info "Install: apt install -y ffmpeg  (or run with --force to deploy anyway)"
        exit 1
    fi

    if echo "$warnings" | grep -q '^certbot:' && [ "$SKIP_SSL" = false ]; then
        log_warning "certbot missing — forcing --skip-ssl"
        SKIP_SSL=true
    fi

    # aws CLI v2 is needed by create-buckets.sh. Install the official binary
    # bundle (works on any Linux amd64; no apt package required).
    if echo "$warnings" | grep -q '^aws:'; then
        log_warning "aws CLI missing — installing AWS CLI v2 binary..."
        if ssh_exec 'bash -s' <<'AWS_INSTALL'
set -euo pipefail
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscli.zip
unzip -q awscli.zip
./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin --update
rm -rf aws awscli.zip
aws --version
AWS_INSTALL
        then
            log_success "AWS CLI v2 installed"
        else
            log_error "Failed to install AWS CLI v2 — bucket creation will fail"
            exit 1
        fi
    fi
}

# ── Pre-deployment validation (local) ───────────────────────────────

run_pre_deployment_validation() {
    log_step "Running pre-deployment validation"

    if [ "$SKIP_TESTS" = true ]; then
        log_info "Skipping tests (--skip-tests)"
        return
    fi

    if $DRY_RUN; then
        log_dry_run "Would run: cd api && npm run validate"
        return
    fi

    log_info "Running api/ validate suite (lint + typecheck + unit)..."
    if (cd "$PROJECT_ROOT/api" && npm run validate 2>&1 | tee -a "$LOG_FILE"); then
        log_success "Local validate suite passed"
    else
        log_error "Local validate suite failed"
        if [ "$FORCE_DEPLOY" = false ]; then
            exit 1
        fi
        log_warning "Continuing despite failure (--force)"
    fi
}

# ── Local build + stage ─────────────────────────────────────────────

build_and_stage() {
    log_step "Building api/ locally"

    if $DRY_RUN; then
        log_dry_run "Would run: npm ci && npm run build && npm run prisma:generate && prepare prod node_modules"
        log_dry_run "Would stage to: $STAGE_DIR/api/{dist,node_modules,prisma,package.json,package-lock.json}"
        return
    fi

    mkdir -p "$STAGE_DIR/api"

    log_info "Installing dev dependencies for build..."
    (cd "$PROJECT_ROOT/api" && npm ci 2>&1 | tee -a "$LOG_FILE") || {
        log_error "npm ci failed"
        exit 1
    }

    log_info "Generating Prisma client..."
    (cd "$PROJECT_ROOT/api" && npm run prisma:generate 2>&1 | tee -a "$LOG_FILE") || {
        log_error "prisma generate failed"
        exit 1
    }

    log_info "Compiling TypeScript..."
    (cd "$PROJECT_ROOT/api" && npm run build 2>&1 | tee -a "$LOG_FILE") || {
        log_error "build failed"
        exit 1
    }

    if [ ! -f "$PROJECT_ROOT/api/dist/index.js" ]; then
        log_error "Expected build artifact missing: api/dist/index.js"
        exit 1
    fi
    log_success "api/dist ready"

    # Copy build artifacts into the stage dir
    log_info "Assembling release at $STAGE_DIR ..."
    rsync -a --delete \
        "$PROJECT_ROOT/api/dist/" "$STAGE_DIR/api/dist/"
    rsync -a --delete \
        "$PROJECT_ROOT/api/prisma/" "$STAGE_DIR/api/prisma/"
    cp "$PROJECT_ROOT/api/package.json"        "$STAGE_DIR/api/package.json"
    cp "$PROJECT_ROOT/api/package-lock.json"   "$STAGE_DIR/api/package-lock.json"
    # prisma.config.ts must ship alongside the release so `prisma migrate deploy`
    # can resolve the schema + migrations paths and the datasource URL.
    cp "$PROJECT_ROOT/api/prisma.config.ts"    "$STAGE_DIR/api/prisma.config.ts"
    # PM2 ecosystem config — the cutover step expects it at
    # <release>/deploy/pm2/ecosystem.config.cjs (matching the repo layout).
    mkdir -p "$STAGE_DIR/deploy/pm2"
    cp "$SCRIPT_DIR/pm2/ecosystem.config.cjs"  "$STAGE_DIR/deploy/pm2/ecosystem.config.cjs"

    # Infra scripts — shipped alongside the release so provision_infra() can
    # call them on the remote during provisioning.
    mkdir -p "$STAGE_DIR/infra/scripts"
    cp "$PROJECT_ROOT/infra/scripts/create-buckets.sh" \
        "$STAGE_DIR/infra/scripts/create-buckets.sh"

    # Production-only node_modules — install into the stage dir directly
    log_info "Installing production dependencies into stage..."
    (cd "$STAGE_DIR/api" && npm ci --omit=dev --ignore-scripts 2>&1 | tee -a "$LOG_FILE") || {
        log_error "prod npm ci failed"
        exit 1
    }
    # Prisma generate AGAIN inside the stage dir so @prisma/client has the
    # engine binaries matching the production lockfile. --omit=dev skipped
    # the postinstall above via --ignore-scripts.
    (cd "$STAGE_DIR/api" && npx prisma generate 2>&1 | tee -a "$LOG_FILE") || {
        log_error "stage prisma generate failed"
        exit 1
    }

    log_success "Stage ready: $STAGE_DIR"
}

# ── Rsync release to VPS ────────────────────────────────────────────

rsync_release_to_remote() {
    log_step "Syncing release to $REMOTE_HOST:$REMOTE_APP_DIR/releases/$RELEASE_ID"

    if $DRY_RUN; then
        log_dry_run "Would mkdir $REMOTE_APP_DIR/releases/$RELEASE_ID"
        log_dry_run "Would rsync $STAGE_DIR/ → $REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/releases/$RELEASE_ID/"
        return
    fi

    ssh_exec "mkdir -p $REMOTE_APP_DIR/releases/$RELEASE_ID $REMOTE_APP_DIR/shared/logs"

    rsync_to "$STAGE_DIR/" \
        "$REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/releases/$RELEASE_ID/"

    log_success "Release uploaded"
}

# ── Deploy env file (first deploy / --sync-env) ─────────────────────

sync_env_file() {
    if [ "$SYNC_ENV" = false ]; then
        log_info "Skipping env rsync (pass --sync-env on first deploy or to rotate secrets)"
        return
    fi

    log_step "Deploying env file to $REMOTE_ENV_FILE"

    local local_env="$PROJECT_ROOT/ops/env/api.production.env"
    if [ ! -f "$local_env" ]; then
        log_error "ops/env/api.production.env missing — required when --sync-env is set"
        exit 1
    fi

    if $DRY_RUN; then
        log_dry_run "Would rsync $local_env → $REMOTE_ENV_FILE (chmod 600, root-owned)"
        return
    fi

    ssh_exec "mkdir -p $(dirname "$REMOTE_ENV_FILE") && chmod 700 $(dirname "$REMOTE_ENV_FILE")"
    rsync_to "$local_env" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_ENV_FILE"
    ssh_exec "chmod 600 $REMOTE_ENV_FILE && chown root:root $REMOTE_ENV_FILE"
    log_success "Env file deployed (chmod 600, root-owned)"
}

# ── Postgres role + database provisioning ───────────────────────────

provision_database() {
    log_step "Provisioning Postgres role + database"

    if $DRY_RUN; then
        log_dry_run "Would create learn_api_user role + learn_api_production database if missing"
        return
    fi

    ssh_exec 'bash -s' -- "$REMOTE_ENV_FILE" <<'PROVISION_SCRIPT'
set -euo pipefail
env_file="$1"

if [ ! -f "$env_file" ]; then
    echo "Env file not found at $env_file — cannot provision database" >&2
    exit 1
fi

# Extract DATABASE_URL
db_url=$(grep -E '^DATABASE_URL=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
if [ -z "$db_url" ]; then
    echo "DATABASE_URL missing in $env_file" >&2; exit 1
fi

# Parse postgresql://user:pass@host:port/dbname?...
# Strip scheme
rest="${db_url#postgresql://}"
rest="${rest#postgres://}"
# user:pass@host:port/dbname
userpass="${rest%%@*}"
rest="${rest#*@}"
db_user="${userpass%%:*}"
db_pass="${userpass#*:}"
db_name="${rest#*/}"
db_name="${db_name%%\?*}"   # strip query string

# Escape single quotes in password for SQL literal
db_pass_escaped="${db_pass//\'/\'\'}"

echo "Provisioning: role=$db_user db=$db_name"

sudo -u postgres psql -v ON_ERROR_STOP=1 -X <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$db_user') THEN
    CREATE ROLE "$db_user" WITH LOGIN PASSWORD '$db_pass_escaped';
    RAISE NOTICE 'Created role %', '$db_user';
  ELSE
    ALTER ROLE "$db_user" WITH PASSWORD '$db_pass_escaped';
    RAISE NOTICE 'Updated password for role %', '$db_user';
  END IF;
  ALTER ROLE "$db_user" CREATEDB;
END
\$\$;
SELECT 'CREATE DATABASE "$db_name" OWNER "$db_user"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db_name') \gexec
GRANT CONNECT ON DATABASE "$db_name" TO "$db_user";
GRANT ALL PRIVILEGES ON DATABASE "$db_name" TO "$db_user";
SQL

echo "PROVISION_OK"
PROVISION_SCRIPT

    log_success "Postgres role + database provisioned"

    # Add seaweedfs.internal → 127.0.0.1 alias if not already present.
    # The API's SSRF guard (src/config/env.ts) rejects bare loopback/RFC1918
    # addresses in S3_ENDPOINT on production, so we route around it with this
    # /etc/hosts alias. Idempotent.
    if ! ssh_exec "grep -q 'seaweedfs.internal' /etc/hosts 2>/dev/null"; then
        ssh_exec "echo '127.0.0.1 seaweedfs.internal' >> /etc/hosts"
        log_success "Added seaweedfs.internal → 127.0.0.1 to /etc/hosts"
    else
        log_info "/etc/hosts: seaweedfs.internal already present"
    fi
}

# ── Infrastructure: SeaweedFS + tusd + dirs + buckets ───────────────

provision_infra() {
    log_step "Provisioning infrastructure (SeaweedFS, tusd, dirs)"

    if $DRY_RUN; then
        log_dry_run "Would install/verify SeaweedFS 4.21 at /usr/local/bin/weed"
        log_dry_run "Would install/verify tusd v2.9.2 at /usr/local/bin/tusd"
        log_dry_run "Would write /etc/learn-api/s3.json with production credentials"
        log_dry_run "Would write /etc/learn-api/tusd-start.sh (reads TUSD_HOOK_SECRET at runtime)"
        log_dry_run "Would patch HLS_SIGNING_SECRET into nginx vhost"
        log_dry_run "Would mkdir /var/lib/learn-seaweedfs /var/tmp/learn-transcode"
        return
    fi

    ssh_exec "mkdir -p /etc/learn-api && chmod 700 /etc/learn-api"

    # Write the provision script to a temp file, rsync to server, and execute.
    # We cannot use 'bash -s' + heredoc here because provision_database runs
    # first with a 'bash -s' heredoc containing an inner 'sudo -u postgres psql'
    # heredoc; after that SSH session closes, the ControlMaster socket's stdin
    # pipe is in a state where subsequent bash -s heredocs receive EOF immediately
    # and silently do nothing. Rsyncing a script file bypasses stdin entirely.
    local infra_script="/tmp/learn-provision-infra-$$.sh"

    cat > "$infra_script" <<'PROVISION_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
env_file="$1"
app_dir="$2"
release_id="$3"

echo "step0: s3.json"
s3_key=$(grep '^S3_ACCESS_KEY='    "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
s3_sec=$(grep '^S3_SECRET_KEY='    "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
# TUSD_ACCESS_KEY/TUSD_SECRET_KEY may only be in infra.production.env, not api env; fall back to defaults
tusd_key=$(grep '^TUSD_ACCESS_KEY=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
tusd_sec=$(grep '^TUSD_SECRET_KEY=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
if [ -z "$tusd_key" ]; then tusd_key="49c9c39b96ad66117d345ff3"; fi
if [ -z "$tusd_sec" ]; then tusd_sec="u7YxmtueGHJQnH89TEd5nIQ6GK5BeaR7AQoNZARSbfE="; fi
printf '{"identities":[{"name":"learn-api-rw","credentials":[{"accessKey":"%s","secretKey":"%s"}],"actions":["Admin:learn-uploads","Admin:learn-vod","Read:learn-uploads","Read:learn-vod","Write:learn-uploads","Write:learn-vod","List:learn-uploads","List:learn-vod","Tagging:learn-uploads","Tagging:learn-vod"]},{"name":"tusd-upload","credentials":[{"accessKey":"%s","secretKey":"%s"}],"actions":["Write:learn-uploads","Read:learn-uploads","List:learn-uploads","Tagging:learn-uploads"]},{"name":"anonymous","actions":["Read:learn-vod"]}]}\n' \
    "$s3_key" "$s3_sec" "$tusd_key" "$tusd_sec" > /etc/learn-api/s3.json
chmod 600 /etc/learn-api/s3.json
chown root:root /etc/learn-api/s3.json
echo "s3.json written"

echo "step1: SeaweedFS"
WEED_VERSION="4.21"
WEED_URL="https://github.com/seaweedfs/seaweedfs/releases/download/${WEED_VERSION}/linux_amd64.tar.gz"
need_weed=true
if [ -x /usr/local/bin/weed ]; then
    current_weed=$(/usr/local/bin/weed version 2>/dev/null | head -1 || true)
    if echo "$current_weed" | grep -qw "${WEED_VERSION}"; then
        echo "SeaweedFS ${WEED_VERSION} already installed"
        need_weed=false
    else
        echo "SeaweedFS version mismatch (found: ${current_weed}) — reinstalling"
    fi
fi
if [ "$need_weed" = true ]; then
    echo "Installing SeaweedFS ${WEED_VERSION}..."
    cd /tmp
    curl -fsSL "${WEED_URL}" -o weed.tar.gz
    tar -xzf weed.tar.gz weed
    mv weed /usr/local/bin/weed
    chmod +x /usr/local/bin/weed
    rm weed.tar.gz
    echo "SeaweedFS ${WEED_VERSION} installed"
fi

echo "step2: tusd"
TUSD_VERSION="v2.9.2"
TUSD_URL="https://github.com/tus/tusd/releases/download/${TUSD_VERSION}/tusd_linux_amd64.tar.gz"
need_tusd=true
if [ -x /usr/local/bin/tusd ]; then
    current_tusd=$(/usr/local/bin/tusd --version 2>/dev/null | head -1 || true)
    if echo "$current_tusd" | grep -q "2.9.2"; then
        echo "tusd 2.9.2 already installed"
        need_tusd=false
    else
        echo "tusd version mismatch (found: ${current_tusd}) — reinstalling"
    fi
fi
if [ "$need_tusd" = true ]; then
    echo "Installing tusd ${TUSD_VERSION}..."
    cd /tmp
    curl -fsSL "${TUSD_URL}" -o tusd.tar.gz
    tar -xzf tusd.tar.gz
    mv tusd_linux_amd64/tusd /usr/local/bin/tusd
    chmod +x /usr/local/bin/tusd
    rm -rf tusd_linux_amd64 tusd.tar.gz
    echo "tusd ${TUSD_VERSION} installed"
fi

echo "step4: tusd-start.sh"
tee /etc/learn-api/tusd-start.sh > /dev/null << 'TUSD_START'
#!/bin/bash
set -euo pipefail
HOOK_SECRET=$(grep '^TUSD_HOOK_SECRET=' /etc/learn-api/.env | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
exec /usr/local/bin/tusd \
  --s3-bucket=learn-uploads \
  --s3-endpoint=http://127.0.0.1:8333 \
  "--hooks-http=http://127.0.0.1:3101/internal/hooks/tusd?token=${HOOK_SECRET}" \
  --hooks-enabled-events=pre-create,pre-finish,post-finish \
  --port=1080 \
  --behind-proxy
TUSD_START
chmod 700 /etc/learn-api/tusd-start.sh
echo "tusd-start.sh written"

echo "step5: nginx HLS secret"
NGINX_VHOST="/etc/nginx/sites-available/learn-api.lifestreamdynamics.com"
if [ -f "$env_file" ] && [ -f "$NGINX_VHOST" ]; then
    hls_secret=$(grep '^HLS_SIGNING_SECRET=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
    if [ -n "$hls_secret" ]; then
        escaped_secret=$(printf '%s\n' "$hls_secret" | sed 's/[\/&]/\\&/g')
        sed -i "s/set \\\$secure_link_secret \"[^\"]*\";/set \$secure_link_secret \"${escaped_secret}\";/" \
            "$NGINX_VHOST"
        echo "HLS secret patched into nginx vhost"
    else
        echo "WARN: HLS_SIGNING_SECRET missing from env file" >&2
    fi
else
    echo "INFO: nginx vhost not yet installed — HLS secret will be patched on next nginx deploy"
fi

echo "step6: dirs"
mkdir -p /var/lib/learn-seaweedfs /var/tmp/learn-transcode
chmod 700 /var/lib/learn-seaweedfs /var/tmp/learn-transcode
echo "data directories ready"

echo "PROVISION_INFRA_OK"
PROVISION_SCRIPT

    rsync_to "$infra_script" "$REMOTE_USER@$REMOTE_HOST:/tmp/learn-provision-infra.sh"
    rm -f "$infra_script"
    ssh_exec "bash /tmp/learn-provision-infra.sh '$REMOTE_ENV_FILE' '$REMOTE_APP_DIR' '$RELEASE_ID'"
    ssh_exec "rm -f /tmp/learn-provision-infra.sh"

    log_success "Infrastructure provisioned (SeaweedFS + tusd + dirs)"

    # Restart SeaweedFS outside the heredoc — PM2's IPC socket keeps the SSH
    # channel alive when pm2 is called from inside a bash heredoc over SSH.
    log_info "Restarting SeaweedFS to apply updated IAM credentials..."
    ssh_exec "pm2 restart learn-seaweedfs 2>&1 | tail -1 || true"
    log_success "SeaweedFS restarted"
}

# ── S3 bucket creation (after PM2 cutover starts SeaweedFS) ─────────

provision_buckets() {
    log_step "Creating S3 buckets (learn-uploads, learn-vod)"

    if $DRY_RUN; then
        log_dry_run "Would wait for SeaweedFS :8333, then run create-buckets.sh"
        return
    fi

    ssh_exec 'bash -s' -- "$REMOTE_ENV_FILE" "$REMOTE_APP_DIR" "$RELEASE_ID" <<'BUCKETS_SCRIPT'
set -euo pipefail
env_file="$1"
app_dir="$2"
release_id="$3"

# Wait up to 30s for SeaweedFS :8333 (started by PM2 cutover)
waited=0
while [ "$waited" -lt 30 ]; do
    if ss -ltn 2>/dev/null | grep -q ':8333'; then
        echo "SeaweedFS :8333 is listening"
        break
    fi
    sleep 1
    waited=$((waited + 1))
done
if ! ss -ltn 2>/dev/null | grep -q ':8333'; then
    echo "ERROR: SeaweedFS :8333 not listening after 30s" >&2
    exit 1
fi

release_script="$app_dir/releases/$release_id/infra/scripts/create-buckets.sh"
if [ ! -f "$release_script" ]; then
    echo "ERROR: create-buckets.sh not found at $release_script" >&2
    exit 1
fi

s3_access_key=$(grep '^S3_ACCESS_KEY=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
s3_secret_key=$(grep '^S3_SECRET_KEY=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true)
if [ -z "$s3_access_key" ]; then s3_access_key="learn_access_key"; fi
if [ -z "$s3_secret_key" ]; then s3_secret_key="learn_secret_key"; fi

S3_ENDPOINT=http://127.0.0.1:8333 \
AWS_ACCESS_KEY_ID="$s3_access_key" \
AWS_SECRET_ACCESS_KEY="$s3_secret_key" \
    bash "$release_script"
echo "BUCKETS_OK"
BUCKETS_SCRIPT

    log_success "S3 buckets ready"
}

# ── DB backup + Prisma migrate ──────────────────────────────────────

migrate_database() {
    log_step "Backing up database + running Prisma migrations"

    if $DRY_RUN; then
        log_dry_run "Would pg_dump learn_api_production → /var/backups/learn-api/db-<ts>.sql.gz"
        log_dry_run "Would run: cd releases/$RELEASE_ID/api && npx prisma migrate deploy"
        return
    fi

    ssh_exec 'bash -s' -- "$REMOTE_APP_DIR" "$RELEASE_ID" "$REMOTE_ENV_FILE" <<'MIGRATE_SCRIPT'
set -euo pipefail
app_dir="$1"
release_id="$2"
env_file="$3"

backup_dir="/var/backups/learn-api"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

if [ ! -f "$env_file" ]; then
    echo "MIGRATE:no-env" >&2
    echo "Expected env file at $env_file — aborting." >&2
    exit 1
fi

# Pull DATABASE_URL out of the env file without exporting the whole thing
db_url=$(grep -E '^DATABASE_URL=' "$env_file" | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//')
if [ -z "$db_url" ]; then
    echo "DATABASE_URL missing in $env_file" >&2
    exit 1
fi

ts=$(date +%Y%m%d-%H%M%S)
if pg_dump "$db_url" 2>/dev/null | gzip > "$backup_dir/db-$ts.sql.gz"; then
    echo "BACKUP_OK:$backup_dir/db-$ts.sql.gz"
else
    echo "BACKUP_FAILED (db may not exist yet; continuing)" >&2
fi

# Prune old DB backups (keep 10)
ls -t "$backup_dir"/db-*.sql.gz 2>/dev/null | tail -n +11 | xargs -r rm --

# Validate env file: catch unquoted values containing spaces before sourcing.
# A line like  FOO=hello world  runs "world" as a command under set -a.
bad_lines=$(grep -Ev '^\s*#|^\s*$' "$env_file" | grep -Ev "^[A-Za-z_][A-Za-z0-9_]*=([^[:space:]]*|'[^']*'|\"[^\"]*\")$" || true)
if [ -n "$bad_lines" ]; then
    echo "Env file has lines that are not valid shell assignments:" >&2
    echo "$bad_lines" >&2
    echo "Fix: quote any value that contains spaces or special characters." >&2
    exit 1
fi

# Run migrations from the new release directory, sourcing the env file
cd "$app_dir/releases/$release_id/api"
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a
npx prisma migrate deploy
echo "MIGRATE_OK"
MIGRATE_SCRIPT

    log_success "Database backed up + migrations applied"
}

# ── Cutover: flip "current" symlink, PM2 reload ─────────────────────

perform_cutover() {
    log_step "Performing cutover (symlink flip + PM2 reload)"

    if $DRY_RUN; then
        log_dry_run "Would flip $REMOTE_APP_DIR/current → releases/$RELEASE_ID"
        log_dry_run "Would: pm2 startOrReload deploy/pm2/ecosystem.config.cjs"
        return
    fi

    # Capture previous release so cleanup can reverse-flip if we die
    PREV_RELEASE=$(ssh_exec "readlink $REMOTE_APP_DIR/current 2>/dev/null | xargs -I{} basename {}" || echo "")

    CUTOVER_STARTED=true
    local cutover_start
    cutover_start=$(date +%s)

    ssh_exec 'bash -s' -- \
        "$REMOTE_APP_DIR" "$RELEASE_ID" "$SCRIPT_DIR/pm2/ecosystem.config.cjs" \
        "$PM2_API_NAME" "$PM2_WORKER_NAME" "$REMOTE_ENV_FILE" <<'CUTOVER_SCRIPT'
set -euo pipefail
app_dir="$1"
release_id="$2"
# $3 (local ecosystem path) is informational — we use the copy inside the release
pm2_api="$4"
pm2_worker="$5"
env_file="$6"

# Atomic symlink flip (ln -sfn is atomic on Linux)
ln -sfn "$app_dir/releases/$release_id" "$app_dir/current"

# Reload PM2 using the ecosystem file we rsynced with the release
ecosystem="$app_dir/current/deploy/pm2/ecosystem.config.cjs"
if [ ! -f "$ecosystem" ]; then
    # Fallback: pm2 ecosystem ships separately from api/, shipped as a sibling
    ecosystem="$app_dir/current/pm2/ecosystem.config.cjs"
fi

# Source env file for pm2 startOrReload (pm2 itself loads env_file from the
# ecosystem config, but we pre-source so pm2's own process sees NODE_ENV etc.)
if [ -f "$env_file" ]; then
    bad_lines=$(grep -Ev '^\s*#|^\s*$' "$env_file" | grep -Ev "^[A-Za-z_][A-Za-z0-9_]*=([^[:space:]]*|'[^']*'|\"[^\"]*\")$" || true)
    if [ -n "$bad_lines" ]; then
        echo "Env file has unquoted multi-word values (would execute as commands):" >&2
        echo "$bad_lines" >&2
        exit 1
    fi
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
fi

if [ -f "$ecosystem" ]; then
    pm2 startOrReload "$ecosystem" --update-env
else
    # No ecosystem shipped — use existing PM2 state
    pm2 reload "$pm2_api"    --update-env 2>/dev/null || true
    pm2 reload "$pm2_worker" --update-env 2>/dev/null || true
fi

pm2 save
echo "CUTOVER_OK"
CUTOVER_SCRIPT

    local cutover_end cutover_duration
    cutover_end=$(date +%s)
    cutover_duration=$((cutover_end - cutover_start))
    log_success "Cutover complete in ${cutover_duration}s"
}

# ── Verify ──────────────────────────────────────────────────────────

verify_deployment() {
    log_step "Verifying deployment"

    if $DRY_RUN; then
        log_dry_run "Would curl https://$API_DOMAIN/health"
        return 0
    fi

    local result
    result=$(ssh_exec 'bash -s' -- "$PM2_API_NAME" "$PM2_WORKER_NAME" <<'VERIFY_SCRIPT'
set -u
pm2_api="$1"
pm2_worker="$2"

api_status="failed"
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if pm2 describe "$pm2_api" 2>/dev/null | grep -q 'status.*online'; then
        api_status="online"; break
    fi
    sleep 2
done

worker_status="failed"
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if pm2 describe "$pm2_worker" 2>/dev/null | grep -q 'status.*online'; then
        worker_status="online"; break
    fi
    sleep 2
done

# Infra processes: warn only — a SeaweedFS restart failure should not roll back
# a successful API deploy.
seaweedfs_status="offline"
if pm2 describe learn-seaweedfs 2>/dev/null | grep -q 'status.*online'; then
    seaweedfs_status="online"
fi

tusd_status="offline"
if pm2 describe learn-tusd 2>/dev/null | grep -q 'status.*online'; then
    tusd_status="online"
fi

sleep 2
# Use /health/liveness — a bare process probe that returns 200 regardless of
# infra dependency state (S3, queue). /health is a deep check that fails when
# SeaweedFS or tusd aren't running yet (e.g. first deploy before Docker infra
# is started). If liveness passes, the process is up and serving; log the
# full /health result as a warning for operator awareness.
liveness_status="failed"
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf http://127.0.0.1:3101/health/liveness >/dev/null 2>&1; then
        liveness_status="ok"; break
    fi
    sleep 2
done

deep_health=$(curl -s http://127.0.0.1:3101/health 2>/dev/null || echo '{}')

echo "API_PM2:$api_status"
echo "WORKER_PM2:$worker_status"
echo "SEAWEEDFS_PM2:$seaweedfs_status"
echo "TUSD_PM2:$tusd_status"
echo "API_LIVENESS:$liveness_status"
echo "API_DEEP_HEALTH:$deep_health"
VERIFY_SCRIPT
    )

    local api_pm2 worker_pm2 seaweedfs_pm2 tusd_pm2 api_liveness api_deep_health
    api_pm2=$(echo          "$result" | sed -n 's/^API_PM2://p')
    worker_pm2=$(echo       "$result" | sed -n 's/^WORKER_PM2://p')
    seaweedfs_pm2=$(echo    "$result" | sed -n 's/^SEAWEEDFS_PM2://p')
    tusd_pm2=$(echo         "$result" | sed -n 's/^TUSD_PM2://p')
    api_liveness=$(echo     "$result" | sed -n 's/^API_LIVENESS://p')
    api_deep_health=$(echo  "$result" | sed -n 's/^API_DEEP_HEALTH://p')

    local failed=false

    if [ "$api_pm2" = "online" ];       then log_success "$PM2_API_NAME online";       else log_error "$PM2_API_NAME failed to start"; failed=true; fi
    if [ "$worker_pm2" = "online" ];    then log_success "$PM2_WORKER_NAME online";    else log_error "$PM2_WORKER_NAME failed to start"; failed=true; fi
    # Infra process checks are warnings only — don't set failed=true
    if [ "$seaweedfs_pm2" = "online" ]; then log_success "learn-seaweedfs online";     else log_warning "learn-seaweedfs not online in PM2 — S3/HLS will be unavailable"; fi
    if [ "$tusd_pm2" = "online" ];      then log_success "learn-tusd online";           else log_warning "learn-tusd not online in PM2 — uploads will be unavailable"; fi
    if [ "$api_liveness" = "ok" ];      then log_success "API /health/liveness OK (process up)"; else log_error "API /health/liveness failed (process not responding)"; failed=true; fi
    if echo "$api_deep_health" | grep -q '"status":"ok"'; then
        log_success "API /health OK (all dependencies healthy)"
    else
        log_warning "API /health degraded — some dependencies not yet reachable (S3/SeaweedFS may need infra start)"
        log_info "Deep health: $api_deep_health"
    fi

    if [ "$failed" = true ]; then
        return 1
    fi

    # Public HTTPS probe — use /health/liveness so S3 being down doesn't
    # produce a false "not reachable" warning. A 200 here means TLS, DNS,
    # nginx, and the Node process are all working end-to-end.
    if [ "$SKIP_NGINX" = false ]; then
        local public_status
        public_status=$(curl -so /dev/null -w "%{http_code}" \
            "https://$API_DOMAIN/health/liveness" 2>/dev/null || echo "000")
        if [ "$public_status" = "200" ]; then
            log_success "Public HTTPS reachable: https://$API_DOMAIN/health/liveness ($public_status)"
        else
            log_warning "Public HTTPS probe returned $public_status — DNS or cert may still be pending"
        fi
    fi

    return 0
}

# ── Rollback via symlink flip ───────────────────────────────────────

rollback_deployment() {
    log_step "Rolling back"

    if $DRY_RUN; then
        if [ -n "$ROLLBACK_TARGET" ]; then
            log_dry_run "Would flip current → releases/$ROLLBACK_TARGET"
        else
            log_dry_run "Would flip current → previous release (second-newest under releases/)"
        fi
        log_dry_run "Would pm2 reload both apps with --update-env"
        return 0
    fi

    local target="$ROLLBACK_TARGET"
    if [ -z "$target" ]; then
        target=$(ssh_exec "ls -1t $REMOTE_APP_DIR/releases 2>/dev/null | sed -n '2p'" || echo "")
        if [ -z "$target" ]; then
            log_error "No previous release found under $REMOTE_APP_DIR/releases"
            return 1
        fi
        log_info "Previous release: $target"
    fi

    if ! ssh_exec "test -d $REMOTE_APP_DIR/releases/$target"; then
        log_error "Release not found on remote: $target"
        return 1
    fi

    ssh_exec "ln -sfn $REMOTE_APP_DIR/releases/$target $REMOTE_APP_DIR/current && \
              pm2 reload $PM2_API_NAME --update-env 2>/dev/null || true && \
              pm2 reload $PM2_WORKER_NAME --update-env 2>/dev/null || true && \
              pm2 save"

    log_success "Rolled back to $target"
}

# ── Release retention (keep N most recent) ──────────────────────────

prune_old_releases() {
    log_step "Pruning old releases (keep $KEEP_RELEASES)"

    if $DRY_RUN; then
        log_dry_run "Would delete releases/ entries older than the $KEEP_RELEASES most recent"
        return
    fi

    ssh_exec "cd $REMOTE_APP_DIR/releases && \
              ls -1t 2>/dev/null | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf --"
    log_success "Release retention applied"
}

# ── Landing page ────────────────────────────────────────────────────

sync_landing_page() {
    if [ "$SKIP_LANDING" = true ]; then
        log_info "Skipping landing page (--skip-landing)"
        return
    fi

    log_step "Syncing landing page → $REMOTE_LANDING_DIR"

    local local_landing="$PROJECT_ROOT/infra/landing"
    if [ ! -d "$local_landing" ]; then
        log_warning "infra/landing/ missing — skipping"
        return
    fi

    if $DRY_RUN; then
        log_dry_run "Would rsync $local_landing/ → $REMOTE_LANDING_DIR/"
        return
    fi

    ssh_exec "mkdir -p $REMOTE_LANDING_DIR"
    rsync_to "$local_landing/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_LANDING_DIR/"
    ssh_exec "chown -R root:root $REMOTE_LANDING_DIR && find $REMOTE_LANDING_DIR -type f -exec chmod 644 {} \; && find $REMOTE_LANDING_DIR -type d -exec chmod 755 {} \;"
    log_success "Landing page synced"
}

# ── Nginx (idempotent, hash-based) ──────────────────────────────────

deploy_nginx() {
    if [ "$SKIP_NGINX" = true ]; then
        log_info "Skipping nginx (--skip-nginx)"
        return
    fi

    log_step "Deploying nginx site files"

    if $DRY_RUN; then
        log_dry_run "Would install nginx vhosts for $API_DOMAIN and $LANDING_DOMAIN"
        log_dry_run "Would install snippet: /etc/nginx/snippets/learn-secure_link.conf.inc"
        log_dry_run "Would run: nginx -t && systemctl reload nginx"
        return
    fi

    local api_conf="$SCRIPT_DIR/nginx/learn-api.lifestreamdynamics.com.conf"
    local landing_conf="$SCRIPT_DIR/nginx/learn.lifestreamdynamics.com.conf"
    local snippet="$SCRIPT_DIR/nginx/snippets/secure_link.conf.inc"

    local remote_api="/etc/nginx/sites-available/learn-api.lifestreamdynamics.com"
    local remote_landing="/etc/nginx/sites-available/learn.lifestreamdynamics.com"
    local remote_snippet="/etc/nginx/snippets/learn-secure_link.conf.inc"

    ssh_exec "mkdir -p /etc/nginx/snippets /var/www/certbot"

    # On first deploy the TLS certs don't exist yet — nginx refuses to load a
    # vhost that references a missing certificate. Install HTTP-only stub configs
    # so nginx stays up for the ACME webroot challenge; setup_ssl then issues
    # the certs and reloads nginx with the real (HTTPS) configs.
    local api_cert="/etc/letsencrypt/live/$API_DOMAIN/fullchain.pem"
    local landing_cert="/etc/letsencrypt/live/$LANDING_DOMAIN/fullchain.pem"
    local need_stub=false
    if ! ssh_exec "test -f $api_cert" 2>/dev/null; then need_stub=true; fi
    if ! ssh_exec "test -f $landing_cert" 2>/dev/null; then need_stub=true; fi

    if [ "$need_stub" = true ]; then
        log_warning "TLS certs not yet issued — installing HTTP-only stub configs for ACME challenge"
        ssh_exec 'bash -s' -- "$API_DOMAIN" "$LANDING_DOMAIN" \
            "$remote_api" "$remote_landing" <<'STUB'
set -euo pipefail
api_domain="$1"
landing_domain="$2"
remote_api="$3"
remote_landing="$4"

cat > "$remote_api" <<CONF
server {
    listen 80;
    listen [::]:80;
    server_name $api_domain;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 444; }
}
CONF

cat > "$remote_landing" <<CONF
server {
    listen 80;
    listen [::]:80;
    server_name $landing_domain;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 444; }
}
CONF

ln -sfn "$remote_api"     "/etc/nginx/sites-enabled/$(basename "$remote_api")"
ln -sfn "$remote_landing" "/etc/nginx/sites-enabled/$(basename "$remote_landing")"
nginx -t && systemctl reload nginx
echo "STUB_OK"
STUB
        log_info "HTTP-only stubs installed; certs will be issued by setup_ssl"
        # Install the snippet (needed post-SSL) but don't try to reload nginx
        # with the real vhost configs until certs exist — setup_ssl handles that.
        rsync_to "$snippet" "$REMOTE_USER@$REMOTE_HOST:$remote_snippet"
        log_success "nginx snippet staged (will activate after cert issuance)"
        return
    fi

    # Certs already exist — install real configs with hash-based change detection
    local changed=false

    for pair in \
        "$api_conf|$remote_api" \
        "$landing_conf|$remote_landing" \
        "$snippet|$remote_snippet"; do
        local src="${pair%%|*}"
        local dst="${pair##*|}"

        local local_hash remote_hash
        local_hash=$(md5sum "$src" | cut -d' ' -f1)
        remote_hash=$(ssh_exec "md5sum $dst 2>/dev/null | cut -d' ' -f1" || echo "none")

        if [ "$local_hash" != "$remote_hash" ]; then
            rsync_to "$src" "$REMOTE_USER@$REMOTE_HOST:$dst"
            log_success "Updated: $dst"
            changed=true
        else
            log_info "Unchanged: $dst"
        fi
    done

    # Enable sites (idempotent)
    ssh_exec "ln -sfn $remote_api /etc/nginx/sites-enabled/learn-api.lifestreamdynamics.com && \
              ln -sfn $remote_landing /etc/nginx/sites-enabled/learn.lifestreamdynamics.com"

    if [ "$changed" = true ]; then
        log_info "Testing nginx configuration..."
        if ssh_exec "nginx -t" 2>&1; then
            ssh_exec "systemctl reload nginx"
            log_success "nginx reloaded"
        else
            log_error "nginx -t failed — NOT reloading"
            exit 1
        fi
    else
        log_info "No nginx changes; skipping reload"
    fi
}

# ── SSL (Let's Encrypt) ─────────────────────────────────────────────

setup_ssl() {
    if [ "$SKIP_SSL" = true ]; then
        log_info "Skipping SSL (--skip-ssl)"
        return
    fi

    log_step "Setting up SSL (Let's Encrypt via webroot)"

    if $DRY_RUN; then
        log_dry_run "Would certbot certonly --webroot -w /var/www/certbot for $API_DOMAIN and $LANDING_DOMAIN"
        return
    fi

    ssh_exec "mkdir -p /var/www/certbot"

    local any_issued=false
    for domain in "$API_DOMAIN" "$LANDING_DOMAIN"; do
        local cert_path="/etc/letsencrypt/live/$domain/fullchain.pem"
        if ssh_exec "test -f $cert_path"; then
            log_info "Cert already present for $domain"
            continue
        fi
        log_info "Requesting certificate for $domain..."
        if ssh_exec "certbot certonly --webroot -w /var/www/certbot -d $domain --non-interactive --agree-tos --email $LE_EMAIL"; then
            log_success "Cert issued: $domain"
            any_issued=true
        else
            log_warning "Cert request failed for $domain — check DNS A-record + port 80 reachability"
        fi
    done

    # After cert issuance, replace the HTTP-only stub configs with the real
    # HTTPS vhost configs and reload nginx. This is idempotent — if both certs
    # already existed and any_issued=false, we still check if the real configs
    # differ from what's on disk (handles the case where certs pre-existed but
    # configs were stubs from a previous partial deploy).
    local api_conf="$SCRIPT_DIR/nginx/learn-api.lifestreamdynamics.com.conf"
    local landing_conf="$SCRIPT_DIR/nginx/learn.lifestreamdynamics.com.conf"
    local remote_api="/etc/nginx/sites-available/learn-api.lifestreamdynamics.com"
    local remote_landing="/etc/nginx/sites-available/learn.lifestreamdynamics.com"

    local api_cert="/etc/letsencrypt/live/$API_DOMAIN/fullchain.pem"
    local landing_cert="/etc/letsencrypt/live/$LANDING_DOMAIN/fullchain.pem"

    if ssh_exec "test -f $api_cert && test -f $landing_cert" 2>/dev/null; then
        local changed=false
        for pair in "$api_conf|$remote_api" "$landing_conf|$remote_landing"; do
            local src="${pair%%|*}"
            local dst="${pair##*|}"
            local local_hash remote_hash
            local_hash=$(md5sum "$src" | cut -d' ' -f1)
            remote_hash=$(ssh_exec "md5sum $dst 2>/dev/null | cut -d' ' -f1" || echo "none")
            if [ "$local_hash" != "$remote_hash" ]; then
                rsync_to "$src" "$REMOTE_USER@$REMOTE_HOST:$dst"
                log_success "Installed real vhost config: $dst"
                changed=true
            fi
        done

        if [ "$changed" = true ] || [ "$any_issued" = true ]; then
            log_info "Testing nginx configuration..."
            if ssh_exec "nginx -t" 2>&1; then
                ssh_exec "systemctl reload nginx"
                log_success "nginx reloaded with HTTPS configs"
            else
                log_error "nginx -t failed after cert issuance — check vhost syntax"
                exit 1
            fi
        else
            log_info "nginx configs already up to date; no reload needed"
        fi
    else
        log_warning "One or more certs still missing — nginx left with HTTP-only stubs"
    fi
}

# ── Summary ─────────────────────────────────────────────────────────

show_summary() {
    log_step "Deployment summary"

    if $DRY_RUN; then
        log_info "Dry run complete — no remote changes were made."
        log_info "Release id that WOULD have been used: ${RELEASE_ID:-<not resolved>}"
        log_info ""
        log_info "Pass-through action plan:"
        log_info "  - build api/ locally (npm ci, prisma generate, npm run build)"
        log_info "  - rsync release to $REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR/releases/<id>/"
        if [ "$SYNC_ENV" = true ]; then
            log_info "  - rsync ops/env/api.production.env → $REMOTE_ENV_FILE"
        else
            log_info "  - env file left untouched (pass --sync-env to rotate)"
        fi
        log_info "  - create learn_api_user role + learn_api_production DB if missing"
        log_info "  - install SeaweedFS 4.21 + tusd v2.9.2 (idempotent)"
        log_info "  - write /etc/learn-api/tusd-start.sh + patch nginx HLS secret"
        log_info "  - mkdir /var/lib/learn-seaweedfs /var/tmp/learn-transcode"
        log_info "  - start learn-seaweedfs via PM2, create S3 buckets"
        log_info "  - pg_dump backup + prisma migrate deploy"
        log_info "  - symlink $REMOTE_APP_DIR/current → releases/<id>"
        log_info "  - pm2 startOrReload deploy/pm2/ecosystem.config.cjs"
        if [ "$SKIP_LANDING" = false ]; then
            log_info "  - rsync infra/landing/ → $REMOTE_LANDING_DIR/"
        fi
        if [ "$SKIP_NGINX" = false ]; then
            log_info "  - deploy nginx vhosts (API + landing) + snippet, reload on hash change"
        fi
        if [ "$SKIP_SSL" = false ]; then
            log_info "  - certbot webroot for $API_DOMAIN + $LANDING_DOMAIN"
        fi
        log_info "  - verify health: https://$API_DOMAIN/health"
        log_info "  - prune to newest $KEEP_RELEASES releases"
        return
    fi

    log_success "Lifestream Learn deployed."
    log_info ""
    log_info "API:     https://$API_DOMAIN"
    log_info "Landing: https://$LANDING_DOMAIN"
    log_info "Health:  https://$API_DOMAIN/health"
    log_info ""
    log_info "Useful commands:"
    log_info "  API logs:      ssh $REMOTE_USER@$REMOTE_HOST 'pm2 logs $PM2_API_NAME'"
    log_info "  Worker logs:   ssh $REMOTE_USER@$REMOTE_HOST 'pm2 logs $PM2_WORKER_NAME'"
    log_info "  PM2 status:    ssh $REMOTE_USER@$REMOTE_HOST 'pm2 status'"
    log_info "  Rollback:      $0 --rollback"
    log_info "  Release id:    $RELEASE_ID"
}

# ── Main ────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    mkdir -p "$LOG_DIR"

    printf "%b" "${BOLD}${BLUE}"
    cat <<'BANNER'
==================================================================
  Lifestream Learn production deploy
==================================================================
BANNER
    printf "%b" "${NC}"

    if $DRY_RUN; then
        log_warning "DRY-RUN mode — no remote changes will be made."
    fi

    log_info "Target:    $REMOTE_USER@$REMOTE_HOST:$REMOTE_APP_DIR"
    log_info "API:       $API_DOMAIN"
    log_info "Landing:   $LANDING_DOMAIN"
    log_info "Env file:  $REMOTE_ENV_FILE (rsync only with --sync-env)"

    trap cleanup EXIT

    # ── Rollback path ──
    if $ROLLBACK_MODE; then
        acquire_lock
        if $DRY_RUN; then
            log_warning "Dry-run rollback: not opening SSH, not touching remote."
        else
            init_ssh_controlmaster
            check_ssh_connectivity
        fi
        rollback_deployment
        exit $?
    fi

    # ── Deploy path ──
    acquire_lock
    check_local_prerequisites
    resolve_git_sha

    if $DRY_RUN; then
        log_step "Dry-run preflight (no remote calls)"
        log_dry_run "Would check SSH connectivity to $REMOTE_USER@$REMOTE_HOST"
        log_dry_run "Would check remote prerequisites (node, pm2, nginx, ffmpeg, certbot, psql, redis)"
        log_dry_run "Would run local validate suite"
        log_dry_run "Would build + stage release $RELEASE_ID"
    else
        init_ssh_controlmaster
        check_ssh_connectivity
        check_remote_prerequisites
        run_pre_deployment_validation
        build_and_stage
        rsync_release_to_remote
        sync_env_file
        provision_database
        provision_infra
        migrate_database
        perform_cutover
        provision_buckets
        sync_landing_page
        deploy_nginx
        setup_ssl

        if ! verify_deployment; then
            log_error "Health checks failed"
            rollback_deployment
            exit 1
        fi

        prune_old_releases
    fi

    show_summary
}

main "$@"
