#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Yamz-Labs/kyojin

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# The package set of Kyojin's own Dockerfile (Ubuntu 24.04, Python 3.12). The
# compilers stay: the servers build a few HIP and Triton kernels at start.
msg_info "Installing Dependencies"
$STD apt install -y \
  ca-certificates \
  curl \
  g++ \
  gcc \
  git \
  libatomic1 \
  libc6-dev \
  libdrm-amdgpu1 \
  libdrm2 \
  libelf1 \
  libgomp1 \
  libnuma1 \
  make \
  python3 \
  python3-dev \
  python3-venv
msg_ok "Installed Dependencies"

mkdir -p /opt/kyojin/models
cat <<'EOF2' >/usr/local/bin/kyojin-build
#!/usr/bin/env bash
# Builds a Kyojin tag (default: the newest vX.Y.Z) into /opt/kyojin/releases
# and points the /opt/kyojin/app symlink at it.
# `kyojin-build --latest` only prints the newest tag.
# Follows Kyojin's docker/Dockerfile: ROCm torch and rocm-sdk-devel from AMD's
# gfx1151 nightly index at the versions that Dockerfile pins, requirements.txt,
# `rocm-sdk init`, then build.sh. No system ROCm is needed.
set -euo pipefail
REPO=https://github.com/Yamz-Labs/kyojin.git
BASE=/opt/kyojin
VENV=$BASE/venv

latest() {
  git ls-remote --tags --refs "$REPO" 'v*' | awk -F/ '{print $3}' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1
}
if [[ "${1:-}" == "--latest" ]]; then
  latest
  exit
fi
TAG=${1:-$(latest)}
[[ -n "$TAG" ]] || { echo "Could not read the Kyojin tags" >&2; exit 1; }

exec 9>"$BASE/.build.lock"
flock -n 9 || { echo "Another kyojin-build is running" >&2; exit 1; }

mkdir -p "$BASE/releases"
NEW="$BASE/releases/${TAG}-$(date +%Y%m%d%H%M%S)"
git -c advice.detachedHead=false clone --depth 1 --branch "$TAG" "$REPO" "$NEW"

pin() { sed -n "s/^ARG $1=//p" "$NEW/docker/Dockerfile" | head -n1; }
TORCH=$(pin TORCH_VERSION)
SDK=$(pin ROCM_SDK_VERSION)
INDEX=$(pin ROCM_INDEX_URL)
[[ -n "$TORCH" && -n "$SDK" && -n "$INDEX" ]] || { echo "No torch or ROCm SDK pins in docker/Dockerfile of ${TAG}" >&2; exit 1; }

