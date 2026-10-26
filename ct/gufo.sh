#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/gufo-org/gufo

APP="Gufo"
var_tags="${var_tags:-ai;llm;inference;rocm}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-32768}"
var_disk="${var_disk:-80}"
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

  if [[ ! -x /usr/local/bin/gufo-build ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "gufo" "gufo-org/gufo"; then
    msg_info "Building ${APP} ${CHECK_UPDATE_RELEASE} (can take a while if not cached)"
    $STD /usr/local/bin/gufo-build "$CHECK_UPDATE_RELEASE"
    msg_ok "Built ${APP} ${CHECK_UPDATE_RELEASE}"

    msg_info "Restarting Service"
    systemctl restart gufo
    msg_ok "Restarted Service"

    msg_info "Removing Old Builds"
    $STD /nix/var/nix/profiles/default/bin/nix-collect-garbage -d
    msg_ok "Removed Old Builds"
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
echo -e "${INFO}${YW} API key (inside the container): cat ~/gufo.creds${CL}"
echo -e "${INFO}${YW} Model and server options: /opt/gufo/gufo.env${CL}"
