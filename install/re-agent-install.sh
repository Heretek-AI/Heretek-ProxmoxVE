#!/usr/bin/env bash

# Author: BillyOutlast
# License: MIT | https://github.com/Heretek-AI/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/morluto/rea | https://github.com/openbin-ai/binny | https://hermes-agent.nousresearch.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
  msg_error "RE-Agent supports amd64 only (Detect It Easy and the BINNY build used here are x86_64)"
  exit 1
fi

msg_info "Installing Dependencies"
$STD apt install -y \
  git \
  jq \
  file \
  unzip \
  p7zip-full \
  build-essential \
  python3 \
  python3-venv \
  python3-dev \
  iptables \
  squid \
  bubblewrap \
  radare2 \
  upx-ucl \
  yara \
  tshark \
  tcpdump
msg_ok "Installed Dependencies"

JAVA_VERSION="21" setup_java
NODE_VERSION="22" NODE_MODULE="rea-agents" setup_nodejs

fetch_and_deploy_gh_release "ghidra" "NationalSecurityAgency/ghidra" "prebuild" "latest" "/opt/ghidra" "ghidra_*_PUBLIC_*.zip"
chmod +x /opt/ghidra/support/analyzeHeadless /opt/ghidra/ghidraRun
fetch_and_deploy_gh_release "binny" "openbin-ai/binny-releases" "prebuild" "latest" "/opt/binny" "binny-linux-amd64.tar.gz"
ln -sf /opt/binny/binny /usr/local/bin/binny

if fetch_and_deploy_gh_release "die" "horsicq/DIE-engine" "prebuild" "latest" "/opt/die" "die_lin64_portable_*.tar.gz"; then
  DIEC_BIN=$(find /opt/die -maxdepth 2 -type f -name 'diec*' | head -n1)
  [[ -n "$DIEC_BIN" ]] && ln -sf "$DIEC_BIN" /usr/local/bin/diec
else
  msg_warn "Detect It Easy could not be installed; the rest of the toolchain is unaffected"
fi

msg_info "Installing Python triage tools"
python3 -m venv /opt/re-tools-venv
$STD /opt/re-tools-venv/bin/pip install --upgrade pip wheel
$STD /opt/re-tools-venv/bin/pip install flare-capa flare-floss yara-python pefile pyelftools r2pipe
ln -sf /opt/re-tools-venv/bin/capa /usr/local/bin/capa
ln -sf /opt/re-tools-venv/bin/floss /usr/local/bin/floss
msg_ok "Installed Python triage tools"

msg_info "Creating analyst user"
useradd -m -s /bin/bash analyst
# The linger file is what loginctl enable-linger writes; written directly it
# also works in the VM build, where logind isn't running.
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/analyst
echo 'export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"' >>/home/analyst/.profile
mkdir -p /work/samples /work/cases
chown -R analyst:analyst /work
cat <<'EOF' >/etc/default/re-agent
HOME=/home/analyst
PATH=/home/analyst/.local/bin:/opt/ghidra/support:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
GHIDRA_INSTALL_DIR=/opt/ghidra
GHIDRA_HEADLESS_MAXMEM=4G
EOF
cat <<'EOF' >/etc/profile.d/re-agent.sh
export GHIDRA_INSTALL_DIR=/opt/ghidra
export GHIDRA_HEADLESS_MAXMEM=4G
export PATH="$PATH:/opt/ghidra/support"
EOF
touch /etc/default/re-agent-proxy
msg_ok "Created analyst user"

# The VM script asks this on the host: the VM build has no terminal to ask on.
if [[ "${DEPLOY_TARGET:-}" != "vm" ]]; then
  confirm_external_installer "https://hermes-agent.nousresearch.com/" "https://hermes-agent.nousresearch.com/install.sh"
fi

msg_info "Installing Hermes Agent"
curl_with_retry "https://hermes-agent.nousresearch.com/install.sh" /tmp/hermes-install.sh ||
  curl_with_retry "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh" /tmp/hermes-install.sh
