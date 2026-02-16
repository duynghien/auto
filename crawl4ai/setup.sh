#!/bin/bash

# ============================================
# Crawl4AI Unified Setup v2.0
# Supports: macOS (Apple Silicon), Raspberry Pi, VPS (amd64/arm64)
# Created by vnROM.net
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; }

# ========================================
# Platform Detection
# ========================================
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    PLATFORM_LABEL="macOS Apple Silicon"
elif [[ "$OS" == "Linux" ]]; then
    if grep -qi 'raspberry\|raspbian' /proc/device-tree/model 2>/dev/null || \
       grep -qi 'raspberry' /etc/os-release 2>/dev/null; then
        PLATFORM="pi"
        PLATFORM_LABEL="Raspberry Pi (ARM64)"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        PLATFORM="vps-arm64"
        PLATFORM_LABEL="Linux VPS (ARM64)"
    elif [[ "$ARCH" == "x86_64" ]]; then
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux VPS (AMD64)"
    else
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux ($ARCH)"
    fi
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

# Banner
echo ""
echo "================================================================"
echo -e "${PURPLE}"
echo "      _                         _     _             "
echo "     | |                       | |   (_)            "
echo "   __| |_   _ _   _ ____   ____| |__  _ _____ ____  "
echo "  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ "
echo " ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |"
echo "  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|"
echo "             (____/      (_____|                    "
echo ""
echo "         Crawl4AI Unified Setup v2.0 — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${BOLD}[1/5] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    # macOS: Require Docker pre-installed
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed."
        echo "  Recommended: Install OrbStack (https://orbstack.dev)"
        exit 1
    fi
    pok "Docker: OK"

    if ! docker compose version &> /dev/null; then
        perr "Docker Compose Plugin not found!"
        exit 1
    fi
    pok "Docker Compose: OK"

else
    # Linux (Pi / VPS): Auto-install Docker
    if ! command -v docker &> /dev/null; then
        pwn "Docker not found, installing..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        pok "Docker: installed"
    else
        pok "Docker: OK"
    fi

    # Install Docker Compose plugin
    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"

    # Install system deps
    sudo apt-get install -y -qq build-essential libssl-dev git curl 2>/dev/null || true
    pok "System dependencies: OK"

    # Memory Check & Swap (Linux only)
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    pok "RAM: ${TOTAL_MEM}MB"
    if [ "$TOTAL_MEM" -lt 3000 ]; then
        pwn "Low RAM (< 3GB). Crawl4AI handles heavy workloads."
        if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
            pwn "Adding 2GB swap file..."
            sudo fallocate -l 2G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
            pok "Swap: 2GB added"
        else
            pok "Swap: already configured"
        fi
    fi
fi

# ========================================
# Step 2: Install Directory
# ========================================
echo ""
echo -e "${BOLD}[2/5] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/crawl4ai"
mkdir -p "$INSTALL_DIR"

if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pok "Copying configs to $INSTALL_DIR ..."
    for f in docker-compose.yml .env .env.example .llm.env .llm.env.example config.yml c4ai.sh docker-entrypoint.sh; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/"
    done
fi
cd "$INSTALL_DIR"

# ========================================
# Step 3: Configuration (Wait for User Input)
# ========================================
echo ""
echo -e "${BOLD}[3/5] Configuring environment${NC}"

