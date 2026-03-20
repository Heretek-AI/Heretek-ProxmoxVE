#!/usr/bin/env bash

# Author: Heretek-AI
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/YaoApp/yao

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
  unzip \
  sqlite3
msg_ok "Installed Dependencies"

fetch_and_deploy_gh_release "yao" "YaoApp/yao" "singlefile" "latest" "/usr/local/bin" "yao-*-linux-*"

msg_info "Creating Application Directory"
mkdir -p /opt/yao/data
mkdir -p /opt/yao/etc
msg_ok "Created Application Directory"

msg_info "Creating Environment File"
cat <<EOF >/opt/yao/.env
YAO_PORT=5099
YAO_STUDIO_PORT=5077
EOF
msg_ok "Created Environment File"

msg_info "Creating Minimal Application Configuration"
# Create a minimal app.yao - yao will create the database on first run
cat <<EOF >/opt/yao/app.yao
{
  "name": "yao-app",
  "version": "1.0.0",
  "description": "Yao Autonomous Agent Engine"
}
EOF
# Create db directory and initialize empty SQLite database
mkdir -p /opt/yao/db
# Create empty SQLite database file that yao expects
sqlite3 /opt/yao/db/yao.db "VACUUM;" 2>/dev/null || touch /opt/yao/db/yao.db
msg_ok "Created Minimal Application Configuration"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/yao.service
[Unit]
Description=Yao - Autonomous Agent Engine
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/yao
ExecStart=/usr/local/bin/yao start
Restart=on-failure
RestartSec=5
EnvironmentFile=/opt/yao/.env

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now yao
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
