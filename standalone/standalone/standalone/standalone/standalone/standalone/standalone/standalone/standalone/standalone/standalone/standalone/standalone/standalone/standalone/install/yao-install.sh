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
mkdir -p /opt/yao/connectors
mkdir -p /opt/yao/scripts
mkdir -p /opt/yao/suis
mkdir -p /opt/yao/agent
mkdir -p /opt/yao/openapi
mkdir -p /opt/yao/services
mkdir -p /opt/yao/public
mkdir -p /opt/yao/icons
mkdir -p /opt/yao/public/.well-known
mkdir -p /opt/yao/logins
mkdir -p /opt/yao/models/admin
mkdir -p /opt/yao/flows/app
msg_ok "Created Application Directory"

msg_info "Creating Environment File"
cat <<EOF >/opt/yao/.env
YAO_PORT=5099
YAO_STUDIO_PORT=5077
EOF
msg_ok "Created Environment File"

msg_info "Creating Application Configuration"
cat <<EOF >/opt/yao/app.yao
{
  "xgen": "1.0",
  "name": "Yao Application",
  "short": "Yao",
  "description": "Yao Autonomous Agent Engine",
  "version": "1.0.0",
  "adminRoot": "admin",
  "menu": {
    "process": "flows.app.menu",
    "args": ["yao"]
  },
  "optional": {
    "hideNotification": true,
    "hideSetting": false
  }
}
EOF
msg_info "Creating Database Directory"
mkdir -p /opt/yao/db
msg_info "Creating Empty SQLite Database"
sqlite3 /opt/yao/db/yao.db "VACUUM;" 2>/dev/null || touch /opt/yao/db/yao.db
msg_ok "Created Application Configuration"

msg_info "Creating Agent Configuration"
cat <<EOF >/opt/yao/agent/agent.yml
# Yao Agent Configuration
# This is a minimal configuration file for the agent system
version: "1.0"
agents: []
EOF
msg_ok "Created Agent Configuration"

msg_info "Creating OpenAPI Configuration"
cat <<EOF >/opt/yao/openapi/openapi.yao
// OpenAPI Configuration
// This is a minimal configuration file for OpenAPI support
{
  "openapi": "3.0.0",
  "info": {
    "title": "Yao API",
    "version": "1.0.0"
  },
  "paths": {}
}
EOF
msg_ok "Created OpenAPI Configuration"

msg_info "Downloading Application Icons"
curl -fsSL "https://raw.githubusercontent.com/YaoApp/yao-dev-app/main/icons/app.ico" -o /opt/yao/icons/app.ico
curl -fsSL "https://raw.githubusercontent.com/YaoApp/yao-dev-app/main/icons/app.png" -o /opt/yao/icons/app.png
msg_ok "Downloaded Application Icons"

msg_info "Creating Well-Known Configuration"
cat <<EOF >/opt/yao/public/.well-known/yao
{
  "name": "yao-app",
  "version": "1.0.0",
  "description": "Yao Autonomous Agent Engine"
}
EOF
msg_ok "Created Well-Known Configuration"

msg_info "Creating Login Configuration"
cat <<EOF >/opt/yao/logins/admin.login.yao
{
  "name": "Admin Login",
  "action": {
    "process": "yao.login.Admin",
    "args": [":payload"]
  },
  "layout": {
    "entry": "/x/Chart/dashboard",
    "captcha": "yao.utils.Captcha",
    "cover": "/assets/images/login/cover.svg",
    "slogan": "Yao Autonomous Agent Engine",
    "site": "https://yaoapps.com"
  }
}
EOF
cat <<EOF >/opt/yao/logins/user.login.yao
{
  "name": "User Login",
  "action": {
    "process": "scripts.user.Login",
    "args": [":payload"]
  },
  "layout": {
    "entry": "/x/Table/pet",
    "captcha": "yao.utils.Captcha",
    "cover": "/assets/images/login/cover.svg",
    "slogan": "Yao Autonomous Agent Engine",
    "site": "https://yaoapps.com/doc"
  }
}
EOF
msg_ok "Created Login Configuration"

