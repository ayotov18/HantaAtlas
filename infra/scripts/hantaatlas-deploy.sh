#!/usr/bin/env bash
# Idempotent deploy. Pulls origin/main; if HEAD changed, builds backend +
# marketing site as needed, restarts services, and reloads nginx if the
# nginx config files changed.
#
# Canonical location: /usr/local/sbin/hantaatlas-deploy
# Run by hantaatlas-deploy.timer every 60s (or manually:
#   sudo systemctl start hantaatlas-deploy.service).
#
# This file lives at infra/scripts/hantaatlas-deploy.sh in the repo and must
# be re-installed via:
#   sudo install -m 0755 /opt/hantaatlas/infra/scripts/hantaatlas-deploy.sh \
#                        /usr/local/sbin/hantaatlas-deploy
# whenever its own contents change.

set -uo pipefail

APP=/opt/hantaatlas
LOG=/var/log/hantaatlas/deploy.log
LOCK=/var/lock/hantaatlas-deploy.lock
MARKETING_WEBROOT=/var/www/thehantaapp.com
HOOK=$(awk -F= '/^LAUNCH_WEBHOOK_URL=/{print $2}' /etc/hantaatlas/healthcheck.env 2>/dev/null)

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$(ts) $*" >> "$LOG"; }
notify() {
    [[ -z "$HOOK" ]] && return
    local title="$1" body="$2" tag="$3" prio="$4"
    curl -fsS -X POST -H "Title: $title" -H "Priority: $prio" -H "Tags: $tag" \
        -d "$body" "$HOOK" >/dev/null 2>&1 || true
}

exec 9>"$LOCK"
flock -n 9 || { log "deploy: already running"; exit 0; }

cd "$APP"
BEFORE=$(sudo -u hantaatlas git -C "$APP" rev-parse HEAD)
sudo -u hantaatlas git -C "$APP" fetch --quiet origin main
TARGET=$(sudo -u hantaatlas git -C "$APP" rev-parse origin/main)

if [[ "$BEFORE" == "$TARGET" ]]; then
    exit 0
fi

log "deploy: $BEFORE → $TARGET"
notify "hantaatlas deploying" "$(echo "$TARGET" | cut -c1-8): $(sudo -u hantaatlas git -C "$APP" log -1 --pretty=%s "$TARGET")" hammer_and_wrench default

sudo -u hantaatlas git -C "$APP" reset --hard "$TARGET" --quiet

CHANGED_FILES=$(sudo -u hantaatlas git -C "$APP" diff --name-only "$BEFORE" "$TARGET" 2>/dev/null)

NEED_INSTALL=no
echo "$CHANGED_FILES" | grep -qE '(^|/)package(-lock)?\.json$' && NEED_INSTALL=yes

NEED_BACKEND_BUILD=no
echo "$CHANGED_FILES" | grep -qE '^(backend/|package(-lock)?\.json$)' && NEED_BACKEND_BUILD=yes

NEED_MARKETING_BUILD=no
echo "$CHANGED_FILES" | grep -qE '^(marketing/|package(-lock)?\.json$)' && NEED_MARKETING_BUILD=yes

NEED_MIGRATE=no
echo "$CHANGED_FILES" | grep -qE '^backend/prisma/migrations/' && NEED_MIGRATE=yes

NEED_NGINX_RELOAD=no
echo "$CHANGED_FILES" | grep -qE '^infra/configs/nginx-.*\.conf$' && NEED_NGINX_RELOAD=yes

if [[ "$NEED_INSTALL" == "yes" ]]; then
    log "deploy: npm ci"
    sudo -u hantaatlas bash -lc "cd $APP && npm ci" >>"$LOG" 2>&1 || { log "deploy: npm ci FAILED"; notify "hantaatlas deploy FAILED" "npm ci failed at $TARGET" rotating_light high; exit 1; }
fi

if [[ "$NEED_MIGRATE" == "yes" ]]; then
    log "deploy: prisma migrate deploy"
    sudo -u hantaatlas bash -lc "cd $APP && DATABASE_URL=\$(grep ^DATABASE_URL /etc/hantaatlas/secrets.env | cut -d= -f2-) npm run prisma:migrate" >>"$LOG" 2>&1 || { log "deploy: migrate FAILED"; notify "hantaatlas deploy FAILED" "prisma migrate failed at $TARGET" rotating_light high; exit 1; }
fi

if [[ "$NEED_BACKEND_BUILD" == "yes" ]]; then
    log "deploy: prisma generate"
    sudo -u hantaatlas bash -lc "cd $APP && npm run prisma:generate" >>"$LOG" 2>&1 || { log "deploy: prisma generate FAILED"; notify "hantaatlas deploy FAILED" "prisma generate failed at $TARGET" rotating_light high; exit 1; }

    log "deploy: backend build"
    sudo -u hantaatlas bash -lc "cd $APP && rm -rf backend/api/dist backend/worker/dist && npm run build" >>"$LOG" 2>&1 || { log "deploy: build FAILED"; notify "hantaatlas deploy FAILED" "build failed at $TARGET" rotating_light high; exit 1; }

    log "deploy: restart hantaatlas-api"
    systemctl restart hantaatlas-api
    sleep 2
    if ! curl -fsS --max-time 5 http://127.0.0.1:3000/health | grep -q '"status":"ok"'; then
        log "deploy: post-restart health check FAILED — rolling back"
        sudo -u hantaatlas git -C "$APP" reset --hard "$BEFORE" --quiet
        sudo -u hantaatlas bash -lc "cd $APP && rm -rf backend/api/dist && npm run build" >>"$LOG" 2>&1
        systemctl restart hantaatlas-api
        sleep 2
        notify "hantaatlas deploy ROLLED BACK" "$TARGET unhealthy; reverted to $BEFORE" rotating_light high
        exit 1
    fi
fi

if [[ "$NEED_MARKETING_BUILD" == "yes" ]]; then
    log "deploy: marketing build"
    sudo -u hantaatlas bash -lc "cd $APP/marketing && rm -rf .next out && npm run build" >>"$LOG" 2>&1 || { log "deploy: marketing build FAILED"; notify "hantaatlas deploy FAILED" "marketing build failed at $TARGET" rotating_light high; exit 1; }

    if [[ -d "$APP/marketing/out" ]]; then
        log "deploy: marketing rsync → $MARKETING_WEBROOT"
        install -d -o www-data -g www-data -m 0755 "$MARKETING_WEBROOT"
        rsync -a --delete "$APP/marketing/out/" "$MARKETING_WEBROOT/" >>"$LOG" 2>&1 || { log "deploy: marketing rsync FAILED"; notify "hantaatlas deploy FAILED" "marketing rsync failed at $TARGET" rotating_light high; exit 1; }
        chown -R www-data:www-data "$MARKETING_WEBROOT"
    fi
fi

if [[ "$NEED_NGINX_RELOAD" == "yes" ]]; then
    log "deploy: nginx -t && reload"
    if nginx -t >>"$LOG" 2>&1; then
        systemctl reload nginx
    else
        log "deploy: nginx config invalid — NOT reloading"
        notify "hantaatlas nginx config invalid" "$TARGET" rotating_light high
    fi
fi

log "deploy: $TARGET live"
notify "hantaatlas deployed" "$(echo "$TARGET" | cut -c1-8) live" rocket default
