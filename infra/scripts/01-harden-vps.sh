#!/usr/bin/env bash
# 01-harden-vps.sh — fresh-VPS hardening for the HantaAtlas iOS backend.
# Tested target: Ubuntu 22.04/24.04 LTS or Debian 12. Idempotent.
#
# Run as root on the VPS (or with sudo) on a freshly provisioned host:
#   bash 01-harden-vps.sh \
#       NEW_USER=ops \
#       SSH_PUBKEY="ecdsa-sha2-nistp256 AAAAE2... user@host" \
#       HOSTNAME=ios-backend-prod \
#       TIMEZONE=Europe/Sofia \
#       SSH_PORT=22 \
#       ALLOW_SSH_PUBLIC=false
#
# Variables:
#   NEW_USER             non-root sudoer to create (required)
#   SSH_PUBKEY           authorised_keys content for NEW_USER (required)
#   HOSTNAME             machine hostname (default: ios-backend-prod)
#   TIMEZONE             IANA timezone (default: UTC)
#   SSH_PORT             SSH port (default: 22)
#   ALLOW_SSH_PUBLIC     if "true", UFW allows SSH from anywhere; otherwise
#                        SSH is reachable only over Tailscale (preferred).
#
# After this script completes you should:
#   1. SSH in as $NEW_USER from your authorised key (test in a *new* shell
#      before logging out of root).
#   2. Run 02-tailscale-up.sh to install Tailscale.
#   3. Run 03-app-deploy.sh once Tailscale is up.

set -euo pipefail

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must run as root." >&2
        exit 1
    fi
}

require_root

# ─── Parse env-style positional args (KEY=VALUE) ────────────────────────────
for arg in "$@"; do
    case "$arg" in
        *=*) export "$arg" ;;
    esac
done

NEW_USER="${NEW_USER:?NEW_USER is required}"
SSH_PUBKEY="${SSH_PUBKEY:?SSH_PUBKEY is required}"
HOSTNAME="${HOSTNAME:-ios-backend-prod}"
TIMEZONE="${TIMEZONE:-UTC}"
SSH_PORT="${SSH_PORT:-22}"
ALLOW_SSH_PUBLIC="${ALLOW_SSH_PUBLIC:-false}"

echo "== Hardening VPS =="
echo "  user=$NEW_USER  hostname=$HOSTNAME  tz=$TIMEZONE  ssh_port=$SSH_PORT  public_ssh=$ALLOW_SSH_PUBLIC"

# ─── 1. System inventory (logs only — no destructive changes yet) ───────────
{
    echo "── inventory ──"
    echo "uname:    $(uname -a)"
    echo "os:       $(lsb_release -ds 2>/dev/null || cat /etc/os-release | head -n1)"
    echo "uptime:   $(uptime -p)"
    echo "ips:      $(hostname -I)"
    echo "users:    $(getent passwd | awk -F: '$3>=1000 && $1!="nobody"{print $1}' | tr '\n' ' ')"
    echo "ports:    $(ss -tulnH 2>/dev/null | awk '{print $5}' | sort -u | tr '\n' ' ')"
    echo "services: $(systemctl list-units --type=service --state=running --no-legend --no-pager | awk '{print $1}' | tr '\n' ' ')"
} | tee /var/log/hantaatlas-inventory-$(date +%Y%m%d-%H%M%S).log

# ─── 2. Hostname + timezone ─────────────────────────────────────────────────
hostnamectl set-hostname "$HOSTNAME"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true

# ─── 3. Full system update ──────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        upgrade -y
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y

# ─── 4. Core hardening packages ─────────────────────────────────────────────
apt-get install -y --no-install-recommends \
    ufw fail2ban unattended-upgrades apt-listchanges \
    auditd audispd-plugins \
    ca-certificates curl gnupg lsb-release \
    rsync zstd age \
    htop iotop sysstat \
    needrestart \
    logrotate \
    chrony

# ─── 5. Automatic security updates ──────────────────────────────────────────
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

systemctl enable --now unattended-upgrades

# ─── 6. Non-root sudo user with the supplied SSH key ────────────────────────
if ! id "$NEW_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$NEW_USER"
fi
usermod -aG sudo "$NEW_USER"

install -d -m 0700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
echo "$SSH_PUBKEY" > "/home/$NEW_USER/.ssh/authorized_keys"
chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh/authorized_keys"
chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"

