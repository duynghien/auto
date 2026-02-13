#!/bin/bash
set -e

# Define Colors
RED='\033[0;31m'
GREEN='\033[1;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Clear screen and show header
clear
echo "================================================================"
echo -e "${PURPLE}"
echo "      _                         _     _             ";
echo "     | |                       | |   (_)            ";
echo "   __| |_   _ _   _ ____   ____| |__  _ _____ ____  ";
echo "  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ ";
echo " ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |";
echo "  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|";
echo "             (____/      (_____|                    ";
echo ""
echo "               OpenClaw + n8n + n8n-custom-mcp Stack"
echo "                        https://ai.vnrom.net"
echo -e "${NC}"
echo "================================================================"
echo ""

# Function for logging
log() {
    echo -e "${GREEN}$1${NC}"
    echo "----------------------------------------------------------------"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

#######################################
# COLLECT USER INPUT
#######################################

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  error "Please run as root (sudo)"
fi

log "1. Collecting configuration information..."
read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Enter your Telegram User ID: " TELEGRAM_USER_ID
read -p "Enter your OpenAI API Key: " OPENAI_API_KEY
echo -e "${PURPLE}Note: You can skip the n8n API Key for now and add it later to .env after n8n is setup.${NC}"
read -p "Enter your n8n API Key (optional): " N8N_API_KEY
N8N_API_KEY=${N8N_API_KEY:-"REPLACE_ME_LATER"}

if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_USER_ID" || -z "$OPENAI_API_KEY" ]]; then
    error "Bot Token, User ID, and OpenAI Key are required!"
fi

# Auto-detect IP
DETECTED_IP=$(curl -s ifconfig.me)
echo -e "${PURPLE}Domain/IP: Nếu chưa mua tên miền, bạn chỉ cần copy địa chỉ IP và dán vào. Hệ thống sẽ dùng nip.io để tạo tên miền tạm.${NC}"
read -p "Nhập Tên miền hoặc IP [${DETECTED_IP}]: " USER_INPUT
USER_INPUT=${USER_INPUT:-$DETECTED_IP}

# Check if input is a raw IP address (v4) to decide whether to use nip.io
if [[ $USER_INPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    DOMAIN_NAME="${USER_INPUT}.nip.io"
else
    DOMAIN_NAME="${USER_INPUT}"
fi

echo -e "Using domain: ${PURPLE}${DOMAIN_NAME}${NC}"

#######################################
# AUTO-GENERATED SECRETS
#######################################
GATEWAY_TOKEN=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
N8N_WEBHOOK_SECRET=$(openssl rand -hex 32)
N8N_WEBHOOK_PATH=$(cat /proc/sys/kernel/random/uuid)

log "2. Installing dependencies (Docker, Compose, UFW, Git)..."
apt update && apt install -y ufw git curl
# Use official Docker install script to avoid conflicts with Ubuntu's docker.io
if ! command -v docker &> /dev/null; then
    log "Installing Docker via get.docker.com..."
    curl -fsSL https://get.docker.com | sh
fi

log "3. Configuring firewall (22, 80, 443)..."
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw --force enable

log "4. Creating directories..."
mkdir -p /opt/openclaw
mkdir -p /opt/clawdbot/caddy_config
mkdir -p /opt/clawdbot/local_files
mkdir -p /root/.openclaw/workspace/skills/n8n-webhook
mkdir -p /opt/n8n-mcp/backups

log "5. Building OpenClaw from source..."
if [ ! -d "/opt/openclaw-src" ]; then
    git clone https://github.com/openclaw/openclaw.git /opt/openclaw-src
else
    cd /opt/openclaw-src && git pull
fi
cd /opt/openclaw-src
docker build -t openclaw:local .

log "6. Cloning n8n-custom-mcp..."
if [ ! -d "/opt/n8n-mcp-src" ]; then
    git clone https://github.com/duynghien/n8n-custom-mcp.git /opt/n8n-mcp-src
else
    cd /opt/n8n-mcp-src && git pull
fi

log "7. Creating OpenClaw config..."
cat > /root/.openclaw/openclaw.json << EOF
{
  "messages": {"ackReactionScope": "group-mentions"},
  "agents": {
    "defaults": {
      "maxConcurrent": 4,
      "subagents": {"maxConcurrent": 8},
      "compaction": {"mode": "safeguard"},
      "workspace": "/home/node/.openclaw/workspace",
      "model": {"primary": "openai/gpt-4.1-mini"},
      "models": {"openai/gpt-4.1-mini": {}}
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {"mode": "token", "token": "${GATEWAY_TOKEN}"},
    "port": 18789,
    "bind": "lan",
    "tailscale": {"mode": "off", "resetOnExit": false},
    "remote": {"token": "${GATEWAY_TOKEN}"}
  },
  "plugins": {"entries": {"telegram": {"enabled": true}}},
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "allowlist",
      "allowFrom": ["${TELEGRAM_USER_ID}"]
    }
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "session-memory": {"enabled": true},
        "command-logger": {"enabled": true}
      }
    }
  }
}
EOF

log "8. Creating n8n webhook skill..."
cat > /root/.openclaw/workspace/skills/n8n-webhook/SKILL.md << EOF
---
name: n8n-webhook
description: Trigger n8n workflows via webhook. Use this when you need to execute automations, run workflows, or integrate with external services through n8n.
---

# n8n Webhook Integration

