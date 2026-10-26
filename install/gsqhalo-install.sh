#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Aristo94/GSQHalo.cpp

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  git \
  libssl-dev \
  ninja-build
msg_ok "Installed Dependencies"

# GSQHalo.cpp is built and measured with AMD's ROCm 7.14 for gfx1151. Debian
# doesn't ship it, so the container gets TheRock's gfx1151 tarball in a prefix
# of its own, the one Strata's manual Strix Halo build also pins.
ROCM_VERSION="7.14.1"
ROCM_SHA256="c40e8f2bd6630a7d11557c762b99c6fa8afb04c9bd0e51ed1675ee1ca24afb00"
ROCM_DIR="/opt/rocm-${ROCM_VERSION}"
msg_info "Installing ROCm ${ROCM_VERSION} for gfx1151 (about 1.7 GB)"
ROCM_TARBALL=$(mktemp)
curl -fsSL --proto '=https' --tlsv1.2 --retry 5 --connect-timeout 30 --speed-limit 1024 --speed-time 300 \
  "https://repo.amd.com/rocm/tarball-multi-arch/therock-dist-linux-gfx1151-${ROCM_VERSION}.tar.gz" -o "$ROCM_TARBALL"
echo "${ROCM_SHA256}  ${ROCM_TARBALL}" | sha256sum -c --quiet - || {
  msg_error "The ROCm tarball does not match its SHA-256"
  exit 1
}
mkdir -p "$ROCM_DIR" /opt/gsqhalo/models /opt/gsqhalo/cache
tar -xzf "$ROCM_TARBALL" -C "$ROCM_DIR"
rm -f "$ROCM_TARBALL"
cat <<EOF2 >/opt/gsqhalo/rocm.env
ROCM_PATH=${ROCM_DIR}
HIP_PATH=${ROCM_DIR}
HIP_PLATFORM=amd
LD_LIBRARY_PATH=${ROCM_DIR}/lib:${ROCM_DIR}/lib/rocm_sysdeps/lib:${ROCM_DIR}/lib/llvm/lib
ROCBLAS_USE_HIPBLASLT=1
EOF2
msg_ok "Installed ROCm ${ROCM_VERSION} for gfx1151"


cat <<'EOF2' >/usr/local/bin/gsqhalo-build
#!/usr/bin/env bash
# Builds the head of GSQHalo.cpp's gsqhalo branch for gfx1151.
set -euo pipefail
set -a
source /opt/gsqhalo/rocm.env
set +a
SDK="$ROCM_PATH"
SRC=/opt/gsqhalo/src
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" fetch --depth 1 origin gsqhalo
  git -C "$SRC" checkout -q --force FETCH_HEAD
else
  git clone --depth 1 --branch gsqhalo https://github.com/Aristo94/GSQHalo.cpp.git "$SRC"
fi
export PATH="$SDK/bin:$SDK/lib/llvm/bin:$PATH"
cmake -S "$SRC" -B /opt/gsqhalo/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON -DGPU_TARGETS=gfx1151 \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DCMAKE_HIP_COMPILER="$SDK/lib/llvm/bin/clang++" -DCMAKE_HIP_COMPILER_ROCM_ROOT="$SDK" \
  "-DCMAKE_PREFIX_PATH=$SDK;$SDK/lib/rocm_sysdeps;$SDK/lib/llvm" \
  "-DCMAKE_HIP_FLAGS=--rocm-path=$SDK --rocm-device-lib-path=$SDK/lib/llvm/amdgcn/bitcode"
cmake --build /opt/gsqhalo/build --target llama-server llama-cli llama-bench -j "$(nproc)"
ln -sf /opt/gsqhalo/build/bin/llama-server /usr/local/bin/llama-server
ln -sf /opt/gsqhalo/build/bin/llama-cli /usr/local/bin/llama-cli
ln -sf /opt/gsqhalo/build/bin/llama-bench /usr/local/bin/llama-bench
git -C "$SRC" rev-parse HEAD >"${HOME:-/root}/.gsqhalo"
EOF2
chmod +x /usr/local/bin/gsqhalo-build

msg_info "Building GSQHalo.cpp (about 20 minutes)"
$STD /usr/local/bin/gsqhalo-build
msg_ok "Built GSQHalo.cpp $(cut -c1-12 "$HOME/.gsqhalo")"

# The ROCm libraries for llama-cli and llama-bench in a login shell.
cat <<'EOF2' >/etc/profile.d/gsqhalo.sh
set -a
. /opt/gsqhalo/rocm.env
set +a
EOF2

