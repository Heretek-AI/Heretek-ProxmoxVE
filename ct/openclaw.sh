#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}"/misc/build.func)
# Author: BIllyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/openclaw/openclaw
# Documentation: https://docs.openclaw.ai

APP="openclaw"
var_tags="${var_tags:-ai;assistant;automation}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if openclaw is installed (npm global bin location varies)
  if ! command -v openclaw &>/dev/null && [[ ! -f /home/openclaw/.npm-global/bin/openclaw ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Get current version
  # Using sudo -u since openclaw user has nologin shell
  CURRENT_VERSION=$(sudo -u openclaw env PATH="/home/openclaw/.npm-global/bin:$PATH" openclaw --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  
  # Get latest version from npm
  LATEST_VERSION=$(npm view openclaw version 2>/dev/null || echo "unknown")

  if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
    msg_ok "OpenClaw is already up to date (v${CURRENT_VERSION})"
    exit
  fi

  if [[ "$LATEST_VERSION" == "unknown" ]]; then
    msg_error "Unable to check for updates. Please try again later."
    exit
  fi

  msg_info "Updating OpenClaw from v${CURRENT_VERSION} to v${LATEST_VERSION}"
  
  msg_info "Stopping Gateway Service"
  sudo -u openclaw systemctl --user stop openclaw-gateway 2>/dev/null || true
  msg_ok "Stopped Gateway Service"

  msg_info "Backing up Configuration"
  BACKUP_DIR="/tmp/openclaw_backup_$(date +%Y%m%d_%H%M%S)"
  if [[ -d /home/openclaw/.openclaw ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -r /home/openclaw/.openclaw/* "$BACKUP_DIR"/ 2>/dev/null || true
    msg_ok "Backed up Configuration to $BACKUP_DIR"
  else
    msg_warn "No configuration directory found"
  fi

  msg_info "Updating OpenClaw Package"
  # Run npm update as the openclaw user using sudo -u (nologin shell)
  sudo -u openclaw env PATH="/home/openclaw/.npm-global/bin:$PATH" npm update -g openclaw 2>/dev/null
  msg_ok "Updated OpenClaw Package"

  msg_info "Verifying Update"
  NEW_VERSION=$(sudo -u openclaw env PATH="/home/openclaw/.npm-global/bin:$PATH" openclaw --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  if [[ "$NEW_VERSION" == "$LATEST_VERSION" ]]; then
    msg_ok "Verified OpenClaw v${NEW_VERSION}"
  else
    msg_warn "Version verification failed. Installed: v${NEW_VERSION}, Expected: v${LATEST_VERSION}"
  fi

  msg_info "Starting Gateway Service"
  sudo -u openclaw systemctl --user start openclaw-gateway 2>/dev/null || true
  
  # Wait for service to start
  sleep 3
  
  # Check if service is running
  if sudo -u openclaw systemctl --user is-active openclaw-gateway 2>/dev/null | grep -q "active"; then
    msg_ok "Gateway Service Started"
  else
    msg_warn "Gateway Service may not have started properly"
    msg_info "Checking service status..."
    sudo -u openclaw systemctl --user status openclaw-gateway 2>/dev/null || true
  fi
  
  msg_ok "Updated successfully to v${LATEST_VERSION}!"
  
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "  Post-Update Verification"
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo ""
  echo "  Note: The openclaw user has no login shell. Use 'sudo -u openclaw' to run commands."
  echo ""
  echo "  Run these commands to verify the update:"
  echo "    sudo -u openclaw openclaw --version"
  echo "    sudo -u openclaw openclaw doctor"
  echo "    sudo -u openclaw openclaw gateway status"
  echo ""
  echo "  View logs if issues occur:"
  echo "    sudo -u openclaw openclaw logs --follow"
  echo ""
  echo "  Backup saved to: $BACKUP_DIR"
  echo ""
  
  exit
}

start
build_container
description

msg_ok "Completed Successfully!"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://localhost:18789${CL}"
echo -e "${INFO}${YW} HTTPS Access (secure, works from any machine):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}https://${IP}:18790${CL}"
echo -e "${INFO}${YW} Note: Your browser will warn about self-signed certificate.${CL}"
echo -e "${TAB}${YW}Click 'Advanced' -> 'Proceed to site' to continue.${CL}"