[[ -x "$VENV/bin/python" ]] || python3 -m venv "$VENV"
if [[ "$(cat "$VENV/.kyojin-pins" 2>/dev/null)" != "$TORCH $SDK" ]]; then
  "$VENV/bin/pip" install --no-cache-dir --pre "torch==${TORCH}" "rocm-sdk-devel==${SDK}" --index-url "$INDEX"
  "$VENV/bin/rocm-sdk" init
  # The same prune as the Dockerfile: test binaries, profiler data, client samples.
  (cd "$("$VENV/bin/rocm-sdk" path --root)" &&
    rm -rf clients share/rocprofiler-sdk share/hipblaslt share/rocdecode share/rocsparse \
      bin/*gtest* bin/*-test bin/*-bench bin/*-gemm-tune bin/*test*)
  echo "$TORCH $SDK" >"$VENV/.kyojin-pins"
fi
"$VENV/bin/pip" install --no-cache-dir -r "$NEW/requirements.txt"

SDK_ROOT=$("$VENV/bin/rocm-sdk" path --root)
cat <<EOF3 >"$BASE/runtime.env"
# Written by kyojin-build. Settings you can change are in /opt/kyojin/kyojin.env.
KYOJIN_ROOT=${BASE}/app
EXL3_VENV=${VENV}
EXL3_ROCM_SDK=${SDK_ROOT}
EXL3_HIPCC=${SDK_ROOT}/bin/hipcc
EXL3_HSA_LIB=${SDK_ROOT}/lib/libhsa-runtime64.so.1
PATH=${VENV}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/root
PYTHONUNBUFFERED=1
EOF3

set -a
# shellcheck disable=SC1091
source "$BASE/runtime.env"
set +a
"$NEW/build.sh"
(
  cd "$NEW"
  # shellcheck disable=SC1091
  source tools/strix_halo/env.sh >/dev/null
  python -c "import torch, exllamav3_ext"
)
rm -rf "$NEW/build" "$NEW"/.rebuild.* "$NEW/.sdk-deps"

# Swap the symlink atomically. The previous release stays until the next
# build, because the running server keeps reading it until it restarts.
PREV=$(readlink -f "$BASE/app" 2>/dev/null || true)
ln -sfn "$NEW" "$BASE/app.tmp"
mv -Tf "$BASE/app.tmp" "$BASE/app"
for dir in "$BASE"/releases/*; do
  [[ "$dir" == "$NEW" || "$dir" == "$PREV" ]] || rm -rf "$dir"
done
echo "$TAG" >"${HOME:-/root}/.kyojin"
EOF2
chmod +x /usr/local/bin/kyojin-build

msg_info "Building Kyojin (about 14 GB of ROCm wheels, then about 10 minutes)"
$STD /usr/local/bin/kyojin-build
msg_ok "Built Kyojin $(cat "$HOME/.kyojin")"

msg_info "Configuring Kyojin"
cat <<'EOF2' >/opt/kyojin/kyojin.env
# Kyojin server settings, read by Kyojin's docker/entrypoint.sh.
# Apply changes with: systemctl restart kyojin
# Every setting: https://github.com/Yamz-Labs/kyojin/blob/main/doc/container.md

# Model: qwen (Qwen3.8-Flash-Next, 95 GB), glm (GLM-5.3-Flash, 100 GB) or
# mimo (MiMo-V2.6-Flash, 106 GB). A missing pack is downloaded from Hugging
# Face into MODEL_DIR on start; the download resumes after a restart.
KYOJIN_MODEL=qwen
MODEL_DIR=/opt/kyojin/models
# Another repository of the same family, e.g. the uncensored GLM pack:
# KYOJIN_HF_REPO=yamz-labs/GLM-5.3-Flash-EXL3-Yamz-Uncensored
# HF_TOKEN=

PORT=8731
# 131072 leaves about 14 GiB (Qwen) or 10 GiB (GLM) free on a 128 GB machine.
CONTEXT=131072
# Extra server flags, appended last. Quote values with spaces, e.g.
# KYOJIN_EXTRA_ARGS="--default-reasoning-effort medium"
KYOJIN_EXTRA_ARGS=
EOF2

# Runs Kyojin's own GPU check (versions and a small matmul). The GPU must be
# free, so stop the service first.
cat <<'EOF2' >/usr/local/bin/kyojin-check
#!/usr/bin/env bash
set -a
source /opt/kyojin/runtime.env
source /opt/kyojin/kyojin.env
set +a
exec /opt/kyojin/app/docker/entrypoint.sh check
EOF2
chmod +x /usr/local/bin/kyojin-check
msg_ok "Configured Kyojin"

msg_info "Creating Service"
cat <<'EOF2' >/etc/systemd/system/kyojin.service
[Unit]
Description=Kyojin inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/opt/kyojin/runtime.env
EnvironmentFile=/opt/kyojin/kyojin.env
ExecStart=/opt/kyojin/app/docker/entrypoint.sh
KillMode=mixed
TimeoutStopSec=60
Restart=on-failure
RestartSec=30
LimitNOFILE=65535
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable -q kyojin
# The first start downloads the Qwen pack (about 95 GB) in the background.
systemctl start --no-block kyojin
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
