#!/bin/bash

# setup.sh - Mem0 OpenMemory Docker Setup
# Supports: macOS (Apple Silicon), Raspberry Pi, VPS (amd64/arm64)
# Created by vnROM.net

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'

pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

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
echo "          Mem0 OpenMemory Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${BOLD}[1/5] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed. Install OrbStack (https://orbstack.dev)"
    fi

    if ! docker info &>/dev/null 2>&1; then
        pwn "Docker daemon not running. Starting..."
        open -a Docker 2>/dev/null || true
        echo -n "  Waiting"
        for i in {1..30}; do
            docker info &>/dev/null 2>&1 && break
            echo -n "."
            sleep 2
        done
        echo ""
        docker info &>/dev/null || perr "Docker daemon still not running."
    fi
    pok "Docker: OK"

    if ! docker compose version &> /dev/null; then
        perr "Docker Compose Plugin not found!"
    fi
    pok "Docker Compose: OK"

else
    # Linux (Pi / VPS)
    if ! command -v docker &> /dev/null; then
        pwn "Docker not found, installing..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        pok "Docker: installed"
    else
        pok "Docker: OK"
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"

    sudo apt-get install -y -qq git curl 2>/dev/null || true
    pok "System dependencies: OK"

    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    pok "RAM: ${TOTAL_MEM}MB"
    if [ "$TOTAL_MEM" -lt 2000 ]; then
        if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
            pwn "Low RAM (${TOTAL_MEM}MB). Adding 2GB swap..."
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

pok "Platform: $PLATFORM_LABEL"

# ========================================
# Step 2: Install Directory & Source
# ========================================
echo ""
echo -e "${BOLD}[2/5] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/mem0"
mkdir -p "$INSTALL_DIR"

# Copy helper files from repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pwn "Copying configs to $INSTALL_DIR ..."
    for f in .env.example mem0.sh; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/" 2>/dev/null || true
    done
fi
cd "$INSTALL_DIR"

# Clone OpenMemory source
if [ ! -d "openmemory-source" ]; then
    pwn "Cloning Mem0 OpenMemory source..."
    git clone --depth=1 https://github.com/mem0ai/mem0.git openmemory-source
    pok "OpenMemory source: cloned"
else
    pok "OpenMemory source: already exists"
fi

mkdir -p data
pok "Directories: OK"

# ========================================
# Step 3: Environment Configuration
# ========================================
echo ""
echo -e "${BOLD}[3/5] Environment configuration${NC}"

# Create api/.env
OPENMEMORY_DIR="$INSTALL_DIR/openmemory-source/openmemory"

if [ ! -f "$OPENMEMORY_DIR/api/.env" ]; then
    OPENAI_KEY="${OPENAI_API_KEY:-}"
    if [ -z "$OPENAI_KEY" ]; then
        echo ""
        echo -e "${YELLOW}OpenAI API Key is REQUIRED for Mem0 (embedding + extraction).${NC}"
        read -rp "  OpenAI API Key: " OPENAI_KEY || true
        if [ -z "${OPENAI_KEY:-}" ]; then
            perr "OpenAI API Key is required. Cannot proceed without it."
        fi
    else
        pok "Using OPENAI_API_KEY from environment"
    fi

    cat > "$OPENMEMORY_DIR/api/.env" << EOF
OPENAI_API_KEY=${OPENAI_KEY}
USER=${USER}
EOF
    pok "api/.env created"
else
    pok "api/.env already exists"
fi

# Create ui/.env
if [ ! -f "$OPENMEMORY_DIR/ui/.env" ]; then
    cat > "$OPENMEMORY_DIR/ui/.env" << EOF
NEXT_PUBLIC_API_URL=http://localhost:8765
NEXT_PUBLIC_USER_ID=${USER}
EOF
    pok "ui/.env created"
else
    pok "ui/.env already exists"
fi

pok "Configuration: OK"

