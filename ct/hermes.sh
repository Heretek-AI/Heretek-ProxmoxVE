#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Stephen Chin (steveonjava) | Improved by Heretek-AI
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://hermes-agent.nousresearch.com/

APP="Hermes"
var_tags="${var_tags:-ai;automation;agent;docker}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-8192}"
var_disk="${var_disk:-32}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /home/hermes/.local/bin/hermes ]]; then
    msg_error "No Hermes Agent Installation Found!"
    exit
  fi

  confirm_external_installer "https://hermes-agent.nousresearch.com/" "hermes update (https://hermes-agent.nousresearch.com/)"

  msg_info "Ensuring System Dependencies & Sudoers"
  $STD apt install -y \
    sudo \
    libx11-6 \
    libxi6 \
    libxkbcommon0
  if [[ ! -f /etc/sudoers.d/90-hermes-nopasswd ]]; then
    printf 'hermes ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/90-hermes-nopasswd
    chmod 0440 /etc/sudoers.d/90-hermes-nopasswd
  fi
  msg_ok "Ensured System Dependencies & Sudoers"

  msg_info "Stopping Services"
  systemctl stop hermes-dashboard
  msg_ok "Stopped Services"

  local update_status=0
  msg_info "Updating Hermes Agent"
  if ! $STD setsid --wait bash -c '
    set -a; source /etc/default/hermes; set +a
    /home/hermes/.local/bin/hermes update --yes
  '; then
    update_status=$?
    msg_warn "Hermes Agent update failed (exit code $update_status)"
  fi
  mapfile -t root_gateway_pids < <(ps -eo user=,pid=,args= | awk '$1 == "root" && /\/home\/hermes\/\.hermes\// && /hermes_cli[.]main/ && / gateway run --replace$/ { print $2 }')
  if ((${#root_gateway_pids[@]})); then
    kill -TERM "${root_gateway_pids[@]}"
    for pid in "${root_gateway_pids[@]}"; do
      deadline=$((SECONDS + 5))
      while kill -0 "$pid" 2>/dev/null; do
        if ((SECONDS >= deadline)); then
          kill -KILL "$pid" 2>/dev/null || true
          break
        fi
        sleep 0.1
      done
    done
  fi
  if ps -eo user=,args= | awk '$1 == "root" && /\/home\/hermes\/\.hermes\// { found = 1 } END { exit !found }'; then
    msg_warn "A root-owned Hermes process is still running; it may keep writing root-owned files"
  fi
  # A writer racing chown makes files vanish between readdir and chown; one retry covers it.
  if ! chown -R hermes:hermes /home/hermes 2>/dev/null; then
    sleep 1
    chown -R hermes:hermes /home/hermes || msg_warn "Could not take ownership of everything under /home/hermes"
  fi
  msg_ok "Updated Hermes Agent"

  msg_info "Starting Services"
  systemctl start hermes-dashboard
  if [[ -f /home/hermes/.config/systemd/user/hermes-gateway.service ]]; then
    su - hermes -c 'systemctl --user restart hermes-gateway' 2>/dev/null ||
      su - hermes -c '/home/hermes/.local/bin/hermes gateway restart' 2>/dev/null || true
  fi
  msg_ok "Started Services"
  if ((update_status != 0)); then
    msg_error "Update failed with exit code $update_status"
    exit "$update_status"
  fi
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}Hermes Agent setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Configure your model provider and gateway server inside the container:${CL}"
echo -e "${TAB}${BGN}hermes-setup${CL}"
echo -e "${INFO} When prompted to install the gateway service, choose 'user service'.${CL}"
DASHBOARD_PASS=$(pct exec "$CTID" -- awk -F'=' '$1=="HERMES_DASHBOARD_BASIC_AUTH_PASSWORD"{print $2}' /home/hermes/.hermes/.env 2>/dev/null || true)
echo -e "${INFO}${YW} Access the Hermes Web Dashboard at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9119${CL}"
echo -e "${INFO}${YW} Dashboard Credentials (stored in /home/hermes/.hermes/.env):${CL}"
echo -e "${TAB}${YW}Username: ${BGN}admin${CL}"
if [[ -n "$DASHBOARD_PASS" ]]; then
  echo -e "${TAB}${YW}Password: ${BGN}${DASHBOARD_PASS}${CL}"
fi
echo -e "${INFO}${YW} Key for Hermes API Server stored in:${CL}"
echo -e "${TAB}${BGN}/home/hermes/.hermes/.env${CL}"
