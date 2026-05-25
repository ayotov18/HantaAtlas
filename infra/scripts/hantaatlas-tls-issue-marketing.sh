#!/usr/bin/env bash
# Issue Let's Encrypt cert for the marketing site (thehantaapp.com + www).
# Uses the existing dns-cloudflare plugin and the same credentials file
# already used to issue api.thehantaapp.com — works through the orange-cloud
# Cloudflare proxy without needing to toggle proxy off.
#
# Usage: sudo hantaatlas-tls-issue-marketing.sh <admin@example.com>
set -euo pipefail

EMAIL="${1:?email required for ACME contact}"
CF_CREDS=/etc/letsencrypt/secrets/cloudflare.ini

if [[ ! -r "$CF_CREDS" ]]; then
    echo "Cloudflare creds not found at $CF_CREDS." >&2
    exit 1
fi

certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CF_CREDS" \
    --dns-cloudflare-propagation-seconds 30 \
    --non-interactive --agree-tos --no-eff-email \
    -m "$EMAIL" \
    --key-type ecdsa \
    -d thehantaapp.com \
    -d www.thehantaapp.com

systemctl enable --now certbot.timer
echo "TLS issued for thehantaapp.com + www.thehantaapp.com."
echo "Verify: ls /etc/letsencrypt/live/thehantaapp.com/"
