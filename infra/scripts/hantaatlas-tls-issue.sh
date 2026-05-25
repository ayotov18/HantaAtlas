#!/usr/bin/env bash
# Run after the api.thehantaapp.com A record points to this VPS.
# Usage: sudo hantaatlas-tls-issue.sh <admin@example.com>
set -euo pipefail
EMAIL="${1:?email required for ACME contact}"
certbot --nginx -n --agree-tos --no-eff-email -m "$EMAIL" \
    -d api.thehantaapp.com --redirect
nginx -t
systemctl reload nginx
systemctl enable --now certbot.timer
echo "TLS issued. Verify: curl -fsSI https://api.thehantaapp.com/health"
