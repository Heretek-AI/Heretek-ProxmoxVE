#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Niko1221/Strata

APP="Strata"
var_tags="${var_tags:-ai;llm;inference;rocm}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-65536}"
var_disk="${var_disk:-150}"
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

  if [[ ! -x /root/.local/bin/strata ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "strata" "Niko1221/Strata"; then
    msg_info "Stopping Service"
    systemctl stop strata
    msg_ok "Stopped Service"

    msg_info "Updating ${APP} Terminal and engine to ${CHECK_UPDATE_RELEASE}"
    if ! $STD /root/.local/bin/strata update --wait 120; then
      systemctl start --no-block strata
      msg_error "strata update failed; the previous version is still installed and was started again"
      exit 1
    fi
    echo "${CHECK_UPDATE_RELEASE#v}" >"$HOME/.strata"
    msg_ok "Updated ${APP} Terminal and engine to ${CHECK_UPDATE_RELEASE}"

    msg_info "Starting Service"
    systemctl start --no-block strata
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} OpenAI-compatible API (after the model download finishes):${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/v1${CL}"
echo -e "${INFO}${YW} API key, from inside the container: strata launch --show-key${CL}"
echo -e "${INFO}${YW} Model and launch options: /opt/strata/strata.env${CL}"
