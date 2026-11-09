#!/bin/bash
set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -n "${INSTALL_DIR:-}" && -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m cd \"${INSTALL_DIR}\" && docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

###############################################################################
# OpenClaw + n8n + n8n-custom-mcp Stack Setup v2 (by duynghien)
# https://ai.vnrom.net
#
# Features:
#   - OpenClaw Gateway + Agent (full stack)
#   - n8n Automation (Postgres, Redis, Worker)
#   - n8n-custom-mcp (MCP bridge)
#   - Feature toggle system
#   - Health checks for all services
#   - Optional: Watchtower, Auto-backup, Multi-model, Web Browsing
###############################################################################

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[1;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Logging ──────────────────────────────────────────────────────────────────
log()   { echo -e "${GREEN}[✓] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
info()  { echo -e "${CYAN}[i] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }
step()  { echo ""; echo -e "${BOLD}────────────────────────────────────────────${NC}"; echo -e "${PURPLE}  $1${NC}"; echo -e "${BOLD}────────────────────────────────────────────${NC}"; }

# ─── Detect OS ────────────────────────────────────────────────────────────────
detect_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        OS="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="linux"
        DISTRO="$ID"
    else
        error "Unsupported OS. Requires Ubuntu/Debian or macOS."
    fi
}

# ─── Generate UUID (cross-platform) ──────────────────────────────────────────
generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
    fi
}

# ─── Check Root (Linux only) ─────────────────────────────────────────────────
check_root() {
    if [[ "$OS" == "linux" ]] && [[ "$EUID" -ne 0 ]]; then
        error "Please run as root (sudo ./setup.sh)"
    fi
}

# ─── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo ""
    echo -e "${PURPLE}"
    echo "      _                         _     _             "
    echo "     | |                       | |   (_)            "
    echo "   __| |_   _ _   _ ____   ____| |__  _ _____ ____  "
    echo "  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ "
    echo " ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |"
    echo "  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|"
    echo "             (____/      (_____|                    "
    echo ""
    echo "         OpenClaw + n8n + n8n-custom-mcp Stack v2"
    echo "                  https://ai.vnrom.net"
    echo -e "${NC}"
    echo "================================================================"
    echo ""
}

###############################################################################
# FEATURE TOGGLE SYSTEM
###############################################################################

# Default feature states
ENABLE_N8N_MCP=true
ENABLE_WATCHTOWER=false
ENABLE_BACKUP=false
ENABLE_WEB_BROWSE=true
ENABLE_MULTI_MODEL=false
ENABLE_SYSTEM_PROMPT=true
ANTHROPIC_API_KEY=""
DEEPSEEK_API_KEY=""

feature_menu() {
    echo -e "${BOLD}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│          ⚙️  FEATURE TOGGLES                 │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────┤${NC}"
    printf "${BOLD}│${NC} %-3s %-30s %-8s ${BOLD}│${NC}\n" "#" "Feature" "Status"
    echo -e "${BOLD}├─────────────────────────────────────────────┤${NC}"
    
    local features=("n8n MCP Server" "Watchtower (Auto-update)" "Auto Backup (Daily)" "Web Browsing Skill" "Multi-model Support" "System Prompt")
    local vars=(ENABLE_N8N_MCP ENABLE_WATCHTOWER ENABLE_BACKUP ENABLE_WEB_BROWSE ENABLE_MULTI_MODEL ENABLE_SYSTEM_PROMPT)
    
    for i in "${!features[@]}"; do
        local num=$((i + 1))
        local val="${!vars[$i]}"
        if [[ "$val" == "true" ]]; then
            local status="${GREEN}ON${NC}"
        else
            local status="${RED}OFF${NC}"
        fi
        printf "${BOLD}│${NC} %-3s %-30s %-18b ${BOLD}│${NC}\n" "[$num]" "${features[$i]}" "$status"
    done
    
    echo -e "${BOLD}├─────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│${NC} [0] Proceed with current settings            ${BOLD}│${NC}"
    echo -e "${BOLD}└─────────────────────────────────────────────┘${NC}"
}

toggle_feature() {
    local var_name=$1
    local current="${!var_name}"
    if [[ "$current" == "true" ]]; then
        eval "$var_name=false"
    else
        eval "$var_name=true"
    fi
}

collect_features() {
    step "1/12 — Feature Selection"
    
    while true; do
        feature_menu
        echo ""
        read -p "Toggle a feature [1-6] or proceed [0]: " choice
        case $choice in
            1) toggle_feature ENABLE_N8N_MCP ;;
            2) toggle_feature ENABLE_WATCHTOWER ;;
            3) toggle_feature ENABLE_BACKUP ;;
            4) toggle_feature ENABLE_WEB_BROWSE ;;
            5) toggle_feature ENABLE_MULTI_MODEL ;;
            6) toggle_feature ENABLE_SYSTEM_PROMPT ;;
            0) break ;;
            *) warn "Invalid choice, try again." ;;
        esac
        echo ""
    done
    
    log "Features configured."
}

