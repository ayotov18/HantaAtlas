#!/usr/bin/env bash
# 03-app-deploy.sh — install the HantaAtlas backend with TLS, systemd, and
# a least-privilege service user. Idempotent.
#
# Inputs:
#   APP_REPO            git URL to clone (default: https://github.com/ayotov18/hantaatls.git)
#   APP_REF             branch/tag/commit (default: main)
#   APP_DOMAIN          public hostname (default: api.thehantaapp.com)
#   ACME_EMAIL          contact email for Let's Encrypt (required)
#   POSTGRES_PASSWORD   strong random password (required)
#   STAGING             "true" to use Let's Encrypt staging (default false)
#
# What it does:
#   - Creates a `hantaatlas` system user (no shell, no home).
#   - Installs Node.js 22 LTS, PostgreSQL 16, nginx, certbot.
#   - Binds Postgres to 127.0.0.1 only.
#   - Clones the backend repo to /opt/hantaatlas, builds it.
#   - Installs systemd units from infra/systemd/.
#   - Installs nginx config from infra/configs/nginx-api.thehantaapp.com.conf.
#   - Issues TLS via certbot, enables auto-renew.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Must be run as root." >&2
    exit 1
fi

for arg in "$@"; do
    case "$arg" in *=*) export "$arg" ;; esac
done

APP_REPO="${APP_REPO:-https://github.com/ayotov18/hantaatls.git}"
APP_REF="${APP_REF:-main}"
APP_DOMAIN="${APP_DOMAIN:-api.thehantaapp.com}"
ACME_EMAIL="${ACME_EMAIL:?ACME_EMAIL required (Let's Encrypt contact)}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD required}"
STAGING="${STAGING:-false}"

APP_DIR=/opt/hantaatlas
SECRET_DIR=/etc/hantaatlas
SECRET_FILE="${SECRET_DIR}/secrets.env"

# ── 1. Packages ────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs git nginx certbot python3-certbot-nginx postgresql postgresql-contrib
npm install -g npm@latest

# ── 2. Service user ─────────────────────────────────────────────────────────
if ! id hantaatlas &>/dev/null; then
    adduser --system --group --no-create-home --shell /usr/sbin/nologin --home "$APP_DIR" hantaatlas
fi

# ── 3. App source ───────────────────────────────────────────────────────────
install -d -m 0755 -o hantaatlas -g hantaatlas "$APP_DIR"
if [[ ! -d "$APP_DIR/.git" ]]; then
    git clone "$APP_REPO" "$APP_DIR"
fi
git -C "$APP_DIR" fetch --all --tags
git -C "$APP_DIR" checkout "$APP_REF"
git -C "$APP_DIR" pull --ff-only origin "$APP_REF" || true
chown -R hantaatlas:hantaatlas "$APP_DIR"

# ── 4. Postgres lock-down ──────────────────────────────────────────────────
PG_VER="$(ls /etc/postgresql/ | head -n1)"
PG_CONF="/etc/postgresql/${PG_VER}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VER}/main/pg_hba.conf"

sed -ri "s/^#?listen_addresses\s*=.*/listen_addresses = '127.0.0.1'/" "$PG_CONF"
sed -ri "s/^#?password_encryption\s*=.*/password_encryption = scram-sha-256/" "$PG_CONF"

cat >"$PG_HBA" <<'EOF'
local   all   postgres                                 peer
local   all   all                                      scram-sha-256
host    all   all   127.0.0.1/32                       scram-sha-256
host    all   all   ::1/128                            scram-sha-256
EOF

systemctl restart postgresql

# Create role/db if missing.
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='hantaatlas'" | grep -q 1 \
    || sudo -u postgres psql -c "CREATE ROLE hantaatlas LOGIN PASSWORD '${POSTGRES_PASSWORD}';"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='hantaatlas'" | grep -q 1 \
    || sudo -u postgres createdb -O hantaatlas hantaatlas

# Always sync the password to whatever was passed.
sudo -u postgres psql -c "ALTER ROLE hantaatlas WITH PASSWORD '${POSTGRES_PASSWORD}';"

# ── 5. Secrets file (chmod 600, owned by hantaatlas) ───────────────────────
install -d -m 0750 -o root -g hantaatlas "$SECRET_DIR"
cat >"$SECRET_FILE" <<EOF
NODE_ENV=production
PORT=3000
HOST=127.0.0.1
LOG_LEVEL=info
SEED_TIMEZONE=Europe/Sofia
API_DOMAIN=${APP_DOMAIN}
CORS_ORIGIN=https://${APP_DOMAIN}
DATABASE_URL=postgresql://hantaatlas:${POSTGRES_PASSWORD}@127.0.0.1:5432/hantaatlas
EOF
chmod 0640 "$SECRET_FILE"
chown root:hantaatlas "$SECRET_FILE"

# ── 6. Build ───────────────────────────────────────────────────────────────
sudo -u hantaatlas -H bash -lc "cd ${APP_DIR} && npm ci --omit=dev=false && npm run prisma:generate && npm run build"

# ── 7. Migrations ──────────────────────────────────────────────────────────
sudo -u hantaatlas -H bash -lc "cd ${APP_DIR} && DATABASE_URL='postgresql://hantaatlas:${POSTGRES_PASSWORD}@127.0.0.1:5432/hantaatlas' npm run prisma:migrate"

# ── 8. systemd units ────────────────────────────────────────────────────────
install -m 0644 "${APP_DIR}/infra/systemd/hantaatlas-api.service"    /etc/systemd/system/hantaatlas-api.service
install -m 0644 "${APP_DIR}/infra/systemd/hantaatlas-worker.service" /etc/systemd/system/hantaatlas-worker.service
systemctl daemon-reload
systemctl enable --now hantaatlas-api.service hantaatlas-worker.service

# ── 9. nginx + TLS ─────────────────────────────────────────────────────────
install -m 0644 "${APP_DIR}/infra/configs/nginx-api.thehantaapp.com.conf" /etc/nginx/sites-available/${APP_DOMAIN}
ln -sf /etc/nginx/sites-available/${APP_DOMAIN} /etc/nginx/sites-enabled/${APP_DOMAIN}
rm -f /etc/nginx/sites-enabled/default

install -d -m 0755 /var/www/certbot
nginx -t
systemctl reload nginx

# Issue cert. Use --staging for testing to avoid LE rate limits.
CERTBOT_FLAGS=(--nginx -n --agree-tos --no-eff-email -m "${ACME_EMAIL}" -d "${APP_DOMAIN}" --redirect)
[[ "$STAGING" == "true" ]] && CERTBOT_FLAGS+=(--staging)
certbot "${CERTBOT_FLAGS[@]}" || {
    echo "certbot failed. DNS for ${APP_DOMAIN} must point at this VPS first." >&2
    exit 1
}

# Renewal timer is enabled by the certbot package; verify.
systemctl enable --now certbot.timer

# ── 10. Logrotate already configured by 01-harden-vps.sh ──
echo "== Deploy complete =="
systemctl --no-pager status hantaatlas-api.service | head -n 8
echo
echo "Public test:"
echo "  curl -fsS https://${APP_DOMAIN}/health"