$STD setsid --wait bash -c '
  set -a; source /etc/default/re-agent; set +a
  export npm_config_yes=true
  bash /tmp/hermes-install.sh --skip-setup --hermes-home /home/analyst/.hermes --dir /home/analyst/.hermes/hermes-agent
'
rm -f /tmp/hermes-install.sh
API_SERVER_KEY=$(random_password 32)
cat <<EOF >/home/analyst/.hermes/.env
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=${API_SERVER_KEY}
EOF
chown -R analyst:analyst /home/analyst
chmod 750 /home/analyst
chmod 700 /home/analyst/.hermes
chmod 600 /home/analyst/.hermes/.env
git config --system --add safe.directory /home/analyst/.hermes/hermes-agent
msg_ok "Installed Hermes Agent"

msg_info "Installing Hermes plugins"
# Catalog plugins install at the commit SHA Nous reviewed. rea registers REA's
# MCP server and skill; bubblewrap sandboxes every command the agent runs;
# holographic is a local SQLite memory whose search by meaning can be pointed at
# an embeddings API later (re-agent-config embeddings).
for plugin in rea bubblewrap holographic; do
  if ! su - analyst -c "set -a; source /etc/default/re-agent; set +a; hermes plugins install ${plugin} --enable --yes-deps" >>/var/log/re-agent-plugins.log 2>&1; then
    msg_warn "Hermes plugin '${plugin}' did not install (see /var/log/re-agent-plugins.log)"
  fi
done
su - analyst -c 'set -a; source /etc/default/re-agent; set +a; hermes config set memory.provider holographic' >>/var/log/re-agent-plugins.log 2>&1 || true
# bwrap needs user namespaces, which an unprivileged LXC usually can't nest.
if [[ "${DEPLOY_TARGET:-}" == "vm" ]]; then
  su - analyst -c 'set -a; source /etc/default/re-agent; set +a; hermes config set terminal.backend bubblewrap' >>/var/log/re-agent-plugins.log 2>&1 || true
fi
# The rea plugin starts its pinned rea-agents through npx. Fetch it now, while
# the npm registry is reachable: under quarantine it is not.
REA_SPEC=$(grep -rhoE 'rea-agents@[0-9][0-9.]*' /home/analyst/.hermes/plugins/rea 2>/dev/null | head -n1 || true)
if [[ -n "$REA_SPEC" ]]; then
  su - analyst -c "npx -y ${REA_SPEC} --version" >>/var/log/re-agent-plugins.log 2>&1 || true
fi
chown -R analyst:analyst /home/analyst
msg_ok "Installed Hermes plugins"

msg_info "Creating Hermes dashboard service"
cat <<EOF >/etc/systemd/system/hermes-dashboard.service
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=analyst
Group=analyst
UMask=0077
WorkingDirectory=/home/analyst
ExecStart=/home/analyst/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open
EnvironmentFile=/etc/default/re-agent
EnvironmentFile=-/etc/default/re-agent-proxy
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hermes-dashboard
msg_ok "Created Hermes dashboard service"

msg_info "Creating setup helper"
cat <<'EOF' >/usr/local/bin/re-agent-setup
#!/usr/bin/env bash
# Configures the model provider, then starts the gateway API on port 8642.
set -e
su - analyst -c 'set -a; source /etc/default/re-agent; [ -s /etc/default/re-agent-proxy ] && source /etc/default/re-agent-proxy; set +a; hermes setup'
chown -R analyst:analyst /home/analyst
chmod 700 /home/analyst/.hermes
if [[ -f /home/analyst/.config/systemd/user/hermes-gateway.service ]]; then
  su - analyst -c 'systemctl --user enable --now hermes-gateway'
  echo "Gateway API: port 8642, key in /home/analyst/.hermes/.env"
else
  echo "No gateway service was installed. Run re-agent-setup again and choose 'user service' for the gateway."
fi
echo "To add an OpenAI-compatible provider or a memory embeddings API (and let it through the quarantine):"
echo "  re-agent-config provider add <name> <base_url> [default_model]"
echo "  re-agent-config embeddings <base_url> <model>"
EOF
chmod 755 /usr/local/bin/re-agent-setup
msg_ok "Created setup helper"