msg_info "Creating Admin User Model"
cat <<EOF >/opt/yao/models/admin/user.mod.yao
{
  "name": "AdminUser",
  "table": { "name": "admin_user", "comment": "The administrator table" },
  "columns": [
    { "label": "ID", "name": "id", "type": "ID" },
    {
      "label": "Type",
      "name": "type",
      "type": "enum",
      "option": ["admin", "staff", "user", "robot"],
      "comment": "AccountTypes: admin, staff, user, robot",
      "default": "user",
      "index": true
    },
    {
      "label": "Email",
      "name": "email",
      "type": "string",
      "length": 50,
      "comment": "Email",
      "index": true,
      "nullable": true
    },
    {
      "label": "Mobile",
      "name": "mobile",
      "type": "string",
      "length": 50,
      "comment": "Mobile",
      "index": true,
      "nullable": true
    },
    {
      "label": "Login Password",
      "name": "password",
      "type": "string",
      "length": 256,
      "comment": "Login Password",
      "crypt": "PASSWORD",
      "index": true,
      "nullable": true
    },
    {
      "label": "Name",
      "name": "name",
      "type": "string",
      "length": 80,
      "comment": "Name",
      "index": true,
      "nullable": true
    },
    {
      "label": "Status",
      "comment": "Status",
      "name": "status",
      "type": "enum",
      "default": "enabled",
      "option": ["enabled", "disabled"],
      "index": true
    }
  ],
  "relations": {},
  "values": [
    {
      "name": "Admin",
      "type": "admin",
      "email": "admin@localhost",
      "password": "admin123",
      "status": "enabled"
    }
  ],
  "indexes": [
    {
      "comment": "Email Unique Index",
      "name": "type_email_unique",
      "columns": ["type", "email"],
      "type": "unique"
    }
  ],
  "option": { "timestamps": true, "soft_deletes": true }
}
EOF
msg_ok "Created Admin User Model"

msg_info "Creating User Login Script"
cat <<EOF >/opt/yao/scripts/user.js
/**
 * User Login
 * @param {*} payload
 */
function Login(payload) {
  log.Trace("[user] Login %s", payload.email);
  return Process("yao.login.Admin", payload);
}
EOF
msg_ok "Created User Login Script"

msg_info "Creating Menu Flow"
cat <<EOF >/opt/yao/flows/app/menu.flow.yao
{
  "label": "Application Menu",
  "version": "1.0.0",
  "description": "Application Menu Flow",
  "nodes": [
    {
      "id": "menu",
      "type": "menu",
      "config": {
        "items": [
          {
            "id": "dashboard",
            "title": "Dashboard",
            "icon": "dashboard",
            "path": "/x/Chart/dashboard"
          },
          {
            "id": "admin",
            "title": "Admin",
            "icon": "admin",
            "path": "/x/Table/admin_user"
          }
        ]
      }
    }
  ],
  "output": "menu"
}
EOF
msg_ok "Created Menu Flow"

msg_info "Creating Public Web Interface"
cat <<EOF >/opt/yao/public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Yao - Autonomous Agent Engine</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
    }
    .container {
      text-align: center;
      padding: 40px;
      background: rgba(255,255,255,0.05);
      border-radius: 20px;
      backdrop-filter: blur(10px);
      box-shadow: 0 8px 32px rgba(0,0,0,0.3);
      max-width: 600px;
    }
    h1 {
      font-size: 3rem;
      margin-bottom: 10px;
      background: linear-gradient(90deg, #00d4ff, #7c3aed);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .subtitle {
      color: #94a3b8;
      font-size: 1.2rem;
      margin-bottom: 30px;
    }
    .status {
      background: rgba(34, 197, 94, 0.2);
      border: 1px solid #22c55e;
      border-radius: 10px;
      padding: 15px;
      margin: 20px 0;
    }
    .status-dot {
      display: inline-block;
      width: 12px;
      height: 12px;
      background: #22c55e;
      border-radius: 50%;
      margin-right: 8px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    .info { color: #cbd5e1; line-height: 1.8; }
    .links {
      margin-top: 30px;
      display: flex;
      gap: 15px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .links a {
      color: #00d4ff;
      text-decoration: none;
      padding: 10px 20px;
      border: 1px solid #00d4ff;
      border-radius: 8px;
      transition: all 0.3s;
    }
    .links a:hover {
      background: #00d4ff;
      color: #1a1a2e;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🤖 Yao</h1>
    <p class="subtitle">Autonomous Agent Engine</p>
    <div class="status">
      <span class="status-dot"></span>
      <span>Service Running</span>
    </div>
    <div class="info">
      <p><strong>Port:</strong> 5099</p>
      <p><strong>Studio Port:</strong> 5077</p>
    </div>
    <div class="links">
      <a href="https://github.com/YaoApp/yao" target="_blank">GitHub</a>
      <a href="https://yaoapps.com" target="_blank">Documentation</a>
    </div>
  </div>
</body>
</html>
EOF
msg_ok "Created Public Web Interface"

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
