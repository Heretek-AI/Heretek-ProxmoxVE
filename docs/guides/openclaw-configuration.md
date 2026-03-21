# OpenClaw Configuration Guide

## Quick Start

After installation, OpenClaw requires a **model provider** to function. This is the most critical configuration step.

### Essential Commands

**Note:** The `openclaw` user has no login shell for security. Use `sudo -u openclaw` to run commands.

```bash
# Verify installation
sudo -u openclaw openclaw --version
sudo -u openclaw openclaw doctor
sudo -u openclaw openclaw gateway status

# View logs
sudo -u openclaw openclaw logs --follow
```

---

## Model Provider Configuration (REQUIRED)

OpenClaw requires a model provider to process messages. Choose one of the following options:

### Option A: Ollama (Local, Free, Recommended for Offline)

Ollama runs models locally on your hardware - no API costs, complete privacy.

#### 1. Install Ollama

```bash
# On the OpenClaw container or a separate server
curl -fsSL https://ollama.com/install.sh | sh
```

#### 2. Pull Required Models

```bash
# Chat model (choose one)
ollama pull llama3.2          # Good balance (recommended)
ollama pull llama3.1:8b       # Larger, more capable
ollama pull mistral           # Alternative option
ollama pull gemma2            # Google's model

# Embedding model (required for memory search)
ollama pull nomic-embed-text  # Recommended (274MB)
ollama pull mxbai-embed-large # Higher quality (670MB)
ollama pull all-minilm        # Smallest, fastest (45MB)
```

#### 3. Configure OpenClaw for Ollama

```bash
sudo -u openclaw openclaw configure
# Select "Ollama" when prompted for model provider
# Enter Ollama URL (default: http://localhost:11434)
```

Or manually edit `~/.openclaw/openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama:llama3.2"
      },
      "memorySearch": {
        "provider": "ollama",
        "model": "nomic-embed-text",
        "remote": {
          "baseUrl": "http://localhost:11434"
        }
      }
    }
  }
}
```

#### 4. Ollama on a Separate Server

If Ollama runs on a different machine:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama:llama3.2"
      },
      "memorySearch": {
        "provider": "ollama",
        "model": "nomic-embed-text",
        "remote": {
          "baseUrl": "http://192.168.1.100:11434"
        }
      }
    }
  }
}
```

### Option B: OpenAI API

```bash
sudo -u openclaw openclaw models auth add --provider openai
# Enter your API key when prompted

# Set as default model
sudo -u openclaw openclaw models set openai:gpt-4o
```

Manual configuration:

```json
{
  "secrets": {
    "providers": {
      "openai-api": {
        "source": "env",
        "env": "OPENAI_API_KEY"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai:gpt-4o"
      }
    }
  }
}
```

### Option C: Anthropic Claude

```bash
sudo -u openclaw openclaw models auth add --provider anthropic
# Enter your API key when prompted

# Set as default model
sudo -u openclaw openclaw models set anthropic:claude-opus-4-6
```

### Option D: Other Providers

OpenClaw supports many providers:

| Provider      | Command                                          |
| ------------- | ------------------------------------------------ |
| Google Gemini | `openclaw models auth add --provider google`     |
| Mistral       | `openclaw models auth add --provider mistral`    |
| OpenRouter    | `openclaw models auth add --provider openrouter` |
| Groq          | `openclaw models auth add --provider groq`       |
| xAI           | `openclaw models auth add --provider xai`        |
| Together AI   | `openclaw models auth add --provider together`   |

### Verify Model Configuration

```bash
# Check model status
openclaw models status

# Test with a message
openclaw agent --message "Hello, are you working?" --local
```

---

## Channel Configuration

OpenClaw supports multiple messaging channels. Configure channels to interact through your preferred platform.

### Supported Channels

| Channel         | Type          | Setup Method                    |
| --------------- | ------------- | ------------------------------- |
| Telegram        | Bot API       | Bot token from @BotFather       |
| Discord         | Bot API       | Bot token from Developer Portal |
| WhatsApp        | Baileys       | QR code pairing                 |
| Slack           | Bolt SDK      | App credentials                 |
| Signal          | signal-cli    | Phone number pairing            |
| Matrix          | Plugin        | Homeserver config               |
| iMessage        | BlueBubbles   | macOS server required           |
| Microsoft Teams | Bot Framework | App registration                |
| IRC             | Native        | Server connection               |
| Google Chat     | Webhook       | App configuration               |

### Telegram Setup (Easiest)

1. **Create a bot** by messaging [@BotFather](https://t.me/BotFather) on Telegram
2. **Get your bot token** (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
3. **Configure OpenClaw**:

```bash
sudo -u openclaw openclaw channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

