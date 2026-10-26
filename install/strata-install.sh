#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Niko1221/Strata

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  ca-certificates \
  curl \
  jq \
  pciutils \
  tar
msg_ok "Installed Dependencies"

# The Strata Terminal is the headless install path: the AppImage needs FUSE 2,
# which an unprivileged container doesn't have. The Terminal fetches the signed
# engine for this GPU (linux-x86_64-hip-halo on gfx1151) with its own HIP
# runtime, so the container needs no ROCm install.
confirm_external_installer "https://github.com/Niko1221/Strata" "https://github.com/Niko1221/Strata/releases/latest/download/install.sh"

RELEASE=$(curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 60 https://api.github.com/repos/Niko1221/Strata/releases/latest | jq -r '.tag_name')
[[ -n "$RELEASE" && "$RELEASE" != "null" ]] || {
  msg_error "Could not read the latest Strata release"
  exit 1
}

msg_info "Installing Strata Terminal ${RELEASE}"
STRATA_INSTALLER=$(mktemp)
curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 300 \
  "https://github.com/Niko1221/Strata/releases/download/${RELEASE}/install.sh" -o "$STRATA_INSTALLER"
$STD sh "$STRATA_INSTALLER"
rm -f "$STRATA_INSTALLER"
[[ -x /root/.local/bin/strata ]] || {
  msg_error "The Strata installer did not create /root/.local/bin/strata"
  exit 1
}
ln -sf /root/.local/bin/strata /usr/local/bin/strata
echo "${RELEASE#v}" >"$HOME/.strata"
msg_ok "Installed Strata Terminal ${RELEASE}"

msg_info "Configuring Strata"
mkdir -p /opt/strata/models
cat <<'EOF2' >/opt/strata/strata.env
# Strata launch settings. Apply changes with: systemctl restart strata
# Every option is listed by: strata launch --help

# Name of the saved preset. It keeps the API key across restarts.
STRATA_PRESET=Proxmox

# Model, context, access and port. The default is ISTA-DASLab's Qwen3.8-Flash-Next
# Coder (IQ1_M, about 58 GB). Other ISTA-DASLab sizes: --family qwen --model IQ3_S
# (or IQ3_XXS, IQ2_XS, Q2_0). Unsloth: --family unsloth --model UD-Q4_K_XL.
# Models already on disk: --model-path /opt/strata/models/<folder or .gguf>
# --access lan makes an API key; show it with: strata launch --show-key
STRATA_LAUNCH_ARGS=--family coder --model IQ1_M --context 128k --access lan --port 8080 --data-dir /opt/strata/models
EOF2
msg_ok "Configured Strata"

msg_info "Creating Service"
# `strata launch --no-tui` hands the server to Strata's own background host and
# returns, so the unit is a oneshot that stays active while the host runs.
cat <<'EOF2' >/etc/systemd/system/strata.service
[Unit]
Description=Strata inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=HOME=/root
EnvironmentFile=/opt/strata/strata.env
ExecStart=/root/.local/bin/strata launch $STRATA_LAUNCH_ARGS --save-preset ${STRATA_PRESET} --yes --no-tui --restart
ExecStop=/root/.local/bin/strata launch --stop --preset ${STRATA_PRESET}
TimeoutStartSec=infinity
TimeoutStopSec=300
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable -q strata
# The first start downloads the engine and the model (about 58 GB for the Coder)
# in the background.
systemctl start --no-block strata
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
