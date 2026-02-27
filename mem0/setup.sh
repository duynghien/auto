#!/bin/bash

# setup.sh - Mem0 OpenMemory Docker Setup (Optimal Stack)
# Stack: Qdrant + Neo4j Graph Memory + FastAPI + Next.js UI
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
echo "       Mem0 OpenMemory Setup — $PLATFORM_LABEL"
echo "       Stack: Qdrant + Neo4j + FastAPI + Next.js"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${BOLD}[1/7] System Check${NC}"

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
echo -e "${BOLD}[2/7] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/mem0"
mkdir -p "$INSTALL_DIR"

# Always update mem0.sh helper; keep .env.example as no-clobber
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pwn "Copying configs to $INSTALL_DIR ..."
    [[ -f "$SCRIPT_DIR/.env.example" ]] && cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/" 2>/dev/null || true
    [[ -f "$SCRIPT_DIR/mem0.sh" ]] && cp "$SCRIPT_DIR/mem0.sh" "$INSTALL_DIR/" 2>/dev/null || true
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
echo -e "${BOLD}[3/7] Environment configuration${NC}"

OPENMEMORY_DIR="$INSTALL_DIR/openmemory-source/openmemory"
NEO4J_PASSWORD="mem0_neo4j_pass"

# Create root .env
ENV_FILE="$INSTALL_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    cp "$INSTALL_DIR/.env.example" "$ENV_FILE"
    pok "Created fresh .env from template"
else
    pok "Using existing .env file"
fi

# Load existing values
source "$ENV_FILE" 2>/dev/null || true

# Check OPENAI_API_KEY
if [ -z "${OPENAI_API_KEY:-}" ] || echo "$OPENAI_API_KEY" | grep -q 'sk-xxx'; then
    echo ""
    echo -e "${YELLOW}OpenAI API Key is REQUIRED for Mem0 (embedding + extraction).${NC}"
    read -rp "  OpenAI API Key: " NEW_OPENAI_KEY || true
    if [ -z "${NEW_OPENAI_KEY:-}" ]; then
        perr "OpenAI API Key is required. Cannot proceed without it."
    fi
    if ! grep -q "^OPENAI_API_KEY=" "$ENV_FILE"; then echo "OPENAI_API_KEY=$NEW_OPENAI_KEY" >> "$ENV_FILE"; else awk -v key="OPENAI_API_KEY" -v val="$NEW_OPENAI_KEY" -F'=' 'BEGIN{OFS="="} $1==key {$2=val} {print}' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"; fi
    if ! grep -q "^API_KEY=" "$ENV_FILE"; then echo "API_KEY=$NEW_OPENAI_KEY" >> "$ENV_FILE"; else awk -v key="API_KEY" -v val="$NEW_OPENAI_KEY" -F'=' 'BEGIN{OFS="="} $1==key {$2=val} {print}' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"; fi
    export OPENAI_API_KEY="$NEW_OPENAI_KEY"
    export API_KEY="$NEW_OPENAI_KEY"
    pok "Saved OpenAI API Key"
fi

# Check UI_PORT
if [ "${UI_PORT:-3000}" = "3000" ]; then
    echo ""
    echo -e "${YELLOW}OpenMemory UI port (default: 3000, press Enter to keep):${NC}"
    read -rp "  UI Port [3000]: " UI_PORT_INPUT || true
    NEW_UI_PORT="${UI_PORT_INPUT:-3000}"
    if ! echo "$NEW_UI_PORT" | grep -qE '^[0-9]+$' || [ "$NEW_UI_PORT" -lt 1024 ] || [ "$NEW_UI_PORT" -gt 65535 ]; then
        pwn "Invalid port '$NEW_UI_PORT', keeping 3000"
        NEW_UI_PORT=3000
    fi
    if [ "$NEW_UI_PORT" != "3000" ] || ! grep -q "^UI_PORT=" "$ENV_FILE"; then
        if ! grep -q "^UI_PORT=" "$ENV_FILE"; then echo "UI_PORT=$NEW_UI_PORT" >> "$ENV_FILE"; else awk -v key="UI_PORT" -v val="$NEW_UI_PORT" -F'=' 'BEGIN{OFS="="} $1==key {$2=val} {print}' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"; fi
        pok "UI Port set to $NEW_UI_PORT"
        export UI_PORT="$NEW_UI_PORT"
    fi
fi

# Cleanup legacy config files
rm -f "$INSTALL_DIR/.ui_port" "$OPENMEMORY_DIR/api/.env" "$OPENMEMORY_DIR/ui/.env" 2>/dev/null || true

pok "Configuration: OK"

# ========================================
# Step 4: Generate Optimized docker-compose.yml
# ========================================
echo ""
echo -e "${BOLD}[4/7] Generating optimized Docker Compose${NC}"

