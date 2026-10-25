#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/morluto/rea | https://github.com/openbin-ai/binny | https://hermes-agent.nousresearch.com/

# The VM runs install/re-agent-install.sh from this repository inside the image,
# through community-scripts/core's vm-app.func, so the VM and the LXC install
# exactly the same thing.
COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/refs/heads/main}"
source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/api/api.func")
source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/pve/vm-core.func")
source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/pve/vm-app.func")
source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/vm/cloud-init.func") || true
load_functions

APP="RE-Agent"
APP_TYPE="vm"
NSAPP="re-agent-vm"
APP_INSTALL_SCRIPT="re-agent"
var_os="debian"
var_version="13"

GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
THIN="discard=on,ssd=1,"

set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  post_update_to_api "failed" "${command}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

TEMP_DIR=$(mktemp -d)
pushd "$TEMP_DIR" >/dev/null

function default_settings() {
  vm_apply_machine_type "q35"
  VMID=$(get_valid_nextid)
  DISK_SIZE="40G"
  DISK_CACHE=""
  HN="re-agent"
  CPU_TYPE=" -cpu host"
  CORE_COUNT="4"
  RAM_SIZE="8192"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  METHOD="default"
  vm_echo_default_settings
}

function advanced_settings() {
  METHOD="advanced"
  vm_prompt_vmid "${VMID:-$(get_valid_nextid)}"
  vm_prompt_machine_type "q35"
  vm_prompt_disk_size "40G"
  vm_prompt_disk_cache "none"
  vm_prompt_hostname "re-agent"
  vm_prompt_cpu_model "host"
  vm_prompt_cpu_cores "4"
  vm_prompt_ram "8192"
  vm_prompt_bridge "vmbr0"
  vm_prompt_mac "$GEN_MAC"
  vm_prompt_vlan
  vm_prompt_mtu
  vm_prompt_verbose "no"
  vm_prompt_start_vm "yes"

  if vm_confirm_advanced_settings "Ready to create a ${APP} VM?"; then
    echo -e "${CREATING}${BOLD}${DGN}Creating a ${APP} VM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

header_info "$APP"
get_app_metadata

if [[ "${VM_UNATTENDED:-0}" == "1" ]]; then
  OS_TYPE="debian"
  OS_VERSION="13"
  OS_CODENAME="trixie"
  OS_DISPLAY="Debian 13 (Trixie)"
  USE_CLOUD_INIT="no"
else
  select_vm_os
fi

vm_start_script "Use Default Settings?\n\nDefaults:\n• 4 CPU Cores\n• 8 GB RAM\n• 40 GB Disk\n• ${OS_DISPLAY}" 14 58

# install/re-agent-install.sh asks this inside an LXC; the VM build has no
# terminal, so ask on the host instead.
if [[ "${VM_UNATTENDED:-0}" != "1" ]] &&
  ! vm_dialog yesno "EXTERNAL INSTALLER" "The build runs the Hermes Agent installer from https://hermes-agent.nousresearch.com/install.sh, which this repository does not maintain or audit.\n\nContinue?" 12 68; then
  exit_script
fi

post_to_api_vm
vm_select_storage "$HN"

ensure_virt_customize
download_and_cache_image

# The toolchain (Ghidra, JDK, Node, the Python tools) does not fit on the cloud
# image's 3 GB root, and the install runs before the disk is resized, so grow a
# copy of the image first and build from that.
EXPANDED_IMAGE="${TEMP_DIR}/re-agent-base.qcow2"
cp "$CACHE_FILE" "$EXPANDED_IMAGE"
vm_expand_image "$EXPANDED_IMAGE" "$DISK_SIZE" || {
  msg_error "Could not grow the image root filesystem to ${DISK_SIZE}; the toolchain would not fit"
  exit 1
}
CACHE_FILE="$EXPANDED_IMAGE"

customize_vm_image
create_app_vm
wait_for_vm_ip
show_app_vm_summary

echo -e "${INFO}${YW} Configure Hermes inside the VM:${CL}"
echo -e "${TAB}${BGN}re-agent-setup${CL}"
echo -e "${INFO}${YW} Add a custom provider or a memory embeddings API, and let it through the quarantine:${CL}"
echo -e "${TAB}${BGN}re-agent-config provider add <name> <base_url>${CL}"
echo -e "${INFO}${YW} The Hermes dashboard listens on localhost only. Reach it through an SSH tunnel:${CL}"
echo -e "${TAB}${BGN}ssh -L 9119:127.0.0.1:9119 root@${VM_IP:-<IP>}${CL}"
echo -e "${INFO}${YW} Before running samples, quarantine egress and take a baseline snapshot:${CL}"
echo -e "${TAB}${BGN}re-firewall isolate local${CL}"
echo -e "${TAB}${BGN}qm snapshot ${VMID} baseline-clean${CL}"

post_update_to_api "done" "none"
msg_ok "Completed successfully!\n"