###############################################################################
# COLLECT USER INPUT
###############################################################################

collect_input() {
    step "2/12 — Configuration"
    
    read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Enter your Telegram User ID: " TELEGRAM_USER_ID
    read -p "Enter your OpenAI API Key: " OPENAI_API_KEY
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_USER_ID" || -z "$OPENAI_API_KEY" ]]; then
        error "Telegram Bot Token, User ID, and OpenAI API Key are required!"
    fi
    
    # Optional keys
    echo ""
    info "Optional keys (press Enter to skip):"
    
    read -p "  n8n API Key (create later in n8n Settings): " N8N_API_KEY
    N8N_API_KEY=${N8N_API_KEY:-"REPLACE_ME_LATER"}
    
    if [[ "$ENABLE_MULTI_MODEL" == "true" ]]; then
        read -p "  Anthropic API Key (optional): " ANTHROPIC_API_KEY
        read -p "  DeepSeek API Key (optional): " DEEPSEEK_API_KEY
    fi
    
    # Domain / IP
    echo ""
    DETECTED_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
    info "Domain/IP: If you don't have a domain, paste your IP. System will use nip.io."
    read -p "  Domain or IP [${DETECTED_IP}]: " USER_INPUT
    USER_INPUT=${USER_INPUT:-$DETECTED_IP}
    
    if [[ -z "$USER_INPUT" ]]; then
        error "Could not detect IP. Please provide a domain or IP address."
    fi
    
    # Check if raw IP → use nip.io
    if [[ $USER_INPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        DOMAIN_NAME="${USER_INPUT}.nip.io"
    else
        DOMAIN_NAME="${USER_INPUT}"
    fi
    
    # Timezone
    read -p "  Timezone [Asia/Ho_Chi_Minh]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-"Asia/Ho_Chi_Minh"}
    
    echo ""
    log "Using domain: ${PURPLE}${DOMAIN_NAME}${NC}"
}

###############################################################################
# AUTO-GENERATED SECRETS
###############################################################################

generate_secrets() {
    step "3/12 — Generating Secrets"
    
    GATEWAY_TOKEN=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 16)
    N8N_WEBHOOK_SECRET=$(openssl rand -hex 32)
    N8N_WEBHOOK_PATH=$(generate_uuid)
    
    log "Secrets generated securely."
}

###############################################################################
# INSTALL DEPENDENCIES
###############################################################################

install_deps() {
    step "4/12 — Installing Dependencies"
    
    if [[ "$OS" == "linux" ]]; then
        apt update && apt install -y curl git jq
        
        # RAM & Swap Preflight Guard
        TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
        TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
        if [ "$TOTAL_MEM_MB" -lt 4000 ] && [ "$TOTAL_SWAP_MB" -lt 2000 ]; then
            warn "Low memory detected (<4GB RAM and <2GB Swap). OpenClaw + n8n runs best with adequate swap."
            read -rp "  Would you like to allocate 4GB Swap? [Y/n]: " SWAP_CHOICE || true
            case "${SWAP_CHOICE:-y}" in
                y|Y|yes|YES)
                    AVAILABLE_DISK_KB=$(df -P / | awk 'NR==2 {print $4}')
                    if [ "$AVAILABLE_DISK_KB" -gt 6000000 ]; then
                        info "Creating 4GB swapfile..."
                        fallocate -l 4G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
                        chmod 600 /swapfile
                        mkswap /swapfile
                        if ! swapon /swapfile 2>/dev/null; then
                            warn "swapon restricted on this virtual environment (LXC/OpenVZ). Skipping swap."
                            rm -f /swapfile
                        else
                            grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
                            log "4GB Swap enabled."
                        fi
                    else
                        warn "Insufficient disk space for 4GB swap. Skipping."
                    fi
                    ;;
            esac
        fi

        # Install Docker if not present
        if ! command -v docker &>/dev/null; then
            log "Installing Docker..."
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        else
            log "Docker already installed."
        fi
        
        # Firewall
        if command -v ufw &>/dev/null; then
            info "Configuring firewall (22, 80, 443)..."
            ufw allow 22
            ufw allow 80
            ufw allow 443
            ufw --force enable
        fi
        
    elif [[ "$OS" == "macos" ]]; then
        if ! command -v docker &>/dev/null; then
            error "Docker Desktop is required on macOS. Install from https://docker.com"
        fi
        if ! command -v git &>/dev/null; then
            error "Git is required. Install with: xcode-select --install"
        fi
        log "Dependencies OK (macOS)."
    fi
}

###############################################################################
# CREATE DIRECTORIES
###############################################################################

