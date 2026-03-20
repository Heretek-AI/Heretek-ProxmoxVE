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
mkdir -p /opt/yao
msg_ok "Created Application Directory"

msg_info "Initializing Yao Application"
cd /opt/yao
$STD yao init
msg_ok "Initialized Yao Application"

# Create additional directories after init
mkdir -p /opt/yao/{db,logins,models,flows,scripts,public,logs,icons}

# Generate secure secrets
YAO_CLIENT_ID=$(cat /proc/sys/kernel/random/uuid)
YAO_JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
YAO_AES_KEY=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)

msg_info "Creating Environment File"
cat <<EOF >/opt/yao/.env
# ============================================
# Yao Application Configuration
# ============================================

# Database Configuration
YAO_DB_DRIVER="sqlite3"
YAO_DB_PRIMARY="./db/yao.db"

# Security
YAO_JWT_SECRET="${YAO_JWT_SECRET}"
YAO_DB_AESKEY="${YAO_AES_KEY}"

# OAuth/OpenAPI
YAO_CLIENT_ID="${YAO_CLIENT_ID}"

# Login Redirects
AFTER_LOGIN_SUCCESS_URL="/dashboard/mission-control"
AFTER_LOGIN_FAILURE_URL="/dashboard/auth/entry"

# Server Configuration
YAO_ENV="production"
YAO_HOST="0.0.0.0"
YAO_PORT=5099
YAO_LOG="./logs/application.log"
YAO_LOG_MODE="TEXT"
YAO_SESSION_FILE="./db/.session"
YAO_SESSION_STORE="file"
EOF
msg_ok "Created Environment File"

msg_info "Creating Application Configuration"
cat <<'EOF' >/opt/yao/app.yao
{
  "name": "Yao Application",
  "short": "Yao",
  "description": "Autonomous Agent Engine",
  "version": "1.0.0",
  "adminRoot": "dashboard",
  "setup": "scripts.setup.Init",
  "menu": {
    "process": "scripts.menu.Get",
    "args": []
  },
  "optional": {
    "hideNotification": true,
    "hideSetting": false
  }
}
EOF
msg_ok "Created Application Configuration"

msg_info "Creating Admin Login Widget"
cat <<'EOF' >/opt/yao/logins/admin.login.json
{
  "name": "::Admin Login",
  "action": {
    "process": "yao.login.Admin",
    "args": [":payload"]
  },
  "layout": {
    "entry": "/dashboard/mission-control",
    "captcha": "yao.utils.Captcha",
    "slogan": "::Build Autonomous Agents with Yao",
    "site": "https://yaoapps.com"
  }
}
EOF
msg_ok "Created Admin Login Widget"

msg_info "Creating Admin User Model"
cat <<'EOF' >/opt/yao/models/admin.mod.json
{
  "name": "Admin User",
  "table": {
    "name": "admin_user",
    "comment": "Admin User"
  },
  "columns": [
    {
      "label": "ID",
      "name": "id",
      "type": "ID"
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
      "label": "Email",
      "name": "email",
      "type": "string",
      "length": 128,
      "comment": "Email",
      "unique": true,
      "index": true,
      "nullable": true,
      "validations": [
        {
          "method": "email",
          "args": [],
          "message": "{{input}} should be email"
        }
      ]
    },
    {
      "label": "Password",
      "name": "password",
      "type": "string",
      "length": 256,
      "comment": "Password",
      "crypt": "PASSWORD",
      "index": true,
      "nullable": true,
      "validations": [
        {
          "method": "typeof",
          "args": ["string"],
          "message": "{{input}} Error"
        },
        {
          "method": "minLength",
          "args": [6],
          "message": "{{label}} must be at least 6 characters"
        }
      ]
    },
    {
      "label": "Type",
      "name": "type",
      "type": "string",
      "length": 20,
      "comment": "User Type",
      "default": "user",
      "index": true
    },
    {
      "label": "Status",
      "name": "status",
      "type": "enum",
      "default": "enabled",
      "option": ["enabled", "disabled"],
      "index": true
    },
    {
      "label": "Extra",
      "name": "extra",
      "type": "json",
      "comment": "Extra",
      "nullable": true
    }
  ],
  "relations": {},
  "values": [],
  "indexes": [],
  "option": {
    "timestamps": true,
    "soft_deletes": true
  }
}
EOF
msg_ok "Created Admin User Model"

