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
  procps
msg_ok "Installed Dependencies"

# Setup Node.js 22 (required by OpenClaw)
NODE_VERSION="22" setup_nodejs

# Install uv (Python package manager)
msg_info "Installing uv (Python Package Manager)"
$STD curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
msg_ok "Installed uv"

# Install Homebrew (Linuxbrew) - use alternative installation for root
msg_info "Installing Homebrew (Linuxbrew)"
# Homebrew refuses to install as root, so we use the alternative untar method
# This installs to /home/linuxbrew/.linuxbrew which is the recommended location
if [[ $EUID -eq 0 ]]; then
  # Create the linuxbrew directory with proper permissions
  mkdir -p /home/linuxbrew/.linuxbrew
  chmod 775 /home/linuxbrew
  chmod 775 /home/linuxbrew/.linuxbrew
  
  # Download and extract Homebrew (alternative installation method)
  cd /tmp
  $STD curl -fsSL https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /home/linuxbrew/.linuxbrew
  
  # Set permissions so brew can be run by anyone
  chown -R root:root /home/linuxbrew/.linuxbrew
  chmod -R g+w /home/linuxbrew/.linuxbrew
  
  # Create symlinks for easy access
  ln -sf /home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew 2>/dev/null || true
  
  # Add to bashrc for persistence
  if ! grep -q 'linuxbrew/.linuxbrew/bin/brew' /root/.bashrc 2>/dev/null; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>/root/.bashrc
  fi
  
  # Add to system profile for all users
  if ! grep -q 'linuxbrew/.linuxbrew' /etc/profile 2>/dev/null; then
    echo 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"' >>/etc/profile
  fi
  
  # Make brew available in current session
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)" || true
else
  # Not running as root, install normally
  $STD /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
msg_ok "Installed Homebrew"

# Install common brew dependencies for OpenClaw skills
msg_info "Installing Homebrew Dependencies"
if command -v brew &>/dev/null || [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  # Use the full path to brew if not in PATH
  BREW_CMD="${BREW_CMD:-/home/linuxbrew/.linuxbrew/bin/brew}"
  if [[ ! -x "$BREW_CMD" ]]; then
    BREW_CMD="brew"
  fi
  # Install ffmpeg for video-frames skill
  $STD $BREW_CMD install ffmpeg 2>/dev/null || true
  # Note: Other brew packages (camsnap, obsidian, summarize, songsee) require specific taps
  # These can be installed manually by the user if needed
fi
msg_ok "Installed Homebrew Dependencies"

msg_info "Installing OpenClaw"
$STD npm install -g openclaw@latest
msg_ok "Installed OpenClaw"

msg_info "Creating Directories"
mkdir -p /opt/openclaw
mkdir -p /root/.openclaw
msg_ok "Created Directories"

msg_info "Creating OpenClaw Configuration"
# Get the container's IP address for allowedOrigins
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
cat <<EOF >/root/.openclaw/openclaw.json
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "http://${CONTAINER_IP}:18789"
      ]
    }
  }
}
EOF
msg_ok "Created OpenClaw Configuration"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw Gateway - Personal AI Assistant
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/openclaw
Environment=NODE_ENV=production
ExecStart=/usr/bin/openclaw gateway --port 18789 --bind lan
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now openclaw
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
