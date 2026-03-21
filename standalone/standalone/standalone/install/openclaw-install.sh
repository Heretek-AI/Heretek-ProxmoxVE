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

# Setup Node.js 24 (recommended by OpenClaw)
NODE_VERSION="24" setup_nodejs

# Install uv (Python package manager) - OpenClaw uses Python for some tools
PYTHON_VERSION="3.12" setup_uv

# Create unprivileged user for OpenClaw
msg_info "Creating OpenClaw User"
if ! id -u openclaw &>/dev/null; then
  useradd -r -s /bin/bash -d /home/openclaw -m openclaw
  # Add openclaw to sudoers for specific operations if needed
  usermod -aG sudo openclaw 2>/dev/null || true
fi
msg_ok "Created OpenClaw User"

# Configure npm to use user-writable directory for global packages
msg_info "Configuring npm for User Packages"
mkdir -p /home/openclaw/.npm-global
chown -R openclaw:openclaw /home/openclaw/.npm-global
# Set npm prefix for openclaw user to use home directory
run_user_cmd="su - openclaw -c"
$run_user_cmd "npm config set prefix /home/openclaw/.npm-global"
# Add to PATH for openclaw user
echo 'export PATH=/home/openclaw/.npm-global/bin:$PATH' >> /home/openclaw/.bashrc
msg_ok "Configured npm for User Packages"

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
    "bind": "lan",
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

msg_info "Creating Self-Signed Certificate for HTTPS"
# Generate self-signed certificate with IP in SAN (Caddy's tls internal doesn't work with IPs)
mkdir -p /etc/caddy/certs
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || hostname)

# Generate self-signed certificate valid for 365 days
openssl req -x509 -newkey rsa:4096 -keyout /etc/caddy/certs/openclaw.key \
  -out /etc/caddy/certs/openclaw.crt \
  -days 365 -nodes \
  -subj "/CN=openclaw-local" \
  -addext "subjectAltName=IP:127.0.0.1,IP:${CONTAINER_IP},DNS:localhost,DNS:${HOSTNAME_FQDN}" 2>/dev/null

# Set proper permissions
chmod 644 /etc/caddy/certs/openclaw.crt
chmod 600 /etc/caddy/certs/openclaw.key
chown caddy:caddy /etc/caddy/certs/openclaw.crt /etc/caddy/certs/openclaw.key
msg_ok "Created Self-Signed Certificate"

msg_info "Creating Caddy HTTPS Reverse Proxy"
# Create Caddyfile for HTTPS reverse proxy with explicit certificate paths
cat <<EOF >/etc/caddy/Caddyfile
# OpenClaw HTTPS Reverse Proxy
# Access via https://<container-ip>:18790

:18790 {
    tls /etc/caddy/certs/openclaw.crt /etc/caddy/certs/openclaw.key
    
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

msg_info "Enabling Lingering for OpenClaw User"
# Enable lingering so user-level systemd services start on boot
loginctl enable-linger openclaw 2>/dev/null || true
msg_ok "Enabled Lingering"

msg_info "Initializing OpenClaw Gateway Service"
# Run OpenClaw installer as the openclaw user to create user-level systemd service
# The installer will prompt for hooks and create the service automatically
export PATH="/home/openclaw/.npm-global/bin:$PATH"
$run_user_cmd "openclaw install --no-hooks" 2>/dev/null || true
msg_ok "Initialized OpenClaw Gateway Service"

msg_info "Starting Caddy HTTPS Proxy"
# Restart Caddy to apply configuration
systemctl restart caddy
msg_ok "Started Caddy HTTPS Proxy"

motd_ssh
customize
cleanup_lxc
