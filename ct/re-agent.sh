#!/usr/bin/env bash
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/morluto/rea | https://github.com/openbin-ai/binny | https://hermes-agent.nousresearch.com/

APP="RE-Agent"
var_tags="${var_tags:-ai;malware;reverse-engineering;security;agent}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-8192}"
var_disk="${var_disk:-40}"
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

  if [[ ! -d /opt/ghidra ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "ghidra" "NationalSecurityAgency/ghidra"; then
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "ghidra" "NationalSecurityAgency/ghidra" "prebuild" "latest" "/opt/ghidra" "ghidra_*_PUBLIC_*.zip"
  fi

  if check_for_gh_release "binny" "openbin-ai/binny-releases"; then
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "binny" "openbin-ai/binny-releases" "prebuild" "latest" "/opt/binny" "binny-linux-amd64.tar.gz"
  fi

  if check_for_gh_release "radare2" "radareorg/radare2"; then
    fetch_and_deploy_gh_release "radare2" "radareorg/radare2" "binary" "latest" "" "radare2_*_amd64.deb"
  fi

  if [[ -x /usr/local/bin/r2mcp ]] && check_for_gh_release "r2mcp" "radareorg/radare2-mcp"; then
    fetch_and_deploy_gh_release "r2mcp" "radareorg/radare2-mcp" "binary" "latest" "" "r2mcp_*_amd64.deb"
  fi

  if [[ -d /opt/jadx ]] && check_for_gh_release "jadx" "skylot/jadx"; then
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "jadx" "skylot/jadx" "prebuild" "latest" "/opt/jadx" "jadx-[0-9]*.zip"
    chmod +x /opt/jadx/bin/jadx
  fi

  DIE_DISTRO=$(. /etc/os-release && echo "${ID^}_${VERSION_ID}")
  if check_for_gh_release "die" "horsicq/DIE-engine" &&
    curl -fsSL https://api.github.com/repos/horsicq/DIE-engine/releases/latest |
    jq -e --arg s "_${DIE_DISTRO}_amd64.deb" 'any(.assets[].name; endswith($s))' >/dev/null; then
    fetch_and_deploy_gh_release "die" "horsicq/DIE-engine" "binary" "latest" "" "die_*_${DIE_DISTRO}_amd64.deb"
  fi

  msg_info "Updating REA and triage tools"
  $STD npm update -g rea-agents box-js
  $STD /opt/re-tools-venv/bin/pip install --upgrade flare-capa flare-floss yara-python pefile pyelftools r2pipe \
    oletools msoffcrypto-tool pdfminer.six dnfile dotnetfile androguard py-tlsh stix2 \
    sigma-cli pysigma-backend-splunk pysigma-backend-elasticsearch pysigma-pipeline-sysmon pysigma-pipeline-windows
  [[ -x /opt/ghidra-mcp-venv/bin/pip ]] && $STD /opt/ghidra-mcp-venv/bin/pip install --upgrade pyghidra-mcp
  [[ -x /usr/local/sbin/re-capa-rules ]] && $STD /usr/local/sbin/re-capa-rules
  if [[ -x /opt/re-console-venv/bin/pip ]]; then
    $STD /opt/re-console-venv/bin/pip install --upgrade fastapi uvicorn python-multipart pyzipper
    systemctl try-restart re-console
  fi
  msg_ok "Updated REA and triage tools"

  if [[ -x /home/analyst/.local/bin/hermes ]]; then
    msg_info "Updating Hermes Agent"
    systemctl stop hermes-dashboard
    $STD setsid --wait bash -c '
      set -a; source /etc/default/re-agent; set +a
      /home/analyst/.local/bin/hermes update --yes
      /home/analyst/.local/bin/hermes plugins update --yes
    '
    chown -R analyst:analyst /home/analyst
    systemctl start hermes-dashboard
    msg_ok "Updated Hermes Agent"
  fi
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${RD} This LXC shares the Proxmox host kernel. Use it for static analysis only; run samples in the RE-Agent VM.${CL}"
echo -e "${INFO}${YW} Configure Hermes inside the container:${CL}"
echo -e "${TAB}${BGN}re-agent-setup${CL}"
echo -e "${INFO}${YW} Add a custom provider or a memory embeddings API, and let it through the quarantine:${CL}"
echo -e "${TAB}${BGN}re-agent-config provider add <name> <base_url>${CL}"
echo -e "${INFO}${YW} The case console (9120) and the Hermes dashboard (9119) listen on localhost only. Reach them through an SSH tunnel:${CL}"
echo -e "${TAB}${BGN}ssh -L 9120:127.0.0.1:9120 -L 9119:127.0.0.1:9119 root@${IP}${CL}"
echo -e "${TAB}${GN}then open http://127.0.0.1:9120${CL}"
echo -e "${INFO}${YW} Start a case with:${CL}"
echo -e "${TAB}${BGN}rea-case new <sample>${CL}"