cat > "$OPENMEMORY_DIR/docker-compose.yml" << 'COMPOSEOF'
services:
  mem0_store:
    image: qdrant/qdrant:latest
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - mem0_qdrant_data:/qdrant/storage

  neo4j:
    image: neo4j:5
    restart: unless-stopped
    environment:
      - NEO4J_AUTH=neo4j/${NEO4J_PASSWORD:-mem0_neo4j_pass}
      - NEO4J_PLUGINS=["apoc"]
      - NEO4J_server_memory_heap_initial__size=256m
      - NEO4J_server_memory_heap_max__size=512m
      - NEO4J_server_memory_pagecache_size=128m
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - mem0_neo4j_data:/data
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p ${NEO4J_PASSWORD:-mem0_neo4j_pass} 'RETURN 1' || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 30s

  openmemory-mcp:
    image: mem0/openmemory-mcp
    build: api/
    restart: unless-stopped
    env_file:
      - ../../.env
    depends_on:
      mem0_store:
        condition: service_started
      neo4j:
        condition: service_healthy
    ports:
      - "8765:8765"
    volumes:
      - ./api:/usr/src/openmemory
    command: >
      sh -c "uvicorn main:app --host 0.0.0.0 --port 8765 --reload --workers 4"
    healthcheck:
      test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8765/docs')\" || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 8
      start_period: 30s

  openmemory-ui:
    build:
      context: ui/
      dockerfile: Dockerfile
    image: mem0/openmemory-ui:latest
    restart: unless-stopped
    env_file:
      - ../../.env
    ports:
      - "${UI_PORT:-3000}:3000"
    depends_on:
      openmemory-mcp:
        condition: service_healthy

volumes:
  mem0_qdrant_data:
  mem0_neo4j_data:
COMPOSEOF

pok "docker-compose.yml generated (Qdrant + Neo4j + API + UI)"

# ========================================
# Step 5: Build & Deploy
# ========================================
echo ""
echo -e "${BOLD}[5/7] Building and starting containers${NC}"
pwn "Building OpenMemory from source (first build takes 3-8 min)..."
echo ""

cd "$OPENMEMORY_DIR"

# Export all env vars for docker-compose.yml and systemd
set -a
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
set +a

# Disable strict error mode for docker compose and post-deploy
# (build output on stderr + pip warnings are non-fatal)
set +euo pipefail

docker compose up -d --build
COMPOSE_EXIT=$?

if [ $COMPOSE_EXIT -ne 0 ]; then
    perr "Docker Compose failed (exit code: $COMPOSE_EXIT). Check Docker/network and retry."
fi

# Double-check: verify at least API container exists
if ! docker compose ps --format '{{.Service}}' 2>/dev/null | grep -q 'openmemory-mcp'; then
    perr "Containers did not start. Run 'docker compose up -d --build' manually to debug."
fi

pok "All containers started!"

# ========================================
# Step 6: Post-deploy setup
# ========================================
echo ""
echo -e "${BOLD}[6/7] Post-deploy configuration${NC}"

# Wait for API container to be ready
echo -n "  Waiting for API container"
for i in {1..45}; do
    if docker exec openmemory-openmemory-mcp-1 python -c "import sys; print('ready')" >/dev/null 2>&1; then
        echo ""
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Install qdrant-client inside the API container (required for vector storage)
pwn "Installing qdrant-client + neo4j driver in API container..."
docker exec openmemory-openmemory-mcp-1 pip install "qdrant-client>=1.9.1" "neo4j>=5.0.0" --quiet 2>&1 || {
    pwn "Package install warning (may already be present)"
}
pok "qdrant-client + neo4j: installed"

# Restart API to pick up the new packages
docker compose restart openmemory-mcp 2>&1
pok "API restarted with new packages"

# Wait for API to come back
echo -n "  Waiting for API"
for i in {1..30}; do
    if curl -sf "http://localhost:8765/docs" > /dev/null 2>&1; then
        echo ""
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Seed Graph Store configuration directly into DB
# (API's ConfigSchema doesn't include graph_store, so we bypass it)
echo "  Configuring Neo4j Graph Store..."
NEO4J_PW=$(grep '^NEO4J_PASSWORD=' "$OPENMEMORY_DIR/api/.env" 2>/dev/null | cut -d= -f2- || echo "mem0_neo4j_pass")

