# OpenClaw + n8n + MCP Stack Setup (by duynghien)

Automatic installation script for a secure AI Agent ecosystem, integrated with n8n and workflow management tools via the Model Context Protocol (MCP).

## 🚀 Key Features
- **OpenClaw Stack**: Installs OpenClaw (Gateway + Agent) from source.
- **n8n Automation**: Deploys n8n with a full database stack (Postgres, Redis) and Worker.
- **MCP Integration**: Includes `n8n-custom-mcp` (by duynghien) to allow the Agent to control n8n directly.
- **Security**: Uses Caddy (Reverse Proxy) for SSL/Domain management and isolates services within a private Docker network.
- **Two-Way Communication**: Pre-configured Skills allow the Agent to trigger n8n and n8n to send responses back to the Agent.

## 📋 System Requirements
- **OS**: Ubuntu 22.04 LTS (Recommended).
- **Minimum Specs**: 4GB RAM, 2 vCPUs (DigitalOcean $24/mo Droplet recommended).
- **Permissions**: Must be run as `root`.

## 🛠️ Installation Guide

### Step 1: Prepare Access Keys
You will need:
1. **Telegram Bot Token**: Get it from `@BotFather`.
2. **Telegram User ID**: Get it from `@userinfobot`.
3. **OpenAI API Key**: From OpenAI Platform.

### Step 2: Run the Script
Copy and run the following command on your VPS terminal:

```bash
curl -O https://raw.githubusercontent.com/duynghien/auto/main/openclaw-n8n-mcp/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### Step 3: Complete MCP Configuration (Important)
Once the script finishes, n8n is running, but the MCP service needs an API Key to allow the Agent to control n8n.
1. Access n8n: `https://n8n.<YOUR_IP>.nip.io`
2. Create your n8n account.
3. Go to **Settings > Personal API Keys > Create New**.
4. Copy the generated key.
5. Back in the terminal, edit the `.env` file:
   ```bash
   nano /opt/openclaw/.env
   ```
6. Replace `REPLACE_ME_LATER` at the `N8N_API_KEY` line with your copied key.
7. Restart the MCP service:
   ```bash
   cd /opt/openclaw
   docker compose up -d n8n-mcp
   ```

## 📂 Directory Structure
- `/opt/openclaw`: Main directory containing Docker Compose and environment config.
- `/root/.openclaw`: Contains Agent data and Skills (n8n-webhook, n8n-mcp).
- `/opt/clawdbot/caddy_config`: Contains Caddyfile for domain management.

## 🤝 Support
- Website: [https://ai.vnrom.net](https://ai.vnrom.net)
- User: **duynghien**

## 📜 Credits
This project architecture and setup scripts are inspired by [openclaw-n8n-starter](https://github.com/Barty-Bart/openclaw-n8n-starter).