4. **Start messaging** your bot on Telegram

### Discord Setup

1. **Create a bot** at [Discord Developer Portal](https://discord.com/developers/applications)
2. **Get your bot token** from the Bot section
3. **Invite bot to server** using OAuth2 URL generator
4. **Configure OpenClaw**:

```bash
sudo -u openclaw openclaw channels add --channel discord --token "YOUR_BOT_TOKEN"
```

### WhatsApp Setup

WhatsApp requires QR code pairing:

```bash
sudo -u openclaw openclaw channels add --channel whatsapp
# A QR code will be displayed
# Scan with WhatsApp on your phone (Settings > Linked Devices)
```

### Multiple Accounts

You can configure multiple accounts per channel:

```bash
# Add a second Telegram account
openclaw channels add --channel telegram --account work --name "Work Bot" --token "WORK_BOT_TOKEN"

# List all channels
openclaw channels list

# Check channel status
openclaw channels status --probe
```

### Channel Routing

Route different channels to different agents:

```bash
# Create an agent
openclaw agents add --workspace ~/.openclaw-workspaces/work

# Bind channels to agent
openclaw agents bind --agent <agent-id> --bind telegram:work
openclaw agents bind --agent <agent-id> --bind discord:main
```

---

## Memory Configuration

OpenClaw's memory search requires an embedding provider to index and search through your memory files.

### Memory Files Location

Memory files are stored in `~/.openclaw/workspace/memory/`:

```bash
# Create memory directory
mkdir -p ~/.openclaw/workspace/memory

# Create your first memory file
cat > ~/.openclaw/workspace/MEMORY.md << 'EOF'
# Personal Memory

## Preferences
- I prefer concise responses
- Use bullet points for lists

## Projects
- Home automation: running on Proxmox
- Media server: Jellyfin on port 8096
EOF
```

### Configure Memory Search

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "ollama",
        "model": "nomic-embed-text",
        "remote": {
          "baseUrl": "http://localhost:11434"
        }
      }
    }
  }
}
```

### Memory Commands

```bash
# Check memory status
openclaw memory status

# Reindex memory files
openclaw memory index

# Search memory
openclaw memory search "project details"
```

---

## "Device Identity Required" Error Fix

If you see this error when accessing the Control UI from another machine:

```
control ui requires device identity (use HTTPS or localhost secure context)
```

**This is a browser security requirement.** The Web Crypto API (used for device identity) only works in secure contexts - either HTTPS or localhost.

### Solution 1: SSH Tunnel (Recommended for LAN)

Access OpenClaw via localhost through an SSH tunnel:

```bash
# On your local machine, create an SSH tunnel
ssh -L 18789:localhost:18789 root@<container-ip>

# Then access in your browser
http://localhost:18789
```

### Solution 2: Allow Insecure Auth (LAN Only)

**Warning:** This reduces security. Only use on trusted networks.

Add `allowInsecureAuth: true` to your OpenClaw configuration:

```bash
# Edit configuration
nano ~/.openclaw/openclaw.json
```

```json
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789", "http://192.168.31.39:18789"],
      "allowInsecureAuth": true
    },
    "auth": {
      "token": "your-secure-token-here"
    }
  }
}
```

Then restart:

```bash
su - openclaw -c "systemctl --user restart openclaw-gateway"
```

**Important:**

- `allowInsecureAuth` only works for localhost connections in non-secure HTTP contexts
- It does **NOT** bypass device identity for remote (non-localhost) connections
- You must still use SSH tunnel or HTTPS for remote LAN access

### Solution 3: HTTPS Reverse Proxy (Production)

The installation includes Caddy for HTTPS access on port 18790.

### Solution 4: Tailscale VPN

Install Tailscale on both machines and access via Tailscale IP.

### Emergency Break-Glass (NOT Recommended)

For emergency access only, you can completely disable device auth:

```json
{
  "gateway": {
    "controlUi": {
      "dangerouslyDisableDeviceAuth": true
    }
  }
}
```

**⚠️ WARNING:** This is a severe security downgrade. Revert immediately after emergency use.

---

## "Origin Not Allowed" Error Fix

If you see this error when accessing the Control UI from another machine:

```
origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins)
```

**Quick Fix:**

```bash
# Get your container IP
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)

