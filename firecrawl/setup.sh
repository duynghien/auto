#!/bin/bash

# setup.sh - FireCrawl Docker Setup
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
echo "  ______ _           ____                       _ "
echo " |  ____(_)         / ___|_ __ __ ___      ____| |"
echo " | |__   _ _ __ ___| |   | '__/ _\` \ \ /\ / / _\` |"
echo " |  __| | | '__/ _ \ |   | | | (_| |\ V  V / (_| |"
echo " | |    | | | |  __/ |___| |  \__,_| \_/\_/ \__,_|"
echo " |_|    |_|_|  \___|\____|_|                      "
echo ""
echo "            FireCrawl Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${BOLD}[1/5] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed."
        echo "  Recommended: Install OrbStack (https://orbstack.dev)"
        echo "  Or Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        exit 1
    fi

    # Ensure Docker daemon is running
    if ! docker info &>/dev/null 2>&1; then
        pwn "Docker daemon not running. Starting Docker Desktop..."
        open -a Docker 2>/dev/null || true
        echo -n "  Waiting"
        for i in {1..30}; do
            docker info &>/dev/null 2>&1 && break
            echo -n "."
            sleep 2
        done
        echo ""
        docker info &>/dev/null || perr "Docker daemon still not running. Start it manually."
    fi
    pok "Docker: OK"

    if ! docker compose version &> /dev/null; then
        perr "Docker Compose Plugin not found!"
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

    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"

    sudo apt-get install -y -qq git curl openssl 2>/dev/null || true
    pok "System dependencies: OK"

    # Memory check & swap
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    pok "RAM: ${TOTAL_MEM}MB"
    if [ "$TOTAL_MEM" -lt 3000 ]; then
        if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
            pwn "Low RAM (${TOTAL_MEM}MB). Adding 4GB swap for FireCrawl build..."
            sudo fallocate -l 4G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
            pok "Swap: 4GB added"
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
INSTALL_DIR="$HOME/self-hosted/firecrawl"
mkdir -p "$INSTALL_DIR"

# Copy config files from repo to install dir
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pwn "Copying configs to $INSTALL_DIR ..."
    for f in .env .env.example fc.sh; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/" 2>/dev/null || true
    done
fi
cd "$INSTALL_DIR"

# Clone FireCrawl source (required for build)
if [ ! -d "firecrawl-source" ]; then
    pwn "Cloning FireCrawl source code..."
    git clone --depth=1 https://github.com/mendableai/firecrawl.git firecrawl-source
    pok "FireCrawl source: cloned"
else
    pok "FireCrawl source: already exists (use 'git pull' in firecrawl-source/ to update)"
fi

# Create data directory
mkdir -p data
pok "Directories: OK"

# ========================================
# Step 3: Environment Configuration
# ========================================
echo ""
echo -e "${BOLD}[3/5] Environment configuration${NC}"

if [ ! -f .env ]; then
    BULL_AUTH_KEY=$(openssl rand -hex 16)
    POSTGRES_PASSWORD=$(openssl rand -hex 12)

    cat > .env << EOF
# ===== FireCrawl Self-hosted Configuration =====
PORT=3002
HOST=0.0.0.0

# Disable DB authentication (no Supabase needed)
USE_DB_AUTHENTICATION=false

# Queue admin panel password — change this!
BULL_AUTH_KEY=${BULL_AUTH_KEY}

# PostgreSQL — uses default 'postgres' user/db (required by nuq.sql init scripts)
# WARNING: Do not change POSTGRES_USER or POSTGRES_DB — the nuq schema is created
# in the default 'postgres' database by the nuq-postgres init scripts.
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres

# AI features (optional — leave blank to disable)
OPENAI_API_KEY=
# OPENAI_BASE_URL=https://api.openai.com/v1
# MODEL_NAME=gpt-4o-mini

# Proxy (optional)
# PROXY_SERVER=
# PROXY_USERNAME=
# PROXY_PASSWORD=

# Performance tuning (adjust based on your server)
NUM_WORKERS_PER_QUEUE=4
CRAWL_CONCURRENT_REQUESTS=5
MAX_CONCURRENT_JOBS=3
BROWSER_POOL_SIZE=3

