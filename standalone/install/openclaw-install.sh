#!/usr/bin/env bash

# Author: BIllyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/openclaw/openclaw

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  ca-certificates \
  build-essential \
  python3 \
  python3-pip \
  python3-venv \
  git \
  procps \
  debian-keyring \
  debian-archive-keyring \
  ffmpeg \
  sudo
msg_ok "Installed Dependencies"

# Install Caddy for HTTPS reverse proxy
msg_info "Installing Caddy (HTTPS Reverse Proxy)"
$STD apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' >/etc/apt/sources.list.d/caddy-stable.list
$STD apt-get update
$STD apt-get install -y caddy
msg_ok "Installed Caddy"

# Setup Node.js 22 (required by OpenClaw)
NODE_VERSION="22" setup_nodejs

# Install uv (Python package manager)
msg_info "Installing uv (Python Package Manager)"
$STD curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
msg_ok "Installed uv"

# Create unprivileged user for OpenClaw
msg_info "Creating OpenClaw User"
if ! id -u openclaw &>/dev/null; then
  useradd -r -s /bin/bash -d /home/openclaw -m openclaw
  # Add openclaw to sudoers for specific operations if needed
  usermod -aG sudo openclaw 2>/dev/null || true
fi
msg_ok "Created OpenClaw User"

msg_info "Installing OpenClaw"
$STD npm install -g openclaw@latest
msg_ok "Installed OpenClaw"

msg_info "Creating Directories"
mkdir -p /opt/openclaw
mkdir -p /home/openclaw/.openclaw
chown -R openclaw:openclaw /opt/openclaw
chown -R openclaw:openclaw /home/openclaw/.openclaw
msg_ok "Created Directories"

msg_info "Creating OpenClaw Configuration"
# Get the container's IP address for allowedOrigins
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
# Get hostname for HTTPS origins
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)
cat <<EOF >/home/openclaw/.openclaw/openclaw.json
{
  "gateway": {
    "bind": "0.0.0.0",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "https://localhost:18790",
        "https://127.0.0.1:18790",
        "https://${CONTAINER_IP}:18790",
        "https://${HOSTNAME_FQDN}:18790"
      ]
    }
  }
}
EOF
chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
msg_ok "Created OpenClaw Configuration"

msg_info "Creating Caddy HTTPS Reverse Proxy"
# Create Caddyfile for HTTPS reverse proxy
# Caddy will automatically generate self-signed certificates for local IPs
cat <<EOF >/etc/caddy/Caddyfile
# OpenClaw HTTPS Reverse Proxy
# Access via https://<container-ip>:18790

:18790 {
    tls internal
    
    # Caddy automatically handles WebSocket upgrades
    reverse_proxy localhost:18789 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
    
    # Log requests
    log {
        output file /var/log/caddy/openclaw.log
        format console
    }
}
EOF

# Create log directory
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

# Enable Caddy
systemctl enable -q caddy
msg_ok "Created Caddy HTTPS Reverse Proxy"

msg_info "Creating OpenClaw Service"
cat <<EOF >/etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw Gateway - Personal AI Assistant
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/opt/openclaw
Environment=NODE_ENV=production
ExecStart=/usr/bin/openclaw gateway --port 18789 --bind 0.0.0.0
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now openclaw
msg_ok "Created OpenClaw Service"

msg_info "Starting Caddy HTTPS Proxy"
# Restart Caddy to apply configuration
systemctl restart caddy
msg_ok "Started Caddy HTTPS Proxy"

motd_ssh
customize
cleanup_lxc
