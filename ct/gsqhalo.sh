#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Aristo94/GSQHalo.cpp

APP="GSQHalo"
var_tags="${var_tags:-ai;llm;inference;rocm}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-65536}"
var_disk="${var_disk:-120}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
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

  if [[ ! -x /usr/local/bin/gsqhalo-build ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # GSQHalo.cpp publishes no releases, so updates follow its gsqhalo branch.
  msg_info "Checking for updates"
  $STD git -C /opt/gsqhalo/src fetch --depth 1 origin gsqhalo
  CURRENT=$(cat "$HOME/.gsqhalo" 2>/dev/null || true)
  LATEST=$(git -C /opt/gsqhalo/src rev-parse FETCH_HEAD)
  msg_ok "Checked for updates"
  if [[ "$CURRENT" == "$LATEST" ]]; then
    msg_ok "${APP} is already at ${LATEST:0:12}"
    exit
  fi

  msg_info "Building ${APP} ${LATEST:0:12} (about 20 minutes)"
  $STD /usr/local/bin/gsqhalo-build
  msg_ok "Built ${APP} ${LATEST:0:12}"

  msg_info "Restarting Service"
  systemctl restart gsqhalo
  msg_ok "Restarted Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} OpenAI-compatible API (after the model download finishes):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/v1${CL}"
echo -e "${INFO}${YW} Model and server options: /opt/gsqhalo/gsqhalo.env${CL}"