# Logging
LOGGING_LEVEL=INFO
EOF
    pok ".env created with secure passwords"
    echo ""
    echo -e "  Bull Auth Key:    ${YELLOW}${BULL_AUTH_KEY}${NC}"
    echo -e "  Postgres Password: ${YELLOW}${POSTGRES_PASSWORD}${NC}"
    echo ""

    # Offer OpenAI key input
    echo -e "${YELLOW}Optional: Add OpenAI API key for AI extraction features.${NC}"
    echo "Press Enter to skip."
    read -rp "  OpenAI API Key: " OPENAI_KEY || true
    if [ -n "${OPENAI_KEY:-}" ]; then
        if [[ "$PLATFORM" == "mac" ]]; then
            sed -i '' "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=${OPENAI_KEY}/" .env
        else
            sed -i "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=${OPENAI_KEY}/" .env
        fi
        pok "OpenAI API Key saved"
    fi
else
    pok ".env already exists (keeping existing config)"
fi

# Generate docker-compose.yml pointing to source
cat > docker-compose.yml << 'COMPOSEOF'
name: firecrawl

x-common-service: &common-service
  build: ./firecrawl-source/apps/api
  restart: unless-stopped
  networks:
    - backend
  extra_hosts:
    - "host.docker.internal:host-gateway"
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
      compress: "true"

x-common-env: &common-env
  REDIS_URL: redis://redis:6379
  REDIS_RATE_LIMIT_URL: redis://redis:6379
  PLAYWRIGHT_MICROSERVICE_URL: http://playwright-service:3000/scrape
  POSTGRES_USER: ${POSTGRES_USER:-firecrawl}
  POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-firecrawl_pass}"
  POSTGRES_DB: ${POSTGRES_DB:-firecrawl}
  POSTGRES_HOST: nuq-postgres
  POSTGRES_PORT: 5432
  USE_DB_AUTHENTICATION: ${USE_DB_AUTHENTICATION:-false}
  NUM_WORKERS_PER_QUEUE: ${NUM_WORKERS_PER_QUEUE:-4}
  CRAWL_CONCURRENT_REQUESTS: ${CRAWL_CONCURRENT_REQUESTS:-5}
  MAX_CONCURRENT_JOBS: ${MAX_CONCURRENT_JOBS:-3}
  BROWSER_POOL_SIZE: ${BROWSER_POOL_SIZE:-3}
  OPENAI_API_KEY: ${OPENAI_API_KEY:-}
  OPENAI_BASE_URL: ${OPENAI_BASE_URL:-}
  MODEL_NAME: ${MODEL_NAME:-}
  OLLAMA_BASE_URL: ${OLLAMA_BASE_URL:-}
  BULL_AUTH_KEY: ${BULL_AUTH_KEY:-changeme}
  NUQ_RABBITMQ_URL: amqp://rabbitmq:5672
  WORKER_PORT: ${WORKER_PORT:-3005}
  EXTRACT_WORKER_PORT: ${EXTRACT_WORKER_PORT:-3004}
  LOGGING_LEVEL: ${LOGGING_LEVEL:-INFO}
  PROXY_SERVER: ${PROXY_SERVER:-}
  PROXY_USERNAME: ${PROXY_USERNAME:-}
  PROXY_PASSWORD: ${PROXY_PASSWORD:-}