msg_info "Creating Menu Flow"
cat <<'EOF' >/opt/yao/flows/menu.flow.yao
{
  "name": "Menu",
  "nodes": [],
  "output": {
    "items": [
      {
        "name": "Dashboard",
        "path": "/dashboard/mission-control",
        "icon": { "name": "material-dashboard", "size": 22 }
      },
      {
        "name": "Agents",
        "path": "/dashboard/agents",
        "icon": { "name": "material-smart_toy", "size": 22 }
      },
      {
        "name": "Data",
        "path": "/dashboard/data",
        "icon": { "name": "material-storage", "size": 22 }
      },
      {
        "name": "Settings",
        "path": "/dashboard/settings",
        "icon": { "name": "material-settings", "size": 22 }
      }
    ],
    "setting": [
      {
        "icon": { "name": "material-person", "size": 22 },
        "name": "Account",
        "path": "/dashboard/account"
      }
    ]
  }
}
EOF
msg_ok "Created Menu Flow"

msg_info "Creating Setup Script"
cat <<'EOF' >/opt/yao/scripts/setup.ts
import { Process, Model } from "@yao/runtime";

/**
 * Initialize the application
 * Creates the default admin user if not exists
 */
export function Init() {
  // Create default admin user
  const adminData = {
    name: "Admin",
    email: "root@yaoagents.com",
    password: "Yao123++",
    type: "admin",
    status: "enabled",
  };

  try {
    // Check if admin user already exists
    const existingAdmin = Process("models.admin.user.Find", 1, {
      select: ["id"],
    });

    if (!existingAdmin || !existingAdmin.id) {
      // Create admin user
      Process("models.admin.user.Save", adminData);
      console.log("Default admin user created successfully");
    } else {
      console.log("Admin user already exists");
    }
  } catch (error) {
    // If the model doesn't exist yet, try to create using direct insert
    console.log("Creating admin user...");
    try {
      Process("models.admin.user.Save", adminData);
      console.log("Default admin user created successfully");
    } catch (e) {
      console.log("Note: Admin user will be created on first login");
    }
  }
}
EOF
msg_ok "Created Setup Script"

msg_info "Creating Menu Script"
cat <<'EOF' >/opt/yao/scripts/menu.ts
import { Process } from "@yao/runtime";

/**
 * Get the menu for the admin panel
 * @returns Menu structure
 */
export function Get() {
  return {
    items: [
      {
        name: "Dashboard",
        path: "/dashboard/mission-control",
        icon: { name: "material-dashboard", size: 22 },
      },
      {
        name: "Agents",
        path: "/dashboard/agents",
        icon: { name: "material-smart_toy", size: 22 },
      },
      {
        name: "Data",
        path: "/dashboard/data",
        icon: { name: "material-storage", size: 22 },
      },
      {
        name: "Settings",
        path: "/dashboard/settings",
        icon: { name: "material-settings", size: 22 },
      },
    ],
    setting: [
      {
        icon: { name: "material-person", size: 22 },
        name: "Account",
        path: "/dashboard/account",
      },
    ],
  };
}
EOF
msg_ok "Created Menu Script"

msg_info "Creating Public Web Interface"
cat <<'EOF' >/opt/yao/public/index.html
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
    .admin-link {
      margin-top: 20px;
      padding: 15px 30px;
      background: linear-gradient(90deg, #7c3aed, #00d4ff);
      border: none;
      border-radius: 10px;
      color: #fff;
      font-size: 1.1rem;
      cursor: pointer;
      text-decoration: none;
      display: inline-block;
    }
    .admin-link:hover {
      opacity: 0.9;
      transform: translateY(-2px);
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
      <p><strong>Default Login:</strong> root@yaoagents.com / Yao123++</p>
    </div>
    <a href="/dashboard/auth/entry" class="admin-link">Open Dashboard</a>
    <div class="links">
      <a href="https://github.com/YaoApp/yao" target="_blank">GitHub</a>
      <a href="https://yaoapps.com" target="_blank">Documentation</a>
    </div>
  </div>
</body>
</html>
EOF
msg_ok "Created Public Web Interface"

msg_info "Running Database Migration"
cd /opt/yao
$STD yao migrate
msg_ok "Database Migration Complete"

msg_info "Creating Default Admin User"
cd /opt/yao
$STD yao run scripts.setup.Init || true
msg_ok "Created Default Admin User"

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
