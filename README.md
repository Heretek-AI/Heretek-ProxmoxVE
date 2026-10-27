<div align="center">
  <img src="https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/main/docs/images/heretek-logo.png" height="120px" alt="Heretek-AI logo" />

  <h1>Proxmox VE Heretek-Scripts</h1>
  <p><em>Experimental scripts beyond the orthodox canon</em></p>

  <p>
    <a href="https://github.com/Heretek-AI/ProxmoxVE">
      <img src="https://img.shields.io/badge/🔧_Main_Repository-Heretek_Forge-9b59b6?style=for-the-badge&labelColor=2d3748" alt="Main repository" />
    </a>
    <a href="https://github.com/community-scripts/ProxmoxVE">
      <img src="https://img.shields.io/badge/🏛️_Orthodox-Upstream-4c9b3f?style=for-the-badge&labelColor=2d3748" alt="Upstream" />
    </a>
    <a href="https://discord.gg/3AnUqsXnmK">
      <img src="https://img.shields.io/badge/💬_Discord-Join-7289da?style=for-the-badge&labelColor=2d3748" alt="Discord" />
    </a>
  </p>
</div>

> [!NOTE]
> This repository is a read-only mirror of the Heretek scripts in
> **[Heretek-AI/ProxmoxVE](https://github.com/Heretek-AI/ProxmoxVE)**, synced
> automatically. Open issues and pull requests there.

The scripts create LXC containers (and, for RE-Agent, a VM) on Proxmox VE. They use the same engine as
[community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)
(loaded from [community-scripts/core](https://github.com/community-scripts/core))
and fetch their install scripts from Heretek-AI/ProxmoxVE.

## Scripts

| Script | What it is | Default resources |
| --- | --- | --- |
| [Agregarr](https://github.com/agregarr/agregarr) | Keeps Plex Home and Recommended fresh with collections from Trakt, IMDb, TMDB, Letterboxd and more | 2 CPU, 4 GB RAM |
| [Drop](https://github.com/Drop-OSS/drop) | Open-source game distribution platform, similar to Steam or GameVault | 2 CPU, 4 GB RAM |
| [Gufo](https://github.com/gufo-org/gufo) | Local inference engine tuned for AMD Strix Halo (gfx1151), with an OpenAI-compatible API | 8 CPU, 32 GB RAM, 80 GB, Strix Halo GPU |
| [GSQHalo.cpp](https://github.com/Aristo94/GSQHalo.cpp) | llama.cpp fork for GSQ-RCO Qwen3.8-Flash-Next on AMD Strix Halo (gfx1151), built with its own ROCm 7.14.1 | 8 CPU, 64 GB RAM, 120 GB, Strix Halo GPU |
| [Kali Linux](https://www.kali.org/) | Debian-based distribution for security testing | 2 CPU, 4 GB RAM |
| [Kyojin](https://github.com/Yamz-Labs/kyojin) | ExLlamaV3-based engine for AMD Strix Halo (gfx1151) serving Yamz Labs' EXL3 Qwen3.8-Flash-Next, GLM-5.3-Flash and MiMo-V2.6-Flash packs, with an OpenAI-compatible API | 8 CPU, 64 GB RAM, 160 GB, Strix Halo GPU |
| [llama.cpp Server](https://github.com/ggml-org/llama.cpp) | LLM inference server with an OpenAI-compatible API, Vulkan backend | 4 CPU, 8 GB RAM |
| [LocalRecall](https://github.com/mudler/LocalRecall) | REST API for knowledge bases stored in vector databases | 2 CPU, 2 GB RAM |
| [MCPHub](https://github.com/samanhappy/mcphub) | One dashboard and API for managing and routing MCP servers | 2 CPU, 2 GB RAM |
| [OpenClaw](https://openclaw.ai) | Personal AI assistant across WhatsApp, Telegram, Slack, Discord and more | 2 CPU, 4 GB RAM |
| [PentAGI](https://github.com/vxcontrol/pentagi) | AI-powered autonomous penetration testing | 4 CPU, 8 GB RAM |
| [RAGFlow](https://ragflow.io/) | RAG engine with deep document understanding | 4 CPU, 16 GB RAM |
| [RE-Agent](https://github.com/morluto/rea) | Malware reverse-engineering workstation: Hermes Agent with REA, Ghidra, BINNY, capa, FLOSS, YARA and Detect It Easy, with an egress allowlist you turn on with `re-firewall isolate local` before handling samples. LXC for static analysis, VM (`vm/re-agent-vm.sh`) for running samples | 4 CPU, 8 GB RAM, 40 GB |
| [SkillServer](https://github.com/mudler/skillserver) | MCP/REST server and web UI holding a skills database for AI agents (in development) | 2 CPU, 2 GB RAM |
| [Strata](https://github.com/Niko1221/Strata) | Inference engine for Qwen3.8-Flash-Next with a Strix Halo (gfx1151) HIP engine and an OpenAI-compatible API | 8 CPU, 64 GB RAM, 150 GB, Strix Halo GPU |
| [SwarmUI](https://github.com/mcmonkeyprojects/SwarmUI) | Stable Diffusion web UI with built-in ComfyUI | 8 CPU, 16 GB RAM |
| [Unsloth Studio](https://unsloth.ai/) | Browser GUI for fine-tuning LLMs without code | 4 CPU, 16 GB RAM |
| [Yao](https://github.com/YaoApp/yao) | Yao application engine | |
| [ZTNet](https://ztnet.network) | Web UI for ZeroTier networks | |

Hermes, Lemonade and Wakapi used to be here. They now have official scripts in
community-scripts/ProxmoxVE: `hermesagent`, `lemonade-server` and `alpine-wakapi`.

## Usage

Run a script from the Proxmox VE shell, for example:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/main/ct/mcphub.sh)"
```

VM scripts live in `vm/`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Heretek-AI/ProxmoxVE/main/vm/re-agent-vm.sh)"
```

Inside a container, run `update` to update the app.

## License

MIT, see [LICENSE](LICENSE). Originally created by tteck, maintained by the
community-scripts team, extended by Heretek-AI.