msg_info "Deploying case tools"
cat <<'EOF' >/usr/local/bin/re-casebook
#!/usr/bin/env python3
"""Evidence ledger for RE-Agent cases: a claim is accepted only when every
evidence id it cites has been recorded in the case's casebook.json."""
import json
import os
import sys
import time


def _path(case_dir):
    return os.path.join(case_dir, "casebook.json")


def _load(case_dir):
    path = _path(case_dir)
    if not os.path.exists(path):
        sys.exit(f"[ERROR] Casebook not found at {path}")
    with open(path) as f:
        return json.load(f)


def _save(case_dir, data):
    with open(_path(case_dir), "w") as f:
        json.dump(data, f, indent=2)


def init(case_dir, sample):
    os.makedirs(case_dir, exist_ok=True)
    if not os.path.exists(_path(case_dir)):
        _save(case_dir, {"sample": os.path.abspath(sample), "created_at": time.time(), "evidence": {}, "verified_claims": []})
    print(f"[CASEBOOK] Initialized {_path(case_dir)}")


def record(case_dir, evidence_id, category, content, offset=None):
    data = _load(case_dir)
    data["evidence"][evidence_id] = {"category": category, "content": content, "offset": offset, "timestamp": time.time()}
    _save(case_dir, data)
    print(f"[CASEBOOK] Recorded evidence: {evidence_id}")


def verify(case_dir, claim, evidence_ids):
    data = _load(case_dir)
    missing = [e for e in evidence_ids if e not in data["evidence"]]
    if missing:
        print(f"[REJECTED] Missing evidence ids: {missing}", file=sys.stderr)
        return False
    data["verified_claims"].append({"claim": claim, "evidence_ids": evidence_ids, "timestamp": time.time()})
    _save(case_dir, data)
    print(f"[ACCEPTED] Claim verified with {len(evidence_ids)} citations.")
    return True


USAGE = "Usage: re-casebook init <case_dir> <sample> | record <case_dir> <id> <category> <content> [offset] | verify <case_dir> <claim> <id,id,...>"

if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) >= 3 and args[0] == "init":
        init(args[1], args[2])
    elif len(args) >= 5 and args[0] == "record":
        record(args[1], args[2], args[3], args[4], args[5] if len(args) > 5 else None)
    elif len(args) >= 4 and args[0] == "verify":
        sys.exit(0 if verify(args[1], args[2], args[3].split(",")) else 1)
    else:
        sys.exit(USAGE)
EOF
chmod 755 /usr/local/bin/re-casebook

cat <<'REACASE' >/usr/local/bin/rea-case
#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-help}"
SAMPLE="${2:-}"
CASE_DIR="/work/cases/$(basename "${SAMPLE:-none}")"

usage() {
  echo "Usage: rea-case <command> [sample]"
  echo "  new <file>       Create a case directory and run hashes, CAPA and FLOSS"
  echo "  status <sample>  Show the case metadata and verified claims"
  echo "  export <sample>  Write FINAL_REPORT.md from the investigation plan"
  echo "  clean            Remove leftover lock files under /work/cases"
  exit 1
}

need_case() {
  [[ -d "$CASE_DIR" ]] || {
    echo "Error: case directory not found: $CASE_DIR"
    exit 1
  }
}