msg_info "Configuring GSQHalo"
cat <<'EOF2' >/opt/gsqhalo/gsqhalo.env
# GSQHalo server settings. Apply changes with: systemctl restart gsqhalo
# Options are listed by: llama-server --help
# Server configs from the fork: https://github.com/Aristo94/GSQHalo.cpp/blob/gsqhalo/docs/gsqhalo/README.md

# Model files, space separated. Missing files are downloaded on start; the
# service loads the first one (llama.cpp finds the other shards next to it).
# Default: ISTA-DASLab's Qwen3.8-Flash-Next GSQ-RCO Coder IQ1_M (about 58 GB).
# For the full model, use the IQ3_XXS or IQ3_S shards of
# https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF
GSQHALO_MODEL_URLS=https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF/resolve/04d8b36b50cc0479fda9214a378336f89b356d67/IQ1_M/Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00001-of-00002.gguf https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF/resolve/04d8b36b50cc0479fda9214a378336f89b356d67/IQ1_M/Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00002-of-00002.gguf

# MTP draft head from Unsloth (the self-contained Q8_0, about 4 GB). Leave it
# empty and drop the --spec-* flags from GSQHALO_ARGS to run without MTP.
GSQHALO_MTP_URL=https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/38bb39ee97821de2c9009abb7e93950eec396e66/MTP/mtp-Qwen3.8-Flash-Next-Q8_0.gguf

GSQHALO_HOST=0.0.0.0
GSQHALO_PORT=8080
# The fork's one-slot MTP config, at 128K context. Add --api-key SECRET to
# require a key.
GSQHALO_ARGS=--spec-type draft-mtp --spec-draft-n-max 3 --spec-draft-p-min 0.3 -c 131072 -ngl 999 -fa on -lm dio -lzm on-direct -t 4 -b 8192 -ub 8192 --cache-ram 2048 -ctxcp 8 --jinja --reasoning on --reasoning-effort xhigh
EOF2

cat <<'EOF2' >/usr/local/bin/gsqhalo-model-fetch
#!/usr/bin/env bash
# Downloads every file in GSQHALO_MODEL_URLS and GSQHALO_MTP_URL that is missing.
set -euo pipefail
cd /opt/gsqhalo/models
for url in $GSQHALO_MODEL_URLS ${GSQHALO_MTP_URL:-}; do
  file=$(basename "$url")
  # ${file}.url records where the file (or its partial download) came from.
  if [[ "$(cat "${file}.url" 2>/dev/null)" != "$url" ]]; then
    rm -f "$file" "${file}.part"
    echo "$url" >"${file}.url"
  fi
  [[ -e "$file" ]] && continue
  echo "Downloading ${url}"
  # A stalled transfer fails after 5 minutes; the service then retries and resumes.
  curl -fL --proto '=https' --tlsv1.2 --retry 5 --connect-timeout 30 --speed-limit 1024 --speed-time 300 \
    -C - -o "${file}.part" "$url"
  mv "${file}.part" "$file"
done
EOF2
chmod +x /usr/local/bin/gsqhalo-model-fetch

cat <<'EOF2' >/usr/local/bin/gsqhalo-serve
#!/usr/bin/env bash
# Starts llama-server on the first model file, with the MTP head when one is set.
set -euo pipefail
read -r first _ <<<"$GSQHALO_MODEL_URLS"
args=(-m "/opt/gsqhalo/models/$(basename "$first")")
[[ -n "${GSQHALO_MTP_URL:-}" ]] && args+=(-md "/opt/gsqhalo/models/$(basename "$GSQHALO_MTP_URL")")
# shellcheck disable=SC2086
exec /opt/gsqhalo/build/bin/llama-server "${args[@]}" --host "$GSQHALO_HOST" --port "$GSQHALO_PORT" $GSQHALO_ARGS
EOF2
chmod +x /usr/local/bin/gsqhalo-serve
msg_ok "Configured GSQHalo"

msg_info "Creating Service"
cat <<'EOF2' >/etc/systemd/system/gsqhalo.service
[Unit]
Description=GSQHalo.cpp inference server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/opt/gsqhalo/rocm.env
EnvironmentFile=/opt/gsqhalo/gsqhalo.env
ExecStartPre=/usr/local/bin/gsqhalo-model-fetch
ExecStart=/usr/local/bin/gsqhalo-serve
TimeoutStartSec=infinity
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF2
systemctl enable -q gsqhalo
# The first start downloads the default model and MTP head (about 62 GB) in the background.
systemctl start --no-block gsqhalo
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