create_dirs() {
    step "5/12 — Creating Directories"
    
    TARGET_USER="${SUDO_USER:-$USER}"
    TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
    ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
    local BASE_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/openclaw"
    
    export INSTALL_DIR="$BASE_DIR"
    export OPENCLAW_HOME="${INSTALL_DIR}/data"
    export CADDY_CONFIG="${INSTALL_DIR}/caddy"
    export SKILLS_DIR="${OPENCLAW_HOME}/workspace/skills"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$OPENCLAW_HOME/workspace/skills/n8n-webhook"
    mkdir -p -m 700 "${INSTALL_DIR}/backups"
    chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"
    
    log "Directories created at: ${INSTALL_DIR}"
}

###############################################################################
# BUILD / CLONE
###############################################################################

build_openclaw() {
    step "6/12 — Building OpenClaw from Source"
    
    local OPENCLAW_SRC="${INSTALL_DIR}/src/openclaw"
    if [ ! -d "$OPENCLAW_SRC" ]; then
        git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_SRC"
    else
        cd "$OPENCLAW_SRC" && git pull
    fi
    cd "$OPENCLAW_SRC"
    docker build -t openclaw:local .
    
    log "OpenClaw built successfully."
}

clone_n8n_mcp() {
    if [[ "$ENABLE_N8N_MCP" != "true" ]]; then
        info "Skipping n8n-custom-mcp (disabled)."
        return
    fi
    
    step "7/12 — Cloning n8n-custom-mcp"
    
    local MCP_SRC="${INSTALL_DIR}/src/n8n-custom-mcp"
    if [ ! -d "$MCP_SRC" ]; then
        git clone https://github.com/duynghien/n8n-custom-mcp.git "$MCP_SRC"
    else
        cd "$MCP_SRC" && git pull
    fi
    
    export MCP_SRC_DIR="$MCP_SRC"
    log "n8n-custom-mcp cloned."
}

###############################################################################
# OPENCLAW CONFIG
###############################################################################