case "$COMMAND" in
new)
  [[ -n "$SAMPLE" && -f "$SAMPLE" ]] || {
    echo "Error: sample not found: $SAMPLE"
    exit 1
  }
  mkdir -p "$CASE_DIR"
  echo "==> [1/4] Hashing"
  SHA256=$(sha256sum "$SAMPLE" | awk '{print $1}')
  FILE_TYPE=$(file -b "$SAMPLE")
  jq -n \
    --arg name "$(basename "$SAMPLE")" \
    --arg path "$(realpath "$SAMPLE")" \
    --arg type "$FILE_TYPE" \
    --arg md5 "$(md5sum "$SAMPLE" | awk '{print $1}')" \
    --arg sha256 "$SHA256" \
    --argjson size "$(stat -c%s "$SAMPLE")" \
    --argjson created "$(date +%s)" \
    '{sample_name: $name, file_path: $path, file_size_bytes: $size, file_type: $type, md5: $md5, sha256: $sha256, created_at: $created}' \
    >"$CASE_DIR/metadata.json"
  echo "==> [2/4] Initializing casebook"
  re-casebook init "$CASE_DIR" "$SAMPLE"
  echo "==> [3/4] CAPA and FLOSS"
  capa -q "$SAMPLE" >"$CASE_DIR/capa_triage.txt" 2>&1 || echo "    capa reported an error, see capa_triage.txt"
  floss --quiet "$SAMPLE" >"$CASE_DIR/floss_strings.txt" 2>&1 || echo "    floss reported an error, see floss_strings.txt"
  echo "==> [4/4] Writing investigation plan"
  cat <<EOF >"$CASE_DIR/investigation_plan.md"
# Investigation Plan: $(basename "$SAMPLE")

