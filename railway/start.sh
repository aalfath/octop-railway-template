#!/usr/bin/env bash
# Octop on Railway.
#  1. First boot: create the admin from OCTOP_ADMIN_USERNAME / OCTOP_ADMIN_PASSWORD
#     (upstream's `octop init`). No setup wizard, so a stranger can never claim
#     the instance. If the password is rejected, the deploy fails.
#  2. Every boot: add or update the LLM provider from LLM_API_KEY / LLM_BASE_URL /
#     LLM_MODEL when those variables changed.
#  3. First boot: once the server answers, create the admin's first expert.
#  4. exec `octop run`, so the container exits with Octop's own status and
#     Railway's ON_FAILURE policy restarts it after a crash.
set -euo pipefail

log() { echo "[railway] $*"; }
die() { echo "[railway] ERROR: $*" >&2; exit 1; }

export HOME="${HOME:-/data}"
export OCTOP_HOME="${OCTOP_HOME:-$HOME/.octop}"
PORT="${PORT:-8088}"
case "$PORT" in ''|*[!0-9]*) die "PORT must be a number, got '$PORT'" ;; esac
export PORT OCTOP_PORT="$PORT"

mkdir -p "$OCTOP_HOME"
chmod 700 "$OCTOP_HOME"
if ! awk '$5 == "/data" { f = 1 } END { exit !f }' /proc/self/mountinfo 2>/dev/null; then
    log "WARNING: /data is not a mounted volume; all data is lost on redeploy"
fi

cd /app
if [ ! -f "$OCTOP_HOME/octop.db" ]; then
    [ -n "${OCTOP_ADMIN_PASSWORD:-}" ] || die "OCTOP_ADMIN_PASSWORD is empty; refusing to start without an admin"
    log "first boot: creating admin '${OCTOP_ADMIN_USERNAME:-admin}'"
    octop init --yes \
        --admin-username "${OCTOP_ADMIN_USERNAME:-admin}" \
        --admin-password "$OCTOP_ADMIN_PASSWORD" \
        --admin-display-name "${OCTOP_ADMIN_DISPLAY_NAME:-Admin}" \
        || die "octop init failed (see above)"
    touch "$OCTOP_HOME/.initialized"
    touch "$OCTOP_HOME/.railway-first-boot"
fi

python /app/railway/setup.py || die "setup failed (see above)"

if [ -f "$OCTOP_HOME/.railway-first-boot" ]; then
    # Runs in the background with its own copy of the admin password.
    python /app/railway/first_expert.py &
fi

# Agents' shells inherit Octop's environment: keep the bootstrap secrets out.
unset OCTOP_ADMIN_PASSWORD OCTOP_DEFAULT_PASSWORD LLM_API_KEY OPENAI_API_KEY

log "starting Octop on 0.0.0.0:$PORT"
exec octop run --host 0.0.0.0 --port "$PORT"