SEED_RESULT=$(docker exec openmemory-openmemory-mcp-1 python -c "
from app.database import SessionLocal
from app.models import Config as ConfigModel
import json, os

db = SessionLocal()
config = db.query(ConfigModel).filter(ConfigModel.key == 'main').first()
if config:
    cfg = config.value
    if 'mem0' not in cfg:
        cfg['mem0'] = {}
    cfg['mem0']['vector_store'] = {
        'provider': 'qdrant',
        'config': {'collection_name': 'openmemory', 'host': 'mem0_store', 'port': 6333}
    }
    cfg['mem0']['graph_store'] = {
        'provider': 'neo4j',
        'config': {
            'url': os.environ.get('NEO4J_URI', 'bolt://neo4j:7687'),
            'username': os.environ.get('NEO4J_USERNAME', 'neo4j'),
            'password': os.environ.get('NEO4J_PASSWORD', '${NEO4J_PW}')
        }
    }
    config.value = cfg
    db.commit()
    print('OK')
else:
    print('NO_CONFIG')
db.close()
" 2>&1)

if echo "$SEED_RESULT" | grep -q 'OK'; then
    pok "Graph Store (Neo4j): configured in DB"
else
    pwn "Graph Store config seeding issue"
    echo "  Result: ${SEED_RESULT:-empty}" | head -3
fi

# ========================================
# Step 7: Verify & Summary
# ========================================
echo ""
echo -e "${BOLD}[7/7] Verification${NC}"

echo -n "  Waiting for all services"
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf "http://localhost:8765/docs" > /dev/null 2>&1 && \
       curl -sf "http://localhost:6333/healthz" > /dev/null 2>&1; then
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

curl -sf "http://localhost:7474" > /dev/null 2>&1 \
    && pok "Neo4j Graph DB: OK (port 7474)" \
    || { pwn "Neo4j: starting (may take 30s more)"; ALL_OK=false; }

curl -sf "http://localhost:${UI_PORT:-3000}" > /dev/null 2>&1 \
    && pok "OpenMemory UI: OK (port ${UI_PORT:-3000})" \
    || { pwn "UI: still starting..."; ALL_OK=false; }

# Verify packages inside container
if docker exec openmemory-openmemory-mcp-1 python -c "import qdrant_client" 2>/dev/null; then
    pok "qdrant-client: available"
else
    pwn "qdrant-client: not found"
    ALL_OK=false
fi

if docker exec openmemory-openmemory-mcp-1 python -c "import neo4j" 2>/dev/null; then
    pok "neo4j driver: available"
else
    pwn "neo4j driver: not found"
    ALL_OK=false
fi

# Systemd for Linux
if [[ "$PLATFORM" != "mac" ]]; then
    COMPOSE_PATH="$OPENMEMORY_DIR/docker-compose.yml"
    sudo bash -c "cat > /etc/systemd/system/mem0.service << EOF
[Unit]
Description=Mem0 OpenMemory (Qdrant + Neo4j)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$OPENMEMORY_DIR
Environment=NEO4J_PASSWORD=$NEO4J_PASSWORD
Environment=UI_PORT=$UI_PORT
ExecStart=/usr/bin/docker compose -f $COMPOSE_PATH up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_PATH down
TimeoutStartSec=180

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
echo -e "  OpenMemory UI:  ${PURPLE}http://localhost:${UI_PORT}${NC}"
echo -e "  Qdrant:         ${PURPLE}http://localhost:6333${NC}"
echo -e "  Neo4j Browser:  ${PURPLE}http://localhost:7474${NC}"
if [[ "$PLATFORM" != "mac" ]]; then
    echo -e "  LAN URL:        ${PURPLE}http://${LAN_IP}:${UI_PORT}${NC}"
fi
echo ""
echo -e "${CYAN}Stack:${NC}"
echo "  • Qdrant — Vector semantic search"
echo "  • Neo4j — Entity relationship graph"
echo "  • FastAPI — Memory API + MCP server"
echo "  • Next.js — Dashboard UI"
echo ""
echo -e "${CYAN}MCP Integration (Claude Desktop):${NC}"
echo "  npx @openmemory/install local http://localhost:8765/mcp/claude/sse/${USER} --client claude"
echo ""
echo -e "${CYAN}MCP Integration (Cursor):${NC}"
echo "  npx @openmemory/install local http://localhost:8765/mcp/cursor/sse/${USER} --client cursor"
echo ""
echo -e "${CYAN}Quick test:${NC}"
echo "  curl -X POST http://localhost:8765/api/v1/memories/ \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"user_id\": \"${USER}\", \"text\": \"My name is Duy\"}'"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  • Start:  ~/self-hosted/mem0/mem0.sh start"
echo "  • Stop:   ~/self-hosted/mem0/mem0.sh stop"
echo "  • Status: ~/self-hosted/mem0/mem0.sh status"
echo "  • Logs:   ~/self-hosted/mem0/mem0.sh logs"
echo "  • Purge:  ~/self-hosted/mem0/mem0.sh purge  (⚠️ removes all data)"
echo ""
echo "Support: https://ai.vnrom.net"