# Create configuration with allowed origins
sudo -u openclaw mkdir -p /home/openclaw/.openclaw
sudo -u openclaw tee /home/openclaw/.openclaw/openclaw.json > /dev/null << EOF
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "http://${CONTAINER_IP}:18789"
      ]
    }
  }
}
EOF

# Apply and restart
sudo -u openclaw systemctl --user restart openclaw-gateway
```

**Note:** Even with `allowedOrigins` configured, you still need a secure context (HTTPS or localhost) for the device identity requirement. Use SSH tunneling for LAN access.

---

## Network Binding Configuration

By default, OpenClaw binds to localhost (127.0.0.1) only. To make it accessible from other machines on your network, you need to:

1. **Bind to all interfaces** (`--bind lan`)
2. **Configure allowed origins** (required for non-loopback bindings)

### Bind Options

| Option     | Description                       | Use Case             |
| ---------- | --------------------------------- | -------------------- |
| `loopback` | Binds to 127.0.0.1 only           | Default, most secure |
| `lan`      | Binds to 0.0.0.0 (all interfaces) | Local network access |
| `tailnet`  | Binds to Tailscale interface      | VPN access only      |
| `auto`     | Automatic selection               | Let OpenClaw decide  |

### Method 1: Configure Command (Recommended for Existing Installations)

```bash
# Open the gateway configuration
sudo -u openclaw openclaw configure --section gateway

# Set bind to "lan" when prompted
# Then restart the service
sudo -u openclaw systemctl --user restart openclaw-gateway
```

### Method 2: Manual Configuration

Edit the configuration file:

```bash
# Edit the configuration file
nano /home/openclaw/.openclaw/openclaw.json
```

Add the configuration with your IP:

```json
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789", "http://192.168.1.4:18789"]
    }
  }
}
```

Apply changes:

```bash
sudo -u openclaw systemctl --user restart openclaw-gateway
```

### Method 3: Quick Fix for Existing Installations

For existing installations, run these commands:

```bash
# Get your container IP
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)

# Create configuration with allowed origins
sudo -u openclaw mkdir -p /home/openclaw/.openclaw
sudo -u openclaw tee /home/openclaw/.openclaw/openclaw.json > /dev/null << EOF
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789",
        "http://${CONTAINER_IP}:18789"
      ]
    }
  }
}
EOF

# Restart the service
sudo -u openclaw systemctl --user restart openclaw-gateway
```

### Method 4: Environment Variable

You can also set the bind mode via environment variable:

```bash
# Add to /etc/environment or the systemd service file
OPENCLAW_BIND=lan
```

## Verification

Check the current binding:

```bash
sudo -u openclaw openclaw gateway status
```

Output should show:

```
bind: lan
listener: 0.0.0.0:18789
```

## Security Considerations

When binding to all interfaces (`lan`):

1. **Token Authentication**: OpenClaw uses token-based authentication. The token is generated on first run and displayed in the startup output.

2. **Firewall**: Consider adding firewall rules to restrict access:

   ```bash
   # Allow only specific IP ranges
   ufw allow from 192.168.31.0/24 to any port 18789
   ```

3. **Reverse Proxy**: For production use, consider placing OpenClaw behind a reverse proxy (nginx, Caddy) with SSL:

   ```nginx
   server {
       listen 443 ssl;
       server_name openclaw.yourdomain.com;

       location / {
           proxy_pass http://127.0.0.1:18789;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
       }
   }
   ```

4. **Never expose directly to the internet**: The gateway provides administrative access to your system. Always use VPN, reverse proxy with authentication, or Tailscale for remote access.

## Remote Access Options

### SSH Tunnel (Most Secure for Temporary Access)

```bash
# On your local machine
ssh -N -L 18789:127.0.0.1:18789 root@<server-ip>