# ========================================
# Step 4: Build & Deploy
# ========================================
echo ""
echo -e "${BOLD}[4/5] Building and starting containers${NC}"
pwn "Building OpenMemory from source (first build takes 3-8 min)..."
echo ""

cd "$OPENMEMORY_DIR"
NEXT_PUBLIC_USER_ID="${USER}" NEXT_PUBLIC_API_URL="http://localhost:8765" \
    docker compose up -d --build 2>&1

pok "All containers started!"

# ========================================
# Step 5: Verify & Summary
# ========================================
echo ""
echo -e "${BOLD}[5/5] Verification${NC}"

echo -n "  Waiting for Mem0 API"
MAX_WAIT=90
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf "http://localhost:8765/docs" > /dev/null 2>&1; then
        echo ""
        break
    fi
    echo -n "."
    sleep 3
    WAITED=$((WAITED + 3))
done
echo ""

ALL_OK=true

curl -sf "http://localhost:8765/docs" > /dev/null 2>&1 \
    && pok "Mem0 API: OK (port 8765)" \
    || { pwn "Mem0 API: still starting..."; ALL_OK=false; }

curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1 \
    && pok "Qdrant Vector DB: OK (port 6333)" \
    || { pwn "Qdrant: starting..."; ALL_OK=false; }

curl -sf "http://localhost:3000" > /dev/null 2>&1 \
    && pok "OpenMemory UI: OK (port 3000)" \
    || { pwn "UI: still starting (may take 30s more)"; ALL_OK=false; }

# Systemd for Linux
if [[ "$PLATFORM" != "mac" ]]; then
    COMPOSE_PATH="$OPENMEMORY_DIR/docker-compose.yml"
    sudo bash -c "cat > /etc/systemd/system/mem0.service << EOF
[Unit]
Description=Mem0 OpenMemory
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$OPENMEMORY_DIR
Environment=NEXT_PUBLIC_USER_ID=$USER
Environment=NEXT_PUBLIC_API_URL=http://localhost:8765
ExecStart=/usr/bin/docker compose -f $COMPOSE_PATH up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_PATH down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable mem0.service 2>/dev/null || true
    pok "Systemd auto-start: enabled"
fi

LAN_IP="localhost"
if [[ "$PLATFORM" != "mac" ]]; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
fi

echo ""
echo "========================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE!${NC}"
else
    echo -e "${YELLOW}  ⚠️  INSTALLATION DONE (some services still starting)${NC}"
fi
echo ""
echo -e "  Platform:       ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  Mem0 API:       ${PURPLE}http://localhost:8765${NC}"
echo -e "  API Docs:       ${PURPLE}http://localhost:8765/docs${NC}"
echo -e "  OpenMemory UI:  ${PURPLE}http://localhost:3000${NC}"
echo -e "  Qdrant:         ${PURPLE}http://localhost:6333${NC}"
if [[ "$PLATFORM" != "mac" ]]; then
    echo -e "  LAN URL:        ${PURPLE}http://${LAN_IP}:3000${NC}"
fi
echo ""
echo -e "${CYAN}MCP Integration (Claude Desktop):${NC}"
echo "  npx @openmemory/install local http://localhost:8765/mcp/claude/sse/${USER} --client claude"
echo ""
echo -e "${CYAN}MCP Integration (Cursor):${NC}"
echo "  npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/${USER} --client cursor"
echo ""
echo -e "${CYAN}Quick test:${NC}"
echo "  curl -X POST http://localhost:8765/v1/memories/ \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"messages\": [{\"role\": \"user\", \"content\": \"My name is Duy\"}]}'"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  • Start:  cd $OPENMEMORY_DIR && docker compose up -d"
echo "  • Stop:   cd $OPENMEMORY_DIR && docker compose down"
echo "  • Logs:   cd $OPENMEMORY_DIR && docker compose logs -f"
echo "  • Update: cd $INSTALL_DIR && git -C openmemory-source pull && cd $OPENMEMORY_DIR && docker compose up -d --build"
echo ""
echo "Support: https://ai.vnrom.net"