# Passwordless sudo only for this single ops account, with restricted PATH
cat >/etc/sudoers.d/10-${NEW_USER} <<EOF
${NEW_USER} ALL=(ALL) NOPASSWD: ALL
Defaults:${NEW_USER} secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
chmod 0440 /etc/sudoers.d/10-${NEW_USER}

# ─── 7. SSH hardening — keys only, no root, no passwords ────────────────────
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-hantaatlas-hardening.conf
cat >"$SSHD_DROPIN" <<EOF
Port ${SSH_PORT}
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 4
AllowUsers ${NEW_USER}
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF
chmod 0644 "$SSHD_DROPIN"

# Validate before reload
sshd -t
systemctl reload ssh || systemctl reload sshd || true

# ─── 8. Firewall (UFW) — default deny, allow only what's needed ─────────────
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

if [[ "$ALLOW_SSH_PUBLIC" == "true" ]]; then
    ufw limit "${SSH_PORT}/tcp" comment "SSH (rate-limited public)"
fi
# Tailscale interface is always trusted (in-tailnet auth).
ufw allow in on tailscale0 comment "Tailscale tailnet"

# Public web — only if the API is intended to be internet-facing.
ufw allow 80/tcp  comment "HTTP (Let's Encrypt + redirect)"
ufw allow 443/tcp comment "HTTPS (api.thehantaapp.com)"

# Tailscale itself needs UDP 41641 outbound; outbound is already allowed.
ufw --force enable

# ─── 9. fail2ban for any remaining public SSH ───────────────────────────────
install -d -m 0755 /etc/fail2ban
cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
backend = systemd
bantime = 1h
findtime = 10m
maxretry = 5
banaction = ufw

[sshd]
enabled = true
port = ${SSH_PORT}
mode = aggressive

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 10m
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# ─── 10. Audit logging ──────────────────────────────────────────────────────
cat >/etc/audit/rules.d/99-hantaatlas.rules <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group  -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd
-w /var/log/auth.log -p wa -k auth
-w /etc/hantaatlas/ -p wa -k app-config
-w /usr/bin/sudo -p x -k privileged
EOF
augenrules --load
systemctl enable --now auditd

# ─── 11. Kernel/network sysctl hardening ────────────────────────────────────
cat >/etc/sysctl.d/99-hantaatlas-hardening.conf <<'EOF'
# Network — anti-spoof, anti-redirect, conservative ICMP
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Kernel
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0
EOF
sysctl --system

# ─── 12. Disable unused services if present ─────────────────────────────────
for svc in avahi-daemon cups bluetooth ModemManager whoopsie apport; do
    systemctl disable --now "$svc" 2>/dev/null || true
    systemctl mask "$svc" 2>/dev/null || true
done

# ─── 13. Install logrotate config for app logs (created by 03-app-deploy) ──
cat >/etc/logrotate.d/hantaatlas <<'EOF'
/var/log/hantaatlas/*.log {
    weekly
    missingok
    rotate 8
    compress
    delaycompress
    notifempty
    create 0640 hantaatlas adm
    sharedscripts
    postrotate
        systemctl kill -s HUP --kill-who=main hantaatlas-api.service 2>/dev/null || true
        systemctl kill -s HUP --kill-who=main hantaatlas-worker.service 2>/dev/null || true
    endscript
}
EOF
install -d -m 0750 -o root -g adm /var/log/hantaatlas

# ─── 14. World-readable file lockdown for shared dirs ───────────────────────
chmod 0700 /root
chmod 0750 /home/${NEW_USER}
install -d -m 0700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.cache"

# ─── 15. Shell history hygiene (no plain-text history of root sessions) ────
cat >/etc/profile.d/00-hantaatlas-history.sh <<'EOF'
# Restrict history visibility, and never persist root history.
if [ "$(id -u)" -eq 0 ]; then
    unset HISTFILE
fi
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=1000
HISTFILESIZE=2000
readonly HISTCONTROL HISTSIZE HISTFILESIZE
EOF
chmod 0644 /etc/profile.d/00-hantaatlas-history.sh

echo
echo "== Hardening complete =="
echo "Next steps:"
echo "  1) From a NEW shell, verify SSH works as ${NEW_USER}:"
echo "       ssh -p ${SSH_PORT} ${NEW_USER}@<host>"
echo "  2) Run infra/scripts/02-tailscale-up.sh (this will tighten SSH to Tailscale-only if you set ALLOW_SSH_PUBLIC=false)."
echo "  3) Run infra/scripts/03-app-deploy.sh once Tailscale is up."
