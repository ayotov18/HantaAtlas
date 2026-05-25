#!/usr/bin/env bash
# 02-tailscale-up.sh — install Tailscale, join the tailnet as ios-backend-prod.
#
# Inputs:
#   TS_AUTHKEY          one-time pre-auth key from your tailnet (required).
#                       Create with: tailnet > Settings > Keys > Auth keys >
#                       reusable=false, ephemeral=false, tags=tag:prod-server.
#   TS_HOSTNAME         machine name in the tailnet (default ios-backend-prod).
#   TS_TAGS             comma-separated tags (default tag:prod-server).
#   ENABLE_SSH          "true" to enable Tailscale SSH (default true).
#   ADVERTISE_ROUTES    optional CIDRs (default empty — do NOT advertise unless needed).
#   EXIT_NODE           "true" to advertise as exit node (default false — do NOT enable unless needed).
#
# After this finishes:
#   - The node should appear in the admin console with tag:prod-server.
#   - Tighten the cloud security group to deny public 22/tcp.
#   - Re-run UFW: only allow SSH on tailscale0 (already configured by 01-).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Must be run as root." >&2
    exit 1
fi

for arg in "$@"; do
    case "$arg" in *=*) export "$arg" ;; esac
done

TS_AUTHKEY="${TS_AUTHKEY:?TS_AUTHKEY is required}"
TS_HOSTNAME="${TS_HOSTNAME:-ios-backend-prod}"
TS_TAGS="${TS_TAGS:-tag:prod-server}"
ENABLE_SSH="${ENABLE_SSH:-true}"
ADVERTISE_ROUTES="${ADVERTISE_ROUTES:-}"
EXIT_NODE="${EXIT_NODE:-false}"

# Install Tailscale (Debian/Ubuntu)
if ! command -v tailscale >/dev/null; then
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg \
        | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list \
        | tee /etc/apt/sources.list.d/tailscale.list >/dev/null
    apt-get update -y
    apt-get install -y tailscale
fi

systemctl enable --now tailscaled

UP_ARGS=(
    --authkey="$TS_AUTHKEY"
    --hostname="$TS_HOSTNAME"
    --advertise-tags="$TS_TAGS"
    --accept-dns=true
)
[[ "$ENABLE_SSH" == "true" ]] && UP_ARGS+=(--ssh)
[[ -n "$ADVERTISE_ROUTES" ]] && UP_ARGS+=(--advertise-routes="$ADVERTISE_ROUTES")
[[ "$EXIT_NODE" == "true" ]] && UP_ARGS+=(--advertise-exit-node)

tailscale up "${UP_ARGS[@]}"

echo
echo "== Tailscale up =="
tailscale status
echo
echo "MagicDNS hostname (if MagicDNS is enabled in admin console):"
echo "  ${TS_HOSTNAME}.<your-tailnet>.ts.net"
echo
echo "Reminder: in the Tailscale admin console:"
echo "  - Enable MagicDNS"
echo "  - Set tag ownership for tag:prod-server (TagOwners → admin group only)"
echo "  - Apply ACL from infra/tailscale/acl.hujson"
echo "  - Run ACL tests (also in acl.hujson)"
echo "  - Require MFA/SSO for the tailnet"
echo "  - Set device key expiry"