services:
  playwright-service:
    build: ./firecrawl-source/apps/playwright-service-ts
    restart: unless-stopped
    environment:
      PORT: 3000
      PROXY_SERVER: ${PROXY_SERVER:-}
      PROXY_USERNAME: ${PROXY_USERNAME:-}
      PROXY_PASSWORD: ${PROXY_PASSWORD:-}
      MAX_CONCURRENT_PAGES: ${CRAWL_CONCURRENT_REQUESTS:-5}
    networks:
      - backend
    mem_limit: 2G
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"

  api:
    <<: *common-service
    environment:
      <<: *common-env
      HOST: "0.0.0.0"
      PORT: ${PORT:-3002}
      ENV: local
    depends_on:
      redis:
        condition: service_started
      playwright-service:
        condition: service_started
      rabbitmq:
        condition: service_healthy
      nuq-postgres:
        condition: service_healthy
    ports:
      - "${PORT:-3002}:${PORT:-3002}"
    command: node dist/src/harness.js --start-docker
    mem_limit: 4G

  redis:
    image: redis:alpine
    restart: unless-stopped
    networks:
      - backend
    command: redis-server --bind 0.0.0.0
    volumes:
      - redis_data:/data
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
        compress: "true"

  rabbitmq:
    image: rabbitmq:3-management
    restart: unless-stopped
    networks:
      - backend
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "check_running"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
        compress: "true"

  nuq-postgres:
    build: ./firecrawl-source/apps/nuq-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres_pass}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
    networks:
      - backend
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      # Wait for nuq schema to be initialized (nuq.sql runs AFTER pg_isready)
      test: ["CMD-SHELL", "psql -U postgres -d postgres -c 'SELECT 1 FROM nuq.queue_scrape LIMIT 1' > /dev/null 2>&1"]
      interval: 5s
      timeout: 10s
      retries: 30
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"

networks:
  backend:
    driver: bridge

volumes:
  redis_data:
  postgres_data:
COMPOSEOF
pok "docker-compose.yml: generated"

# ========================================
# Step 4: Build & Deploy
# ========================================
echo ""
echo -e "${BOLD}[4/5] Building and starting containers${NC}"
pwn "Building FireCrawl from source (first build takes 5-15 min)..."
echo ""

docker compose up -d --build 2>&1

pok "All containers started!"

# ========================================
# Step 5: Verify & Summary
# ========================================
echo ""
echo -e "${BOLD}[5/5] Verification${NC}"

# Wait for API to be ready
PORT_VAL=$(grep -E "^PORT=" .env 2>/dev/null | cut -d= -f2 || echo "3002")
echo -n "  Waiting for FireCrawl API"
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf "http://localhost:${PORT_VAL}/health" > /dev/null 2>&1; then
        echo ""
        break
    fi
    echo -n "."
    sleep 3
    WAITED=$((WAITED + 3))
done
echo ""

ALL_OK=true
docker exec "$(docker compose ps -q redis 2>/dev/null | head -1)" redis-cli ping &>/dev/null \
    && pok "Redis: OK" \
    || { pwn "Redis: starting..."; ALL_OK=false; }

curl -sf "http://localhost:${PORT_VAL}/health" > /dev/null 2>&1 \
    && pok "FireCrawl API: OK" \
    || { pwn "FireCrawl API: still starting (check logs)"; ALL_OK=false; }

# Systemd service for Linux
if [[ "$PLATFORM" != "mac" ]]; then
    COMPOSE_PATH="$INSTALL_DIR/docker-compose.yml"
    sudo bash -c "cat > /etc/systemd/system/firecrawl.service << EOF
[Unit]
Description=FireCrawl Web Scraper
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose -f $COMPOSE_PATH up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_PATH down
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl daemon-reload
    sudo systemctl enable firecrawl.service 2>/dev/null || true
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
echo -e "  Platform:      ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  FireCrawl API: ${PURPLE}http://localhost:${PORT_VAL}${NC}"
echo -e "  Queue Admin:   ${PURPLE}http://localhost:${PORT_VAL}/admin/queues${NC}"
if [[ "$PLATFORM" != "mac" ]]; then
    echo -e "  LAN URL:       ${PURPLE}http://${LAN_IP}:${PORT_VAL}${NC}"
fi
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  • Credentials are in .env — DO NOT share!"
echo "  • Path: $INSTALL_DIR/.env"
echo ""
echo -e "${CYAN}Quick test:${NC}"
echo "  curl http://localhost:${PORT_VAL}/v1/health"
echo "  curl -X POST http://localhost:${PORT_VAL}/v1/scrape \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"url\": \"https://example.com\", \"formats\": [\"markdown\"]}'"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  • Start:   cd $INSTALL_DIR && docker compose up -d"
echo "  • Stop:    cd $INSTALL_DIR && docker compose down"
echo "  • Logs:    cd $INSTALL_DIR && docker compose logs -f api"
echo "  • Update:  cd $INSTALL_DIR && git -C firecrawl-source pull && docker compose up -d --build"
echo ""
echo "Support: https://ai.vnrom.net"