# .env setup
if [ ! -f .env ]; then
    cp .env.example .env
    pok "Created .env from template"

    # Auto-adjust memory limits for Linux
    if [[ "$PLATFORM" != "mac" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 4000 ]; then
            # < 4GB RAM
            sed -i "s/^C4AI_MEMORY_LIMIT=.*/C4AI_MEMORY_LIMIT=2G/" .env
            sed -i "s/^C4AI_MEMORY_RESERVE=.*/C4AI_MEMORY_RESERVE=512M/" .env
            pok "Memory limits adjusted for low RAM"
        elif [ "$TOTAL_MEM" -lt 8000 ]; then
            # 4-8GB RAM
            sed -i "s/^C4AI_MEMORY_LIMIT=.*/C4AI_MEMORY_LIMIT=4G/" .env
            sed -i "s/^C4AI_MEMORY_RESERVE=.*/C4AI_MEMORY_RESERVE=1G/" .env
            pok "Memory limits adjusted for medium RAM"
        fi
        
        # Pi optimization: use default install type (no heavy torch/transformers)
        if [[ "$PLATFORM" == "pi" ]]; then
            sed -i "s/^INSTALL_TYPE=.*/INSTALL_TYPE=default/" .env
            pok "optimized for Pi (default install type)"
        fi
    fi
else
    pok ".env already exists"
fi

# .llm.env setup
if [ ! -f .llm.env ]; then
    cp .llm.env.example .llm.env
    pok "Created .llm.env template"
    
    echo ""
    echo -e "${YELLOW}Optional: Add LLM API keys for AI extraction.${NC}"
    echo "Press Enter to skip."
    
    read -p "openai_api_key: " OPENAI_KEY
    if [ -n "$OPENAI_KEY" ]; then
        if [[ "$PLATFORM" == "mac" ]]; then
            sed -i '' "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=${OPENAI_KEY}/" .llm.env
        else
            sed -i "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=${OPENAI_KEY}/" .llm.env
        fi
        pok "OpenAI Key saved"
    fi

    read -p "anthropic_api_key: " ANTHROPIC_KEY
    if [ -n "$ANTHROPIC_KEY" ]; then
        if [[ "$PLATFORM" == "mac" ]]; then
            sed -i '' "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=${ANTHROPIC_KEY}/" .llm.env
        else
            sed -i "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=${ANTHROPIC_KEY}/" .llm.env
        fi
        pok "Anthropic Key saved"
    fi
else
    pok ".llm.env already exists"
fi

# ========================================
# Step 4: Deploy
# ========================================
echo ""
echo -e "${BOLD}[4/5] Deploying...${NC}"

# Ask for build mode only on capable machines (Mac/VPS-AMD64)
# Pi usually prefers pre-built to save time, but we can offer choice if user wants
# For simplicity and speed, let's default to image pull unless user explicitly wants to build.
# Mac Script offered choice. Let's keep it simple: defaulting to Pull image.

echo -e "  ${GREEN}1)${NC} Pull Official Image (Recommended)"
echo -e "  ${YELLOW}2)${NC} Build from Source (Advanced)"
read -p "Choose [1]: " SETUP_MODE
SETUP_MODE=${SETUP_MODE:-1}

if [ "$SETUP_MODE" = "2" ]; then
    pwn "Building from source..."
    if [ ! -d "crawl4ai-source" ]; then
        git clone https://github.com/unclecode/crawl4ai.git crawl4ai-source
    else
        git -C crawl4ai-source pull || true
    fi
    INSTALL_TYPE=default docker compose up -d --build
else
    pok "Pulling pre-built image..."
    docker compose pull
    docker compose up -d
fi

# ========================================
# Step 5: Service & Finish
# ========================================
echo ""
echo -e "${BOLD}[5/5] Finishing up${NC}"

# Systemd Service for Linux
if [[ "$PLATFORM" != "mac" ]]; then
    pwn "Setting up auto-start service..."
    COMPOSE_PATH="$INSTALL_DIR/docker-compose.yml"
    sudo bash -c "cat > /etc/systemd/system/crawl4ai.service << EOF
[Unit]
Description=Crawl4AI Web Crawler
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose -f $COMPOSE_PATH up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_PATH down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable crawl4ai.service
    pok "Systemd service enabled"
fi

# Wait for Health
echo ""
echo -e "${BOLD}Waiting for Crawl4AI to start...${NC}"
MAX_WAIT=90
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf http://localhost:11235/health > /dev/null 2>&1; then
        break
    fi
    sleep 3
    WAITED=$((WAITED + 3))
    echo -ne "\r  Waiting... (${WAITED}s/${MAX_WAIT}s)"
done
echo ""

PORT=$(grep -E "^C4AI_PORT=" .env 2>/dev/null | cut -d= -f2 || echo "11235")
LAN_IP="localhost"
if [[ "$PLATFORM" != "mac" ]]; then
    LAN_IP=$(hostname -I | awk '{print $1}')
fi

echo ""
echo -e "${GREEN}=== INSTALLATION COMPLETE ===${NC}"
echo -e "  Platform:   ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  API:        ${PURPLE}http://localhost:${PORT}${NC}"
echo -e "  Dashboard:  ${PURPLE}http://localhost:${PORT}/dashboard${NC}"
echo -e "  MCP SSE:    ${PURPLE}http://localhost:${PORT}/mcp/sse${NC}"
if [[ "$PLATFORM" != "mac" ]]; then
    echo -e "  LAN URL:    ${PURPLE}http://${LAN_IP}:${PORT}${NC}"
fi
echo ""
echo -e "${YELLOW}Manage:${NC} ./c4ai.sh [start|stop|logs|test]"
echo "Support: https://ai.vnrom.net"