create_openclaw_config() {
    step "8/12 — Creating OpenClaw Configuration"
    
    # ── Model Configuration ──
    local MODELS_JSON='"openai/gpt-4.1-mini": {}'
    local PRIMARY_MODEL="openai/gpt-4.1-mini"
    local ENV_KEYS=""
    
    if [[ "$ENABLE_MULTI_MODEL" == "true" ]]; then
        MODELS_JSON='"openai/gpt-4.1-mini": {}, "openai/gpt-4.1": {}'
        if [[ -n "$ANTHROPIC_API_KEY" ]]; then
            MODELS_JSON="${MODELS_JSON}, \"anthropic/claude-sonnet-4-20250514\": {}"
        fi
        if [[ -n "$DEEPSEEK_API_KEY" ]]; then
            MODELS_JSON="${MODELS_JSON}, \"deepseek/deepseek-chat\": {}"
        fi
    fi
    
    # ── MCP Client Config ──

    
    # ── Main Config ──
    cat > "${OPENCLAW_HOME}/openclaw.json" << JSONEOF
{
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "agents": {
    "defaults": {
      "maxConcurrent": 4,
      "subagents": {"maxConcurrent": 8},
      "compaction": {"mode": "safeguard"},
      "workspace": "/home/node/.openclaw/workspace",
      "model": {"primary": "${PRIMARY_MODEL}"},
      "models": {${MODELS_JSON}}
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
  "plugins": {
    "entries": {
      "telegram": {"enabled": true}
    }
  },
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
JSONEOF
    
    log "OpenClaw config created."
    
    # ── System Prompt ──
    if [[ "$ENABLE_SYSTEM_PROMPT" == "true" ]]; then
        create_system_prompt
    fi
}

create_system_prompt() {
    cat > "${OPENCLAW_HOME}/workspace/system-prompt.md" << 'PROMPT'
# Agent Identity

You are a powerful AI assistant running on OpenClaw, integrated with n8n automation platform. You have access to both direct tools (terminal, file editor, browser) and n8n workflows via MCP.

## Capabilities

### Direct Tools
- **Terminal**: Execute shell commands on the server
- **File Editor**: Read/write/edit files
- **Browser**: Browse the web and extract information (if enabled)

### n8n Integration (via MCP)
- **List Workflows**: See all available n8n workflows
- **Execute Workflows**: Trigger any workflow
- **Get Executions**: Check past execution results
- **Manage Workflows**: Create, update, activate/deactivate workflows

### n8n Webhook
- Trigger specific workflows via webhook with authentication

## Guidelines
1. When asked to automate something, check if there's an existing n8n workflow first
2. For complex multi-step tasks, consider creating an n8n workflow
3. Always confirm before executing destructive actions
4. Report errors clearly and suggest fixes
5. Use your MCP tools to directly interact with n8n — no need to use curl manually if MCP is available
PROMPT
    
    log "System prompt created."
}

###############################################################################
# SKILLS
###############################################################################

create_skills() {
    step "9/12 — Creating Agent Skills"
    
    # ── n8n Webhook Skill ──
    cat > "${SKILLS_DIR}/n8n-webhook/SKILL.md" << SKILLEOF
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
SKILLEOF
    
    log "n8n webhook skill created."
    
    # ── n8n MCP Skill ──
    if [[ "$ENABLE_N8N_MCP" == "true" ]]; then
        mkdir -p "${SKILLS_DIR}/n8n-mcp"
        cat > "${SKILLS_DIR}/n8n-mcp/SKILL.md" << 'MCPEOF'
---
name: n8n-mcp-manager
description: Manage n8n workflows and tasks using the MCP protocol. This allows direct access to n8n tools like listing workflows, getting executions, creating/updating workflows, and more. PREFER using MCP tools over manual curl commands.
---

# n8n MCP Integration

This skill enables the agent to use standard MCP tools to interact with n8n directly.

## Available MCP Tools
- **list_workflows**: List all n8n workflows with their status
- **get_workflow**: Get details of a specific workflow
- **create_workflow**: Create a new workflow
- **update_workflow**: Update an existing workflow
- **activate_workflow**: Activate a workflow
- **deactivate_workflow**: Deactivate a workflow
- **execute_workflow**: Execute a workflow
- **get_executions**: Get past execution results
- **delete_workflow**: Delete a workflow

## Usage Priority
1. **Always try MCP tools first** — they are faster and more reliable
2. Only fall back to webhook/curl if MCP is unavailable
3. When creating workflows, use the n8n JSON format

## Connection
MCP Server: `http://n8n-mcp:3000/sse` (configured automatically in openclaw.json)
MCPEOF
        
        log "n8n MCP skill created."
    fi
    
    # ── Web Browse Skill ──
    if [[ "$ENABLE_WEB_BROWSE" == "true" ]]; then
        mkdir -p "${SKILLS_DIR}/web-browse"
        cat > "${SKILLS_DIR}/web-browse/SKILL.md" << 'WEBEOF'
---
name: web-browse
description: Browse the web to search for information, read web pages, and extract data. Use this whenever you need up-to-date information from the internet.
---

# Web Browsing

## How to use
Use the `exec` tool to run curl commands for web browsing:

### Search the web
```bash
curl -s "https://html.duckduckgo.com/html/?q=YOUR_SEARCH_QUERY" | \
  sed -n 's/.*class="result__a"[^>]*href="\([^"]*\)"[^>]*>\(.*\)<\/a>.*/\2: \1/p' | \
  head -10
```

### Read a web page
```bash
curl -s -L "https://example.com" | \
  sed 's/<[^>]*>//g' | \
  sed '/^[[:space:]]*$/d' | \
  head -100
```

### Download a file
```bash
curl -L -o /tmp/filename "https://example.com/file"
```

## Notes
- Use DuckDuckGo HTML for searches (no API key needed)
- For JavaScript-heavy pages, results may be limited
- Always respect robots.txt and rate limits
WEBEOF
        
        log "Web browse skill created."
    fi
    
    # ── System Info Skill ──
    mkdir -p "${SKILLS_DIR}/system-info"
    cat > "${SKILLS_DIR}/system-info/SKILL.md" << 'SYSEOF'
---
name: system-info
description: Check server status, Docker containers, disk usage, and system health. Use this for monitoring and diagnostics.
---

# System Info & Monitoring

## Docker Status
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Disk Usage
```bash
df -h /
```

## Memory
```bash
free -h 2>/dev/null || vm_stat 2>/dev/null
```

## Container Logs
```bash
docker logs --tail 50 <container_name>
```

## Restart a Service
```bash
cd ${INSTALL_DIR} && docker compose restart <service_name>
```
SYSEOF
    
    log "System info skill created."
}

###############################################################################
# CADDY
###############################################################################



###############################################################################
# ENV FILE + FEATURES FILE
###############################################################################

create_env_files() {
    # ── Main .env ──
    cat > "${INSTALL_DIR}/.env" << ENVEOF
# ═══════════════════════════════════════════
# OpenClaw + n8n Stack — Environment Config
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# ═══════════════════════════════════════════

# ── Security ──
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENAI_API_KEY=${OPENAI_API_KEY}
ENVEOF

    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> "${INSTALL_DIR}/.env"
    fi
    if [[ -n "$DEEPSEEK_API_KEY" ]]; then
        echo "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}" >> "${INSTALL_DIR}/.env"
    fi
    
    cat >> "${INSTALL_DIR}/.env" << ENVEOF

# ── Domain & n8n ──
DOMAIN_NAME=${DOMAIN_NAME}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_API_KEY=${N8N_API_KEY}
TIMEZONE=${TIMEZONE}

# ── Database ──
POSTGRES_USER=n8n
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=n8n

# ── Webhook ──
N8N_WEBHOOK_PATH=${N8N_WEBHOOK_PATH}
N8N_WEBHOOK_SECRET=${N8N_WEBHOOK_SECRET}
ENVEOF

    # ── Features .env ──
    cat > "${INSTALL_DIR}/features.env" << FEATEOF
# ═══════════════════════════════════════════
# Feature Toggles — Edit and run:
#   cd ${INSTALL_DIR} && docker compose up -d
# ═══════════════════════════════════════════
ENABLE_N8N_MCP=${ENABLE_N8N_MCP}
ENABLE_WATCHTOWER=${ENABLE_WATCHTOWER}
ENABLE_BACKUP=${ENABLE_BACKUP}
ENABLE_WEB_BROWSE=${ENABLE_WEB_BROWSE}
ENABLE_MULTI_MODEL=${ENABLE_MULTI_MODEL}
ENABLE_SYSTEM_PROMPT=${ENABLE_SYSTEM_PROMPT}
FEATEOF

    chmod 600 "${INSTALL_DIR}/.env" "${INSTALL_DIR}/features.env"
    local t_user="${SUDO_USER:-$USER}"
    local t_grp
    t_grp=$(id -gn "$t_user" 2>/dev/null || echo "$t_user")
    chown "$t_user:$t_grp" "${INSTALL_DIR}/.env" "${INSTALL_DIR}/features.env"

    log "Environment files created."
}

###############################################################################
# DOCKER COMPOSE
###############################################################################

create_docker_compose() {
    step "11/12 — Creating Docker Compose"
    
    # Determine OpenClaw data path inside container
    local OPENCLAW_DATA_PATH="${OPENCLAW_HOME}"
    
    cat > "${INSTALL_DIR}/docker-compose.yml" << COMPOSEFILE
# ═══════════════════════════════════════════════════════════════
# OpenClaw + n8n + MCP Stack v2 (by duynghien)
# https://ai.vnrom.net
# ═══════════════════════════════════════════════════════════════

networks:
  frontend:
  backend:
    internal: true
  agent-net:
    # Shared network for OpenClaw <-> n8n internal communication
  egress:
    driver: bridge

volumes:
  n8n_data:
  postgres_data:
  mcp_backups:

services:
  # ── OpenClaw Gateway ──────────────────────────────────────────
  openclaw-gateway:
    image: openclaw:local
    container_name: openclaw-gateway
    restart: unless-stopped
    command: ["node", "dist/index.js", "gateway"]
    user: "1000:1000"
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    environment:
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
COMPOSEFILE

    # Add optional multi-model env vars
    if [[ "$ENABLE_MULTI_MODEL" == "true" ]]; then
        if [[ -n "$ANTHROPIC_API_KEY" ]]; then
            echo "      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY}" >> "${INSTALL_DIR}/docker-compose.yml"
        fi
        if [[ -n "$DEEPSEEK_API_KEY" ]]; then
            echo "      - DEEPSEEK_API_KEY=\${DEEPSEEK_API_KEY}" >> "${INSTALL_DIR}/docker-compose.yml"
        fi
    fi

    cat >> "${INSTALL_DIR}/docker-compose.yml" << COMPOSEFILE
    volumes:
      - ${OPENCLAW_DATA_PATH}:/home/node/.openclaw
    networks:
      - agent-net
      - egress
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:18789/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"]
      interval: 30s
      timeout: 10s
      retries: 3



  # ── n8n (Main Instance) ──────────────────────────────────────
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - N8N_HOST=n8n.\${DOMAIN_NAME}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.\${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=\${TIMEZONE}
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - N8N_RUNNERS_ENABLED=true
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend
      - backend
      - agent-net
      - egress
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  # ── n8n Worker ───────────────────────────────────────────────
  n8n-worker:
    image: n8nio/n8n:latest
    container_name: n8n-worker
    restart: unless-stopped
    command: worker
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - GENERIC_TIMEZONE=\${TIMEZONE}
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - postgres
      - redis
      - n8n
    networks:
      - backend

  # ── PostgreSQL ───────────────────────────────────────────────
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── Redis ────────────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
COMPOSEFILE

    # ── Optional: n8n-custom-mcp ──
    if [[ "$ENABLE_N8N_MCP" == "true" ]]; then
        cat >> "${INSTALL_DIR}/docker-compose.yml" << COMPOSEFILE

  # ── n8n Custom MCP Server ────────────────────────────────────
  n8n-mcp:
    build:
      context: ${MCP_SRC_DIR}
      dockerfile: Dockerfile
    container_name: n8n-mcp
    restart: unless-stopped
    environment:
      - N8N_HOST=http://n8n:5678
      - N8N_API_KEY=\${N8N_API_KEY}
      - MCP_TRANSPORT=sse
      - PORT=3000
    volumes:
      - mcp_backups:/app/backups
    depends_on:
      n8n:
        condition: service_healthy
    networks:
      - backend
      - agent-net
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
COMPOSEFILE
    fi

    # ── Optional: Watchtower ──
    if [[ "$ENABLE_WATCHTOWER" == "true" ]]; then
        cat >> "${INSTALL_DIR}/docker-compose.yml" << 'COMPOSEFILE'

  # ── Watchtower (Auto-update) ─────────────────────────────────
  watchtower:
    image: nickfedor/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
      - WATCHTOWER_INCLUDE_STOPPED=false
      - WATCHTOWER_LABEL_ENABLE=false
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
COMPOSEFILE
    fi
    


    log "Docker Compose file created."
}

###############################################################################
# BACKUP SCRIPT (Optional)
###############################################################################

create_backup_script() {
    if [[ "$ENABLE_BACKUP" != "true" ]]; then
        return
    fi
    
    cat > "${INSTALL_DIR}/backup.sh" << BACKUPEOF
#!/bin/bash
# Automated daily backup for OpenClaw + n8n stack
BACKUP_DIR="${INSTALL_DIR}/backups"
DATE=\$(date '+%Y%m%d_%H%M%S')

echo "[\$(date)] Starting backup..."

# Backup n8n data
docker run --rm -v n8n_data:/data -v \${BACKUP_DIR}:/backup alpine \
  tar czf /backup/n8n_data_\${DATE}.tar.gz -C /data .

# Backup postgres
docker exec postgres pg_dump -U n8n n8n | gzip > \${BACKUP_DIR}/postgres_\${DATE}.sql.gz

# Backup OpenClaw config
tar czf \${BACKUP_DIR}/openclaw_config_\${DATE}.tar.gz -C ${OPENCLAW_HOME} .

# Cleanup old backups (keep last 7 days)
find \${BACKUP_DIR} -name "*.tar.gz" -mtime +7 -delete
find \${BACKUP_DIR} -name "*.sql.gz" -mtime +7 -delete
chmod 600 \${BACKUP_DIR}/*\${DATE}* 2>/dev/null || true

echo "[\$(date)] Backup completed."
BACKUPEOF
    
    chmod +x "${INSTALL_DIR}/backup.sh"
    
    # Install cron job (Linux only)
    if [[ "$OS" == "linux" ]]; then
        (crontab -l 2>/dev/null; echo "0 3 * * * ${INSTALL_DIR}/backup.sh >> ${INSTALL_DIR}/backups/backup.log 2>&1") | crontab -
        log "Daily backup cron installed (3:00 AM)."
    else
        info "macOS: Add this to crontab manually:"
        info "  0 3 * * * ${INSTALL_DIR}/backup.sh"
    fi
}

###############################################################################
# HELPER SCRIPT
###############################################################################

create_helper_script() {
    cat > "${INSTALL_DIR}/openclaw.sh" << 'HELPEREOF'
#!/bin/bash
# ═══════════════════════════════════════════
# OpenClaw Stack Helper (by duynghien)
# ═══════════════════════════════════════════

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

RED='\033[0;31m'
GREEN='\033[1;32m'
PURPLE='\033[0;35m'
NC='\033[0m'

case "$1" in
    status)
        echo -e "${PURPLE}=== Container Status ===${NC}"
        docker compose ps
        ;;
    logs)
        SERVICE="${2:-}"
        if [[ -z "$SERVICE" ]]; then
            docker compose logs --tail 50 -f
        else
            docker compose logs --tail 50 -f "$SERVICE"
        fi
        ;;
    restart)
        SERVICE="${2:-}"
        if [[ -z "$SERVICE" ]]; then
            docker compose restart
        else
            docker compose restart "$SERVICE"
        fi
        echo -e "${GREEN}Restarted.${NC}"
        ;;
    stop)
        docker compose down
        echo -e "${GREEN}All services stopped.${NC}"
        ;;
    start)
        docker compose up -d
        echo -e "${GREEN}All services started.${NC}"
        ;;
    backup)
        if [[ -f "$DIR/backup.sh" ]]; then
            bash "$DIR/backup.sh"
        else
            echo -e "${PURPLE}Running ad-hoc database backup...${NC}"
            mkdir -p -m 700 "$DIR/backups"
            DATE=$(date '+%Y%m%d_%H%M%S')
            docker exec postgres pg_dump -U n8n n8n | gzip > "$DIR/backups/postgres_${DATE}.sql.gz"
            chmod 600 "$DIR/backups/postgres_${DATE}.sql.gz"
            echo -e "${GREEN}✓ Database backed up to: $DIR/backups/postgres_${DATE}.sql.gz${NC}"
        fi
        ;;
    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: openclaw.sh restore <path-to-postgres-sql-gz>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${RED}WARNING: This will overwrite the n8n database!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            gunzip -c "$FILE" | docker compose exec -T postgres psql -U n8n -d n8n
            echo -e "${GREEN}✓ Database restore completed! Restarting n8n...${NC}"
            docker compose restart n8n
        else
            echo "Restore aborted."
        fi
        ;;
    doctor)
        echo -e "${PURPLE}=== OpenClaw Diagnostic Doctor ===${NC}"
        echo -n "Checking Docker... "
        if docker --version >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Docker not found${NC}"
        fi
        echo -n "Checking Docker Compose... "
        if docker compose version >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Docker Compose not found${NC}"
        fi
        echo "Disk space:"
        df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
        echo "File permissions:"
        for f in .env features.env; do
            if [[ -f "$f" ]]; then
                P=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%Lp" "$f" 2>/dev/null || echo "unknown")
                echo "  $f: $P (recommended: 600)"
            fi
        done
        echo "Port bindings:"
        for p in 5678 18789 3001 5432 6379; do
            if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
                echo "  [BOUND] Port $p is listening"
            else
                echo "  [OPEN/UNKNOWN] Port $p"
            fi
        done
        echo -n "PostgreSQL health: "
        if docker compose exec postgres pg_isready -U n8n -d n8n &>/dev/null; then
            echo -e "${GREEN}Ready (OK)${NC}"
        else
            echo -e "${YELLOW}Not ready${NC}"
        fi
        echo -n "Redis health: "
        if docker compose exec redis redis-cli ping &>/dev/null; then
            echo -e "${GREEN}Ready (PONG)${NC}"
        else
            echo -e "${YELLOW}Not ready${NC}"
        fi
        ;;
    uninstall)
        echo -e "${PURPLE}=== OpenClaw Uninstall ===${NC}"
        echo "  1) Soft Uninstall (Stop and remove containers, keep data)"
        echo "  2) Full Purge (Permanently destroy all containers and data volumes)"
        read -rp "Select option [1-2]: " UNINSTALL_CHOICE || true
        case "${UNINSTALL_CHOICE:-1}" in
            2)
                read -rp "Type 'yes' to confirm permanent data destruction: " CONFIRM
                if [[ "$CONFIRM" == "yes" ]]; then
                    docker compose down -v
                    echo -e "${GREEN}✓ All containers and volumes permanently deleted.${NC}"
                else
                    echo "Uninstall cancelled."
                fi
                ;;
            *)
                docker compose down
                echo -e "${GREEN}✓ Containers removed. Data preserved.${NC}"
                ;;
        esac
        ;;
    update)
        echo -e "${PURPLE}Pulling latest images...${NC}"
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}Updated.${NC}"
        ;;
    features)
        echo -e "${PURPLE}=== Feature Toggles ===${NC}"
        cat "$DIR/features.env"
        echo ""
        echo -e "Edit with: ${PURPLE}nano $DIR/features.env${NC}"
        ;;
    env)
        echo -e "${PURPLE}=== Environment (sensitive data hidden) ===${NC}"
        cat "$DIR/.env" | sed 's/\(=\).*/\1***/'
        ;;
    *)
        echo -e "${PURPLE}OpenClaw Stack Helper (Gen 4 Standard)${NC}"
        echo ""
        echo "Usage: openclaw.sh <command> [service]"
        echo ""
        echo "Commands:"
        echo "  status           Show all container statuses"
        echo "  logs [service]   View logs (all or specific service)"
        echo "  restart [svc]    Restart all or specific service"
        echo "  start            Start all services"
        echo "  stop             Stop all services"
        echo "  backup           Run backup"
        echo "  restore <file>   Restore database from archive"
        echo "  doctor           Run diagnostic health checks"
        echo "  uninstall        Soft or complete uninstall"
        echo "  update           Pull latest images and restart"
        echo "  features         View feature toggles"
        echo "  env              View environment (values hidden)"
        ;;
esac
HELPEREOF
    
    chmod +x "${INSTALL_DIR}/openclaw.sh"
    
    # Create symlink for easy access
    if [[ "$OS" == "linux" ]]; then
        ln -sf "${INSTALL_DIR}/openclaw.sh" /usr/local/bin/openclaw
    fi
    
    log "Helper script created. Use: openclaw <command>"
}

###############################################################################
# SET PERMISSIONS & START
###############################################################################

finalize() {
    step "12/12 — Finalizing & Starting Services"
    
    # Set permissions
    if [[ "$OS" == "linux" ]]; then
        chown -R 1000:1000 "${OPENCLAW_HOME}"
    fi
    
    # Start services
    cd "${INSTALL_DIR}"
    docker compose up -d
    
    log "All services starting..."
    
    # Wait a moment for containers to initialize
    echo ""
    info "Waiting for services to initialize..."
    sleep 10
    
    # Show status
    docker compose ps
}

###############################################################################
# SUMMARY
###############################################################################

show_summary() {
    echo ""
    echo "================================================================"
    echo -e "${GREEN}  🎉 SETUP COMPLETE!${NC}"
    echo "================================================================"
    echo ""
    echo -e "  n8n URL: ${PURPLE}https://n8n.${DOMAIN_NAME}${NC}"
    echo -e "  Install Dir: ${PURPLE}${INSTALL_DIR}${NC}"
    echo ""
    echo "────────────────────────────────────────────"
    echo -e "${PURPLE}  🔑 Security & Access${NC}"
    echo "────────────────────────────────────────────"
    echo "  Gateway Token:     ${GATEWAY_TOKEN}"
    echo "  n8n API Key:       ${N8N_API_KEY}"
    echo "  Webhook Path:      ${N8N_WEBHOOK_PATH}"
    echo "  Webhook Secret:    ${N8N_WEBHOOK_SECRET}"
    echo ""
    echo "────────────────────────────────────────────"
    echo -e "${PURPLE}  ⚙️  Enabled Features${NC}"
    echo "────────────────────────────────────────────"
    [[ "$ENABLE_N8N_MCP" == "true" ]]       && echo -e "  ${GREEN}✓${NC} n8n MCP Server"
    [[ "$ENABLE_N8N_MCP" != "true" ]]       && echo -e "  ${RED}✗${NC} n8n MCP Server"
    [[ "$ENABLE_WATCHTOWER" == "true" ]]    && echo -e "  ${GREEN}✓${NC} Watchtower (Auto-update)"
    [[ "$ENABLE_WATCHTOWER" != "true" ]]    && echo -e "  ${RED}✗${NC} Watchtower (Auto-update)"
    [[ "$ENABLE_BACKUP" == "true" ]]        && echo -e "  ${GREEN}✓${NC} Auto Backup (Daily 3AM)"
    [[ "$ENABLE_BACKUP" != "true" ]]        && echo -e "  ${RED}✗${NC} Auto Backup"
    [[ "$ENABLE_WEB_BROWSE" == "true" ]]    && echo -e "  ${GREEN}✓${NC} Web Browsing Skill"
    [[ "$ENABLE_WEB_BROWSE" != "true" ]]    && echo -e "  ${RED}✗${NC} Web Browsing Skill"
    [[ "$ENABLE_MULTI_MODEL" == "true" ]]   && echo -e "  ${GREEN}✓${NC} Multi-model Support"
    [[ "$ENABLE_MULTI_MODEL" != "true" ]]   && echo -e "  ${RED}✗${NC} Multi-model Support"
    [[ "$ENABLE_SYSTEM_PROMPT" == "true" ]] && echo -e "  ${GREEN}✓${NC} System Prompt"
    [[ "$ENABLE_SYSTEM_PROMPT" != "true" ]] && echo -e "  ${RED}✗${NC} System Prompt"
    
    if [[ "$ENABLE_N8N_MCP" == "true" ]]; then
        echo ""
        echo "────────────────────────────────────────────"
        echo -e "${PURPLE}  🤖 MCP Server${NC}"
        echo "────────────────────────────────────────────"
        echo "  Internal: http://n8n-mcp:3000/sse"
    fi
    
    echo ""
    echo "────────────────────────────────────────────"
    echo -e "${YELLOW}  📋 ACTION REQUIRED${NC}"
    echo "────────────────────────────────────────────"
    if [[ "$N8N_API_KEY" == "REPLACE_ME_LATER" ]]; then
        echo "  1. Go to: https://n8n.${DOMAIN_NAME}"
        echo "  2. Create your n8n account"
        echo "  3. Settings > Personal API Keys > Create New"
        echo "  4. Edit: nano ${INSTALL_DIR}/.env"
        echo "  5. Replace REPLACE_ME_LATER with your key"
        echo "  6. Run: cd ${INSTALL_DIR} && docker compose up -d n8n-mcp"
    else
        echo "  n8n API Key is set. MCP should be operational."
        echo "  Verify: telegram your bot and ask it to list n8n workflows."
    fi
    
    echo ""
    echo "────────────────────────────────────────────"
    echo -e "${PURPLE}  🛠  Helper Commands${NC}"
    echo "────────────────────────────────────────────"
    if [[ "$OS" == "linux" ]]; then
        echo "  openclaw status      # View all services"
        echo "  openclaw logs        # View logs"
        echo "  openclaw restart     # Restart everything"
        echo "  openclaw features    # View feature toggles"
    else
        echo "  ${INSTALL_DIR}/openclaw.sh status"
        echo "  ${INSTALL_DIR}/openclaw.sh logs"
    fi
    
    echo ""
    echo "================================================================"
    echo -e "${RED}  ⚠️  SAVE THESE VALUES SECURELY!${NC}"
    echo "================================================================"
    echo -e "  Support: ${PURPLE}https://ai.vnrom.net${NC}"
    echo ""
}

###############################################################################
# MAIN
###############################################################################

main() {
    detect_os
    show_banner
    check_root
    collect_features
    collect_input
    generate_secrets
    install_deps
    create_dirs
    build_openclaw
    clone_n8n_mcp
    create_openclaw_config
    create_skills
    create_env_files
    create_docker_compose
    create_backup_script
    create_helper_script
    finalize
    show_summary
}

main "$@"
