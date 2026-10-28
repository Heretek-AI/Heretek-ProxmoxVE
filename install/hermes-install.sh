#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Stephen Chin (steveonjava) | Improved by Heretek-AI
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://hermes-agent.nousresearch.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  sudo \
  libx11-6 \
  libxi6 \
  libxkbcommon0
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs

setup_docker

msg_info "Creating Hermes User"
useradd -m -s /bin/bash -G docker hermes
loginctl enable-linger hermes
echo 'export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"' >>/home/hermes/.profile
printf 'hermes ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/90-hermes-nopasswd
chmod 0440 /etc/sudoers.d/90-hermes-nopasswd
msg_ok "Created Hermes User"

msg_info "Configuring Service Environment"
cat <<EOF >/etc/default/hermes
HOME=/home/hermes
PATH=/home/hermes/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NODE_OPTIONS=${NODE_OPTIONS}
EOF
msg_ok "Configured Service Environment"

confirm_external_installer "https://hermes-agent.nousresearch.com/" "https://hermes-agent.nousresearch.com/install.sh"

msg_info "Installing Hermes Agent"
curl_with_retry "https://hermes-agent.nousresearch.com/install.sh" /tmp/hermes-install.sh ||
  curl_with_retry "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh" /tmp/hermes-install.sh
$STD setsid --wait bash -c '
  set -a; source /etc/default/hermes; set +a
  export npm_config_yes=true
  bash /tmp/hermes-install.sh --skip-setup --hermes-home /home/hermes/.hermes --dir /home/hermes/.hermes/hermes-agent
'
rm -f /tmp/hermes-install.sh
chown -R hermes:hermes /home/hermes
chmod 750 /home/hermes
chmod 700 /home/hermes/.hermes
git config --system --add safe.directory /home/hermes/.hermes/hermes-agent 2>/dev/null || true
msg_ok "Installed Hermes Agent"

msg_info "Configuring API Server & Dashboard Auth"
API_SERVER_KEY=$(random_password 32)
DASHBOARD_PASSWORD=$(random_password 24)
mkdir -p /home/hermes/.hermes
cat <<EOF >/home/hermes/.hermes/.env
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=${API_SERVER_KEY}
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${DASHBOARD_PASSWORD}
EOF
chown hermes:hermes /home/hermes/.hermes/.env
chmod 600 /home/hermes/.hermes/.env
msg_ok "Configured API Server & Dashboard Auth"

msg_info "Creating Dashboard Service"
cat <<EOF >/etc/systemd/system/hermes-dashboard.service
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=hermes
Group=hermes
UMask=0077
WorkingDirectory=/home/hermes
ExecStart=/home/hermes/.local/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open
EnvironmentFile=/etc/default/hermes
EnvironmentFile=-/home/hermes/.hermes/.env
Restart=on-failure
RestartSec=5
ProtectProc=invisible
ProcSubset=pid

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hermes-dashboard
msg_ok "Created Dashboard Service"

msg_info "Creating Setup Helper"
cat <<'SETUP' >/usr/bin/hermes-setup
#!/usr/bin/env bash
set -a; source /etc/default/hermes; set +a
/home/hermes/.local/bin/hermes setup
chown -R hermes:hermes /home/hermes
chmod 750 /home/hermes
chmod 700 /home/hermes/.hermes
if [[ -f /home/hermes/.config/systemd/user/hermes-gateway.service ]]; then
  su - hermes -c 'systemctl --user enable --now hermes-gateway && systemctl --user restart hermes-gateway'
fi
echo "Hermes setup complete. File permissions restored."
SETUP
chmod +x /usr/bin/hermes-setup
msg_ok "Created Setup Helper"

msg_info "Configuring Login Hints"
cat <<'HINT' >/etc/profile.d/hermes-hint.sh
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  Run 'hermes-setup' to configure your model provider and gateway server."
  echo "  Use 'su - hermes' (with the dash) to switch to the hermes user."
fi
HINT
msg_ok "Configured Login Hints"

motd_ssh
customize
cleanup_lxc
