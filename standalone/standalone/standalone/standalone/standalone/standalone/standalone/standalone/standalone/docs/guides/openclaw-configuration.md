# OpenClaw Configuration Guide

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
      "mode": "token",
      "token": "your-secure-token-here"
    }
  }
}
```

Then restart:

```bash
systemctl restart openclaw
```

**Important:**

- `allowInsecureAuth` only works for localhost connections in non-secure HTTP contexts
- It does **NOT** bypass device identity for remote (non-localhost) connections
- You must still use SSH tunnel or HTTPS for remote LAN access

### Solution 3: HTTPS Reverse Proxy (Production)

Set up Caddy or Nginx with SSL certificates for secure HTTPS access.

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
mkdir -p ~/.openclaw
cat > ~/.openclaw/openclaw.json << EOF
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

# Update service to use lan binding
sed -i 's|--port 18789|--port 18789 --bind lan|' /etc/systemd/system/openclaw.service

# Apply and restart
systemctl daemon-reload
systemctl restart openclaw
```

**Note:** Even with `allowedOrigins` configured, you still need a secure context (HTTPS or localhost) for the device identity requirement. Use SSH tunneling for LAN access.

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
openclaw configure --section gateway

# Set bind to "lan" when prompted
# Then restart the service
systemctl restart openclaw
```

### Method 2: Manual Configuration

Edit both the configuration file and systemd service:

```bash
# Create/edit the configuration file
nano ~/.openclaw/openclaw.json
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

Then edit the systemd service:

```bash
nano /etc/systemd/system/openclaw.service
```

Modify the `ExecStart` line to include `--bind lan`:

```ini
[Service]
ExecStart=/usr/bin/openclaw gateway --port 18789 --bind lan
```

Apply changes:

```bash
systemctl daemon-reload
systemctl restart openclaw
```

### Method 3: Quick Fix for Existing Installations

For existing installations, run these commands:

```bash
# Get your container IP
CONTAINER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)

# Create configuration with allowed origins
mkdir -p ~/.openclaw
cat > ~/.openclaw/openclaw.json << EOF
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

# Update service to use lan binding
sed -i 's|--port 18789|--port 18789 --bind lan|' /etc/systemd/system/openclaw.service

# Apply and restart
systemctl daemon-reload
systemctl restart openclaw
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
openclaw gateway status
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
   openclaw configure --section gateway
   # Set bind to "tailnet"
   systemctl restart openclaw
   ```

3. Access via Tailscale IP: `http://<tailscale-ip>:18789`

## Troubleshooting

### Gateway Not Starting

```bash
# Check logs
journalctl -u openclaw -f

# Common issues:
# - Port already in use: lsof -i :18789
# - Permission denied: ensure running as root or correct user
```

### Cannot Connect from Remote

1. Verify binding: `openclaw gateway status` should show `0.0.0.0:18789`
2. Check firewall: `ufw status` or `iptables -L -n`
3. Verify network connectivity: `ping <server-ip>`

### Token Authentication Issues

```bash
# Regenerate token
openclaw doctor --generate-gateway-token

# View current token
openclaw gateway status
```

## Installing Homebrew (Optional)

If you need to install additional tools via Homebrew, follow these steps:

### Prerequisites

The `openclaw` user needs sudo access and a password set. By default, the user is created without a password.

### Step 1: Set Password for openclaw User

As root, set a password for the openclaw user:

```bash
passwd openclaw
# Enter and confirm the new password
```

### Step 2: Install Homebrew

Switch to the openclaw user and run the installer:

```bash
su - openclaw
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

When prompted:

1. Enter the openclaw password for sudo access
2. Press ENTER to continue when the installer shows the directories it will create

### Step 3: Add Homebrew to PATH

After installation, add Homebrew to your shell:

```bash
echo >> /home/openclaw/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> /home/openclaw/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
```

### Step 4: Verify Installation

```bash
brew --version
```

### Installing Packages

Once Homebrew is installed, you can install packages:

```bash
brew install <package-name>
```

**Note:** Homebrew packages are installed to `/home/linuxbrew/.linuxbrew/` and are available to all users on the system.

## Additional Resources

- [OpenClaw Gateway Documentation](https://docs.openclaw.ai/gateway)
- [OpenClaw Security Guide](https://docs.openclaw.ai/gateway/security)
- [OpenClaw Troubleshooting](https://docs.openclaw.ai/gateway/troubleshooting)