# Then access in browser
http://localhost:18789
```

### Tailscale (Recommended for Permanent Remote Access)

1. Install Tailscale on both machines
2. Set OpenClaw bind to `tailnet`:

   ```bash
   sudo -u openclaw openclaw configure --section gateway
   # Set bind to "tailnet"
   sudo -u openclaw systemctl --user restart openclaw-gateway
   ```

3. Access via Tailscale IP: `http://<tailscale-ip>:18789`

## Troubleshooting

### Gateway Not Starting

```bash
# Check logs
sudo -u openclaw journalctl --user -u openclaw-gateway -f

# Or from root
journalctl --user -u openclaw-gateway -f --user-unit

# Common issues:
# - Port already in use: lsof -i :18789
# - Permission denied: ensure running as correct user
# - Config errors: sudo -u openclaw openclaw doctor
```

### Cannot Connect from Remote

1. Verify binding: `sudo -u openclaw openclaw gateway status` should show `0.0.0.0:18789`
2. Check firewall: `ufw status` or `iptables -L -n`
3. Verify network connectivity: `ping <server-ip>`

### Token Authentication Issues

```bash
# View current token
sudo -u openclaw openclaw gateway status

# Regenerate token (if needed)
sudo -u openclaw openclaw doctor --generate-gateway-token
```

### Model Provider Issues

```bash
# Check model status
sudo -u openclaw openclaw models status

# Probe providers (may consume tokens)
sudo -u openclaw openclaw models status --probe

# Set default model
sudo -u openclaw openclaw models set <provider:model>

# Example:
sudo -u openclaw openclaw models set ollama:llama3.2
sudo -u openclaw openclaw models set openai:gpt-4o
```

### Channel Issues

```bash
# Check channel status
sudo -u openclaw openclaw channels status --probe

# View channel logs
sudo -u openclaw openclaw channels logs --channel telegram

# Re-login to a channel
sudo -u openclaw openclaw channels login --channel whatsapp
```

## Using Homebrew

Homebrew is installed automatically during the OpenClaw installation. It provides access to additional packages that may be useful for extending OpenClaw functionality.

### Verify Installation

```bash
sudo -u openclaw brew --version
```

### Installing Packages

Once Homebrew is installed, you can install additional packages:

```bash
brew install <package-name>
```

### Common Useful Packages

```bash
# Example: Install additional tools
brew install jq          # JSON processor
brew install yq          # YAML processor
brew install git-delta   # Better git diff viewer
```

**Note:** Homebrew packages are installed to `/home/linuxbrew/.linuxbrew/` and are available to all users on the system.

### Troubleshooting Homebrew

If Homebrew is not working correctly:

```bash
# Check if Homebrew is in PATH
which brew

# If not, add it manually
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

# Add to .bashrc permanently
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
```

---

## Embedding Model Comparison

| Model             | Size   | Quality | Speed   | Use Case                      |
| ----------------- | ------ | ------- | ------- | ----------------------------- |
| nomic-embed-text  | ~274MB | Good    | Fast    | General purpose (recommended) |
| mxbai-embed-large | ~670MB | Better  | Medium  | Higher accuracy needed        |
| all-minilm        | ~45MB  | Basic   | Fastest | Resource-constrained          |

---

## Hybrid Search (BM25 + Vector)

Enable hybrid search for better recall:

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "ollama",
        "model": "nomic-embed-text",
        "remote": {
          "baseUrl": "http://localhost:11434"
        },
        "query": {
          "hybrid": {
            "enabled": true,
            "vectorWeight": 0.7,
            "textWeight": 0.3
          }
        }
      }
    }
  }
}
```

---

## Additional Resources

- [OpenClaw Gateway Documentation](https://docs.openclaw.ai/gateway)
- [OpenClaw Security Guide](https://docs.openclaw.ai/gateway/security)
- [OpenClaw Troubleshooting](https://docs.openclaw.ai/gateway/troubleshooting)
- [OpenClaw Memory Configuration Reference](https://docs.openclaw.ai/reference/memory-config)
- [OpenClaw CLI Reference](https://docs.openclaw.ai/cli)
- [OpenClaw Channels](https://docs.openclaw.ai/channels)
- [OpenClaw Model Providers](https://docs.openclaw.ai/providers)
- [Ollama Documentation](https://ollama.com/docs)
