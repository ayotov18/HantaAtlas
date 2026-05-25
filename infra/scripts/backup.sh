#!/usr/bin/env bash
# Encrypted Postgres + config backup. Reads age recipients from
# /etc/hantaatlas/backup-recipients.txt or AGE_RECIPIENTS env.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/hantaatlas}"
AGE_RECIPIENTS="${AGE_RECIPIENTS:?AGE_RECIPIENTS required}"
RETAIN_DAYS="${RETAIN_DAYS:-14}"
PGUSER="${PGUSER:-hantaatlas}"
PGDATABASE="${PGDATABASE:-hantaatlas}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPASSFILE="${PGPASSFILE:-/etc/hantaatlas/.pgpass}"

install -d -m 0700 -o root -g root "$BACKUP_DIR"
ts="$(date -u +%Y%m%d-%H%M)"

age_args=()
for rcpt in $AGE_RECIPIENTS; do
    age_args+=(-r "$rcpt")
done

# Postgres dump → age
PG_OUT="${BACKUP_DIR}/hantaatlas-pg-${ts}.dump.age"
PGPASSFILE="$PGPASSFILE" pg_dump \
    --host="$PGHOST" --username="$PGUSER" --dbname="$PGDATABASE" \
    --format=custom --no-owner --no-privileges \
    | age "${age_args[@]}" -o "$PG_OUT"
chmod 0600 "$PG_OUT"

# Config tarball → age. --ignore-failed-read so missing cert dir before
# first issuance doesn't bork the run; age compresses anyway.
CONF_PATHS=(
    /etc/hantaatlas
    /etc/nginx/sites-available/api.thehantaapp.com
    /etc/systemd/system/hantaatlas-api.service
    /etc/systemd/system/hantaatlas-worker.service
    /etc/systemd/system/hantaatlas-backup.service
)
[[ -d /etc/letsencrypt/live/api.thehantaapp.com ]] && CONF_PATHS+=(/etc/letsencrypt)

CONF_OUT="${BACKUP_DIR}/hantaatlas-conf-${ts}.tar.age"
tar -cf - --ignore-failed-read "${CONF_PATHS[@]}" 2>/dev/null \
    | age "${age_args[@]}" -o "$CONF_OUT"
chmod 0600 "$CONF_OUT"

# Retention prune
find "$BACKUP_DIR" -type f -name "hantaatlas-*.age" -mtime "+${RETAIN_DAYS}" -delete

# Sanity
ls -lh "$PG_OUT" "$CONF_OUT" >/dev/null
echo "Backup complete: $PG_OUT, $CONF_OUT"
