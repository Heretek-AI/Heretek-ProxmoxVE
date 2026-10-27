#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Yamz-Labs/kyojin

APP="Kyojin"
var_tags="${var_tags:-ai;llm;inference;rocm}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-122880}"
var_disk="${var_disk:-160}"
var_os="${var_os:-ubuntu}"
var_version="${var_version:-24.04}"
var_unprivileged="${var_unprivileged:-1}"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /usr/local/bin/kyojin-build ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Kyojin's GitHub releases stopped at 1.5.10 while its tags went on, so
  # updates follow the newest vX.Y.Z tag.
  msg_info "Checking for updates"
  CURRENT=$(cat "$HOME/.kyojin" 2>/dev/null || true)
  LATEST=$(/usr/local/bin/kyojin-build --latest)
  msg_ok "Checked for updates"
  if [[ -z "$LATEST" ]]; then
    msg_error "Could not read the Kyojin tags"
    exit 1
  fi
  if [[ "$CURRENT" == "$LATEST" ]]; then
    msg_ok "${APP} is already at ${LATEST}"
    exit
  fi

  # The new tree is built next to the running one and swapped in only when the
  # build succeeds, so the service keeps running until the restart.
  msg_info "Building ${APP} ${LATEST} (about 10 minutes)"
  $STD /usr/local/bin/kyojin-build "$LATEST"
  msg_ok "Built ${APP} ${LATEST}"

  msg_info "Restarting Service"
  systemctl restart kyojin
  msg_ok "Restarted Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} OpenAI-compatible API (after the model download and load finish):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8731/v1${CL}"
echo -e "${INFO}${YW} Model and server options: /opt/kyojin/kyojin.env${CL}"
