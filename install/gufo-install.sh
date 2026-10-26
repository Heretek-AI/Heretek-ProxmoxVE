#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/gufo-org/gufo

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
  xz-utils
msg_ok "Installed Dependencies"

# Gufo publishes no Linux binaries: its release build is the Nix flake output,
# with ROCm and the patched ROCr prebuilt on gufo.cachix.org.
confirm_external_installer "https://nixos.org/" "https://nixos.org/nix/install"

msg_info "Installing Nix"
NIX_INSTALLER=$(mktemp)
curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 300 https://nixos.org/nix/install -o "$NIX_INSTALLER"
$STD sh "$NIX_INSTALLER" --daemon --yes
rm -f "$NIX_INSTALLER"
cat <<EOF >>/etc/nix/nix.conf
experimental-features = nix-command flakes
sandbox = false
extra-substituters = https://gufo.cachix.org
extra-trusted-public-keys = gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE=
EOF
systemctl restart nix-daemon
msg_ok "Installed Nix"

mkdir -p /opt/gufo/models

cat <<'EOF' >/usr/local/bin/gufo-build
#!/usr/bin/env bash
# Builds a Gufo release tag and points /opt/gufo/result at it.
set -euo pipefail
tag="${1:?usage: gufo-build <tag>}"
export PATH="/nix/var/nix/profiles/default/bin:${PATH}"
nix build --print-build-logs "github:gufo-org/gufo/${tag}#release" --out-link /opt/gufo/result
ln -sf /opt/gufo/result/bin/gufo /usr/local/bin/gufo
echo "${tag#v}" >"${HOME:-/root}/.gufo"
EOF
chmod +x /usr/local/bin/gufo-build

RELEASE=$(curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 30 --max-time 60 https://api.github.com/repos/gufo-org/gufo/releases/latest | jq -r '.tag_name')
[[ -n "$RELEASE" && "$RELEASE" != "null" ]] || {
  msg_error "Could not read the latest Gufo release"
  exit 1
}
msg_info "Building Gufo ${RELEASE} (can take a while if not cached)"
$STD /usr/local/bin/gufo-build "$RELEASE"
msg_ok "Built Gufo ${RELEASE}"

msg_info "Configuring Gufo"
GUFO_API_KEY=$(random_password 32)
cat <<EOF >/opt/gufo/gufo.env
# Gufo server settings. Apply changes with: systemctl restart gufo
# Options are listed by: gufo serve --help and gufo serve llm --help

# Model file. If it is missing and GUFO_MODEL_URL is set, the service
# downloads it before starting.
GUFO_MODEL=/opt/gufo/models/Qwen3.8-27B-UD-Q4_K_XL.gguf
GUFO_MODEL_URL=https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf

# llm, image, video, tts, asr or embedding
GUFO_MODALITY=llm

GUFO_HOST=0.0.0.0
GUFO_PORT=8080
# Server options before the modality, for example: --sessions 2
# Clients send the API key as: Authorization: Bearer <key>
GUFO_SERVER_ARGS=--api-key ${GUFO_API_KEY}
# Model options after the modality, for example:
# --speculative dflash2 --dflash-model /opt/gufo/models/Qwen3.8-27B-DFlash2-Q4_K_M.gguf
GUFO_ARGS=--context 32768
EOF
chmod 600 /opt/gufo/gufo.env
{
  echo "Gufo API key: ${GUFO_API_KEY}"
  echo "Set in GUFO_SERVER_ARGS in /opt/gufo/gufo.env"
} >~/gufo.creds

cat <<'EOF' >/usr/local/bin/gufo-model-fetch
#!/usr/bin/env bash
# Downloads GUFO_MODEL from GUFO_MODEL_URL when the file is missing.
set -euo pipefail
[[ -e "$GUFO_MODEL" || -z "${GUFO_MODEL_URL:-}" ]] && exit 0
mkdir -p "$(dirname "$GUFO_MODEL")"
# A partial download from another URL can't be resumed.
if [[ "$(cat "${GUFO_MODEL}.url" 2>/dev/null)" != "$GUFO_MODEL_URL" ]]; then
  rm -f "${GUFO_MODEL}.part"
  echo "$GUFO_MODEL_URL" >"${GUFO_MODEL}.url"
fi
echo "Downloading ${GUFO_MODEL_URL} to ${GUFO_MODEL}"
# A stalled transfer fails after 5 minutes; the service then retries and resumes.
curl -fL --proto '=https' --tlsv1.2 --retry 5 --connect-timeout 30 --speed-limit 1024 --speed-time 300 \
  -C - -o "${GUFO_MODEL}.part" "$GUFO_MODEL_URL"
mv "${GUFO_MODEL}.part" "$GUFO_MODEL"
rm -f "${GUFO_MODEL}.url"
EOF
chmod +x /usr/local/bin/gufo-model-fetch
msg_ok "Configured Gufo"

msg_info "Creating Service"
cat <<'EOF' >/etc/systemd/system/gufo.service
[Unit]
Description=Gufo inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/opt/gufo/gufo.env
ExecStartPre=/usr/local/bin/gufo-model-fetch
ExecStart=/usr/local/bin/gufo serve --host ${GUFO_HOST} --port ${GUFO_PORT} $GUFO_SERVER_ARGS $GUFO_MODALITY --model ${GUFO_MODEL} $GUFO_ARGS
TimeoutStartSec=infinity
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q gufo
# The first start downloads the default model (about 17 GB) in the background.
systemctl start --no-block gufo
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
