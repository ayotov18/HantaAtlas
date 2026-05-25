#!/usr/bin/env bash
# Usage: sudo hantaatlas-tailscale-up.sh tskey-auth-...
set -euo pipefail
KEY="${1:?TS_AUTHKEY required}"
tailscale up \
    --authkey="$KEY" \
    --hostname=ios-backend-prod \
    --advertise-tags=tag:prod-server \
    --ssh \
    --accept-dns=true
tailscale status
echo
echo "Tighten public SSH next:"
echo "  sudo ufw delete limit 22/tcp"
echo "  gcloud compute firewall-rules delete default-allow-ssh --quiet"