- **Type**: $FILE_TYPE
- **SHA256**: \`$SHA256\`
- Capabilities: \`capa_triage.txt\`
- Strings: \`floss_strings.txt\`

## Hypothesis Queue
- [ ] Entry point and imports
- [ ] Decryptors, unpacking loops and strings
- [ ] C2 communication and protocol framing
- [ ] Persistence and privilege escalation

## Verified Findings
Every finding must cite an evidence id recorded in casebook.json.
EOF
  echo "==> Case ready: $CASE_DIR"
  ;;
status)
  need_case
  jq . "$CASE_DIR/metadata.json"
  echo "Verified claims:"
  jq '.verified_claims' "$CASE_DIR/casebook.json"
  ;;
export)
  need_case
  {
    echo "# Technical Report: $(basename "$SAMPLE")"
    echo "Generated: $(date)"
    echo
    cat "$CASE_DIR/investigation_plan.md"
    echo
    echo "## Verified Claims"
    jq -r '.verified_claims[] | "- \(.claim) (evidence: \(.evidence_ids | join(", ")))"' "$CASE_DIR/casebook.json"
  } >"$CASE_DIR/FINAL_REPORT.md"
  echo "Report written to $CASE_DIR/FINAL_REPORT.md"
  ;;
clean)
  find /work/cases -type f \( -name "*.lock" -o -name "*.lock~" \) -delete
  echo "Removed temporary lock files under /work/cases."
  ;;
*)
  usage
  ;;
esac
REACASE
chmod 755 /usr/local/bin/rea-case
msg_ok "Deployed case tools"

msg_info "Deploying egress quarantine"
mkdir -p /etc/re-agent
cat <<'EOF' >/etc/re-agent/egress-allow
# One host per line. Under quarantine these are the only hosts reachable,
# through the proxy. Manage with: re-firewall allow|deny <host-or-url>
api.anthropic.com
api.openai.com
openrouter.ai
generativelanguage.googleapis.com
EOF
systemctl disable -q --now squid

cat <<'FIREWALL' >/usr/local/sbin/re-firewall
#!/usr/bin/env bash
# Egress quarantine for RE-Agent. Root only: the analyst user has no sudo, so
# nothing running as analyst (Hermes, tools, samples) can lift it.
set -euo pipefail

STATE=/etc/re-agent/firewall.conf
ALLOW=/etc/re-agent/egress-allow
PROXY_ENV=/etc/default/re-agent-proxy
HOST_CONF=/opt/re-agent/host-egress-proxy.conf
CHAIN=RE_EGRESS
LOCAL_PORT=3128

usage() {
  cat <<'USAGE'
Usage: re-firewall <command>
  isolate local                Quarantine through a proxy inside this guest (Squid on 127.0.0.1:3128)
  isolate <proxy_ip> [port]    Quarantine through a proxy you run on the host or a gateway
  unmask                       Lift the quarantine
  allow <host-or-url>          Allow a host through the proxy (e.g. https://llm.example.com/v1)
  deny <host>                  Remove a host from the allowlist
  list                         Show the allowlist
  apply                        Re-apply the saved state (run at boot)
  status                       Show the mode and rules
USAGE
  exit 1
}

normalize_host() {
  local h="${1,,}"
  h="${h#*://}"
  h="${h%%/*}"
  h="${h%%:*}"
  [[ "$h" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ && "$h" == *.* ]] || {
    echo "Not a host name: $1" >&2
    exit 1
  }
  echo "$h"
}

allowed_hosts() {
  grep -vE '^\s*(#|$)' "$ALLOW" 2>/dev/null | sort -u
}

write_proxy_confs() {
  local hosts h
  hosts=$(allowed_hosts)
  {
    echo "# Generated by re-firewall from ${ALLOW}. Squid config for the egress proxy on the"
    echo "# Proxmox host or a gateway: HTTPS CONNECT to the allowed hosts only."
    echo "http_port 8080"
    for h in $hosts; do echo "acl re_agent_allowed dstdomain ${h}"; done
    echo "acl SSL_ports port 443"
    echo "http_access deny !SSL_ports"
    echo "http_access deny CONNECT !SSL_ports"
    echo "http_access allow CONNECT re_agent_allowed"
    echo "http_access deny all"
  } >"$HOST_CONF"
  {
    echo "# Generated by re-firewall. Local egress proxy for RE-Agent quarantine."
    echo "http_port 127.0.0.1:${LOCAL_PORT}"
    for h in $hosts; do echo "acl re_agent_allowed dstdomain ${h}"; done
    echo "acl SSL_ports port 443"
    echo "http_access deny !SSL_ports"
    echo "http_access deny CONNECT !SSL_ports"
    echo "http_access allow localhost CONNECT re_agent_allowed"
    echo "http_access deny all"
    echo "cache deny all"
    echo "access_log stdio:/var/log/squid/access.log"
    echo "coredump_dir /var/spool/squid"
  } >/etc/squid/squid.conf
}

flush_chain() {
  local ipt="$1"
  command -v "$ipt" >/dev/null 2>&1 || return 0
  "$ipt" -D OUTPUT -j "$CHAIN" 2>/dev/null || true
  "$ipt" -F "$CHAIN" 2>/dev/null || true
  "$ipt" -X "$CHAIN" 2>/dev/null || true
}

apply_rules() {
  local proxy="$1" port="$2" uid
  uid=$(id -u analyst)
  flush_chain iptables
  flush_chain ip6tables

  iptables -N "$CHAIN"
  iptables -A "$CHAIN" -o lo -j ACCEPT
  iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A "$CHAIN" -p udp --sport 68 --dport 67 -j ACCEPT
  if [[ "$proxy" == "local" ]]; then
    # Only Squid itself goes out, and it enforces the allowlist.
    iptables -A "$CHAIN" -m owner --uid-owner proxy -p udp --dport 53 -j ACCEPT
    iptables -A "$CHAIN" -m owner --uid-owner proxy -p tcp --dport 53 -j ACCEPT
    iptables -A "$CHAIN" -m owner --uid-owner proxy -p tcp --dport 443 -j ACCEPT
    # Squid may resolve through systemd-resolved's stub, which then needs out too.
    if id systemd-resolve >/dev/null 2>&1; then
      iptables -A "$CHAIN" -m owner --uid-owner systemd-resolve -p udp --dport 53 -j ACCEPT
      iptables -A "$CHAIN" -m owner --uid-owner systemd-resolve -p tcp --dport 53 -j ACCEPT
    fi
  else
    iptables -A "$CHAIN" -p tcp -m owner --uid-owner "$uid" -d "$proxy" --dport "$port" -j ACCEPT
  fi
  iptables -A "$CHAIN" -j DROP
  iptables -I OUTPUT 1 -j "$CHAIN"

  # IPv6 has no proxy path, so everything but loopback and replies is dropped.
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -N "$CHAIN"
    ip6tables -A "$CHAIN" -o lo -j ACCEPT
    ip6tables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A "$CHAIN" -j DROP
    ip6tables -I OUTPUT 1 -j "$CHAIN"
  else
    echo "Warning: ip6tables not found, IPv6 egress is NOT blocked" >&2
  fi

  local url="http://${proxy}:${port}"
  if [[ "$proxy" == "local" ]]; then
    url="http://127.0.0.1:${LOCAL_PORT}"
    write_proxy_confs
    systemctl enable -q --now squid
    systemctl reload squid 2>/dev/null || systemctl restart squid
  fi
  printf 'HTTPS_PROXY=%s\nHTTP_PROXY=%s\nNO_PROXY=127.0.0.1,localhost\n' "$url" "$url" >"$PROXY_ENV"
}

restart_hermes() {
  systemctl restart hermes-dashboard 2>/dev/null || true
  su - analyst -c 'systemctl --user try-restart hermes-gateway' 2>/dev/null || true
}

mode() {
  local MODE=open PROXY_IP=""
  # shellcheck disable=SC1090
  [[ -f "$STATE" ]] && source "$STATE"
  echo "${MODE}:${PROXY_IP}"
}

[[ $EUID -eq 0 ]] || {
  echo "re-firewall must run as root" >&2
  exit 1
}
mkdir -p "$(dirname "$STATE")"

case "${1:-status}" in
isolate)
  [[ -n "${2:-}" ]] || usage
  port="${3:-8080}"
  [[ "$2" == "local" ]] && port="$LOCAL_PORT"
  printf 'MODE=isolate\nPROXY_IP=%s\nPROXY_PORT=%s\n' "$2" "$port" >"$STATE"
  apply_rules "$2" "$port"
  restart_hermes
  echo "Quarantine active through ${2}:${port}; allowed hosts: $(allowed_hosts | paste -sd' ')."
  echo "It persists across reboots. Lift it with: re-firewall unmask"
  ;;
unmask)
  echo "MODE=open" >"$STATE"
  flush_chain iptables
  flush_chain ip6tables
  systemctl disable -q --now squid 2>/dev/null || true
  : >"$PROXY_ENV"
  restart_hermes
  echo "Quarantine lifted."
  ;;
allow | deny)
  [[ -n "${2:-}" ]] || usage
  host=$(normalize_host "$2")
  if [[ "$1" == "allow" ]]; then
    grep -qxF "$host" "$ALLOW" || echo "$host" >>"$ALLOW"
    echo "Allowed ${host}."
  else
    sed -i "/^${host//./\\.}\$/d" "$ALLOW"
    echo "Removed ${host}."
  fi
  write_proxy_confs
  case "$(mode)" in
  isolate:local) systemctl reload squid ;;
  isolate:*) echo "Copy ${HOST_CONF} to your host proxy and reload it to apply this there." ;;
  esac
  ;;
list)
  allowed_hosts
  ;;
apply)
  [[ -f "$STATE" ]] || exit 0
  # shellcheck disable=SC1090
  source "$STATE"
  if [[ "${MODE:-open}" == "isolate" ]]; then
    apply_rules "$PROXY_IP" "$PROXY_PORT"
  fi
  ;;
status)
  if [[ -f "$STATE" ]]; then cat "$STATE"; else echo "MODE=open"; fi
  echo "Allowed hosts: $(allowed_hosts | paste -sd' ')"
  iptables -L "$CHAIN" -v -n --line-numbers 2>/dev/null || echo "IPv4: no quarantine rules"
  ip6tables -L "$CHAIN" -v -n --line-numbers 2>/dev/null || echo "IPv6: no quarantine rules"
  ;;
*)
  usage
  ;;
esac
FIREWALL
chmod 700 /usr/local/sbin/re-firewall

cat <<'EOF' >/etc/systemd/system/re-firewall.service
[Unit]
Description=RE-Agent egress quarantine
Before=network-pre.target hermes-dashboard.service
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/re-firewall apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q re-firewall

cat <<'CONFIG' >/usr/local/sbin/re-agent-config
#!/usr/bin/env bash
# Adds model providers and the memory embeddings endpoint to Hermes, and lets
# their hosts through the egress quarantine. Keys are read from the terminal,
# never from the command line, and stored in /home/analyst/.hermes/.env.
set -euo pipefail

ENV_FILE=/home/analyst/.hermes/.env

usage() {
  cat <<'USAGE'
Usage: re-agent-config <command>
  provider add <name> <base_url> [default_model]   Add an OpenAI-compatible provider (e.g. heretek https://llm.heretek.one/v1)
  provider list                                     List configured providers
  embeddings <base_url> <model>                     Turn on memory search by meaning through an embeddings API
  embeddings off                                    Turn it off (memory stays local)
USAGE
  exit 1
}

hermes_cfg() {
  runuser -u analyst -- env HOME=/home/analyst PATH=/home/analyst/.local/bin:/usr/local/bin:/usr/bin:/bin \
    /home/analyst/.local/bin/hermes config "$@"
}

store_key() {
  local var="$1" key
  read -rsp "API key for ${2} (leave empty for none): " key
  echo
  [[ -n "$key" ]] || return 1
  touch "$ENV_FILE"
  sed -i "/^${var}=/d" "$ENV_FILE"
  printf '%s=%s\n' "$var" "$key" >>"$ENV_FILE"
  chown analyst:analyst "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

check_url() {
  [[ "$1" =~ ^https://[^/]+ ]] || {
    echo "Use an https:// URL: $1" >&2
    exit 1
  }
}

restart_hermes() {
  systemctl restart hermes-dashboard 2>/dev/null || true
  su - analyst -c 'systemctl --user try-restart hermes-gateway' 2>/dev/null || true
}

[[ $EUID -eq 0 ]] || {
  echo "re-agent-config must run as root" >&2
  exit 1
}

case "${1:-}" in
provider)
  case "${2:-}" in
  add)
    name="${3:-}" url="${4:-}" model="${5:-}"
    [[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ && -n "$url" ]] || usage
    check_url "$url"
    var="RE_PROVIDER_${name^^}_KEY"
    var="${var//-/_}"
    entry=$(jq -cn --arg api "$url" --arg model "$model" '{api: $api} + (if $model == "" then {} else {default_model: $model} end)')
    if store_key "$var" "$name"; then
      entry=$(jq -c --arg k "$var" '. + {key_env: $k}' <<<"$entry")
    fi
    hermes_cfg set "providers.${name}" "$entry"
    re-firewall allow "$url"
    restart_hermes
    echo "Added provider '${name}'. Pick it with /model in Hermes, or: hermes config set model.provider ${name}"
    ;;
  list)
    hermes_cfg get providers 2>/dev/null || grep -A20 '^providers:' /home/analyst/.hermes/config.yaml || echo "No providers configured."
    ;;
  *) usage ;;
  esac
  ;;
embeddings)
  if [[ "${2:-}" == "off" ]]; then
    hermes_cfg set plugins.hermes-memory-store.embeddings off
    restart_hermes
    echo "Memory search by meaning is off; memory stays local."
    exit 0
  fi
  url="${2:-}" model="${3:-}"
  [[ -n "$url" && -n "$model" ]] || usage
  check_url "$url"
  hermes_cfg set plugins.hermes-memory-store.embeddings on
  hermes_cfg set plugins.hermes-memory-store.embedding_url "$url"
  hermes_cfg set plugins.hermes-memory-store.embedding_model "$model"
  if store_key RE_EMBEDDINGS_KEY "the embeddings API"; then
    hermes_cfg set plugins.hermes-memory-store.embedding_key_env RE_EMBEDDINGS_KEY
  fi
  re-firewall allow "$url"
  restart_hermes
  echo "Memory search by meaning uses ${model} at ${url}. Fact texts and messages are sent there."
  ;;
*)
  usage
  ;;
esac
CONFIG
chmod 700 /usr/local/sbin/re-agent-config
mkdir -p /opt/re-agent
# Writes the host proxy template and the local Squid config from the allowlist.
/usr/local/sbin/re-firewall allow api.anthropic.com >/dev/null
msg_ok "Deployed egress quarantine"

motd_ssh
customize
cleanup_lxc