## Endpoint
Internal URL: \`http://n8n:5678/webhook/${N8N_WEBHOOK_PATH}\`

## Authentication
All requests MUST include this header:
- Header: \`X-Webhook-Secret\`
- Value: \`${N8N_WEBHOOK_SECRET}\`

## How to use
Use the \`exec\` tool to call the n8n webhook with curl:

\`\`\`bash
curl -X POST "http://n8n:5678/webhook/${N8N_WEBHOOK_PATH}" \\
  -H "Content-Type: application/json" \\
  -H "X-Webhook-Secret: ${N8N_WEBHOOK_SECRET}" \\
  -d '{"task": "description of what to do", "data": {}}'
\`\`\`

## Notes
- Always include the X-Webhook-Secret header or the request will fail
- Send JSON payload describing the task or data
- n8n will process the workflow and return a response
EOF

log "9. Creating MCP Integration Skill..."
cat > /root/.openclaw/workspace/skills/n8n-mcp.md << EOF
---
name: n8n-mcp-manager
description: Manage n8n workflows and tasks using the MCP protocol. This allows direct access to n8n tools like listing workflows, getting executions, etc.
---

# n8n MCP Integration
Internal MCP Server: \`http://n8n-mcp:3000/sse\`

This skill enables the agent to use standard MCP tools to interact with n8n.
EOF

log "10. Creating Caddyfile..."
cat > /opt/clawdbot/caddy_config/Caddyfile << EOF
n8n.${DOMAIN_NAME} {
    reverse_proxy n8n:5678
}
EOF

log "11. Creating .env file..."
cat > /opt/openclaw/.env << EOF
# Security
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENAI_API_KEY=${OPENAI_API_KEY}

# Domain & n8n
DOMAIN_NAME=${DOMAIN_NAME}
N8N_SUBDOMAIN=n8n
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_API_KEY=${N8N_API_KEY}

# Database
POSTGRES_USER=n8n
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=n8n
EOF

log "12. Creating docker-compose.yml..."
cat > /opt/openclaw/docker-compose.yml << 'COMPOSEFILE'
networks:
  frontend:
  backend:
    internal: true
  egress:

volumes:
  caddy_data:
  n8n_data:
  postgres_data:
  mcp_backups:

services:
  openclaw-gateway:
    image: openclaw:local
    container_name: openclaw-gateway
    restart: unless-stopped
    command: ["node", "dist/index.js", "gateway"]
    user: "1000:1000"
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - /root/.openclaw:/home/node/.openclaw
    networks:
      - egress

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/clawdbot/caddy_config/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - /opt/clawdbot/local_files:/srv
    networks:
      - frontend

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - N8N_HOST=n8n.${DOMAIN_NAME}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.${DOMAIN_NAME}/
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
      - redis
    networks:
      - frontend
      - backend
      - egress

  n8n-worker:
    image: n8nio/n8n:latest
    container_name: n8n-worker
    restart: unless-stopped
    command: worker
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
      - redis
      - n8n
    networks:
      - backend

  n8n-mcp:
    build: 
      context: /opt/n8n-mcp-src
      dockerfile: Dockerfile
    container_name: n8n-mcp
    restart: unless-stopped
    environment:
      - N8N_HOST=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
      - MCP_TRANSPORT=sse
      - PORT=3000
    volumes:
      - mcp_backups:/app/backups
    networks:
      - backend

  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    networks:
      - backend
COMPOSEFILE

log "13. Setting permissions..."
chown -R 1000:1000 /root/.openclaw

log "14. Starting all services..."
cd /opt/openclaw
docker compose up -d

echo ""
echo "================================================================"
echo -e "${GREEN}  🎉 SETUP COMPLETE!${NC}"
echo "================================================================"
echo ""
echo -e "n8n URL: ${PURPLE}https://n8n.${DOMAIN_NAME}${NC}"
echo ""
echo "--------------------------------------------------------"
echo -e "${PURPLE}  🔑 Security & Access Info${NC}"
echo "--------------------------------------------------------"
echo "  OpenClaw Gateway Token: ${GATEWAY_TOKEN}"
echo "  n8n API Key (MCP):      ${N8N_API_KEY}"
echo "  n8n Webhook Path:       ${N8N_WEBHOOK_PATH}"
echo "  n8n Webhook Secret:     ${N8N_WEBHOOK_SECRET}"
echo ""
echo "--------------------------------------------------------"
echo -e "${PURPLE}  🤖 MCP Server (Internal)${NC}"
echo "--------------------------------------------------------"
echo "  Address: http://n8n-mcp:3000/sse"
echo ""
echo "--------------------------------------------------------"
echo -e "${PURPLE}  � ACTION REQUIRED (For MCP Support)${NC}"
echo "--------------------------------------------------------"
echo "  1. Log into n8n: https://n8n.${DOMAIN_NAME}"
echo "  2. Go to Settings > Personal API Keys > Create New"
echo "  3. Copy the key and edit /opt/openclaw/.env"
echo "  4. Update N8N_API_KEY and run:"
echo "     cd /opt/openclaw && docker compose up -d n8n-mcp"
echo ""
echo "================================================================"
echo -e "${RED}  ⚠️ PLEASE SAVE THESE VALUES SECURELY!${NC}"
echo "================================================================"
echo -e "  Support: ${PURPLE}https://ai.vnrom.net${NC}"
echo ""
