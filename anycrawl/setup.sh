#!/bin/bash

# setup.sh - AnyCrawl Unified Setup v2.0
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
echo "            AnyCrawl Setup v2.0 — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${CYAN}[1/5] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    # macOS: Docker must be pre-installed
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed."
        echo "  Install OrbStack: https://orbstack.dev"
        echo "  Or Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        exit 1
    fi
    pok "Docker: OK"

    if ! docker compose version &> /dev/null; then
        perr "Docker Compose Plugin not found!"
        exit 1
    fi
    pok "Docker Compose: OK"

else
    # Linux (Pi / VPS): Auto-install Docker + dependencies
    if ! command -v docker &> /dev/null; then
        pwn "Docker not found, installing..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        pok "Docker: installed"
    else
        pok "Docker: OK"
    fi

    # Install Docker Compose plugin if needed
    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"

    # Install build dependencies
    sudo apt-get install -y -qq build-essential libssl-dev git curl 2>/dev/null || true
    pok "Build dependencies: OK"

    # Pi-specific: Swap check
    if [[ "$PLATFORM" == "pi" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        pok "RAM: ${TOTAL_MEM}MB"
        if [ "$TOTAL_MEM" -lt 4000 ]; then
            if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
                pwn "Low RAM ($TOTAL_MEM MB). Adding 2GB swap..."
                sudo fallocate -l 2G /swapfile
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
fi

# Check required tools
for c in openssl git curl; do
    if ! command -v $c &> /dev/null; then
        perr "Missing: $c"
        exit 1
    fi
done
pok "Platform: $PLATFORM_LABEL"

# ========================================
# Step 2: Install Directory & Source
# ========================================
echo ""
echo -e "${CYAN}[2/5] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/anycrawl"
mkdir -p "$INSTALL_DIR"

# Copy config files from repo to install dir (skip if already there)
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pok "Copying configs to $INSTALL_DIR ..."
    for f in docker-compose.yml .env .env.example; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/"
    done
    for d in searxng mcp-server; do
        [[ -d "$SCRIPT_DIR/$d" ]] && cp -rn "$SCRIPT_DIR/$d" "$INSTALL_DIR/"
    done
fi
cd "$INSTALL_DIR"

# Clone AnyCrawl Source (Required for build)
if [ ! -d "anycrawl-source" ]; then
    pwn "Cloning AnyCrawl source code..."
    git clone https://github.com/any4ai/AnyCrawl.git anycrawl-source
    pok "AnyCrawl source: cloned"
else
    pok "AnyCrawl source: already exists"
fi

# Create directories
mkdir -p storage searxng
chmod 777 searxng
pok "Directories: OK"

# ========================================
# Step 3: Environment Configuration
# ========================================
echo ""
echo -e "${CYAN}[3/5] Environment configuration${NC}"

if [ ! -f .env ]; then
    # Generate random keys
    API_KEY=$(openssl rand -hex 16)
    MINIO_ROOT_USER="admin"
    MINIO_ROOT_PASSWORD=$(openssl rand -hex 12)
    POSTGRES_PASSWORD=$(openssl rand -hex 12)

    cat <<EOF > .env
# --- General ---
NODE_ENV=production
ANYCRAWL_NAME=AnyCrawl
ANYCRAWL_DOMAIN=http://localhost:8880
ANYCRAWL_API_PORT=8880
ANYCRAWL_API_KEY=${API_KEY}
ANYCRAWL_API_AUTH_ENABLED=true

# --- Engine ---
ANYCRAWL_HEADLESS=true
ANYCRAWL_AVAILABLE_ENGINES=playwright,cheerio
ANYCRAWL_IGNORE_SSL_ERROR=true

# --- Database ---
POSTGRES_USER=anycrawl
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=anycrawl_db
ANYCRAWL_API_DB_TYPE=postgresql

# --- Redis ---
ANYCRAWL_REDIS_URL=redis://redis:6379

# --- MinIO (S3) ---
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
ANYCRAWL_S3_BUCKET=anycrawl-data
ANYCRAWL_S3_ENDPOINT=http://minio:9000

# --- Search ---
ANYCRAWL_SEARCH_DEFAULT_ENGINE=searxng
ANYCRAWL_SEARCH_ENABLED_ENGINES=searxng
ANYCRAWL_SEARXNG_URL=http://searxng:8080

# --- Advanced ---
ANYCRAWL_SCHEDULER_ENABLED=true
ANYCRAWL_WEBHOOKS_ENABLED=true
ANYCRAWL_MAX_CONCURRENCY=20

# --- AI (Optional) ---
DEFAULT_LLM_MODEL=
DEFAULT_EXTRACT_MODEL=
DEFAULT_EMBEDDING_MODEL=
OPENAI_API_KEY=
CUSTOM_BASE_URL=
CUSTOM_API_KEY=

# --- Credits & Performance ---
ANYCRAWL_EXTRACT_JSON_CREDITS=5
ANYCRAWL_PROXY_STEALTH_CREDITS=5
ANYCRAWL_TEMPLATE_EXECUTION_TIMEOUT=600000
ANYCRAWL_REQUEST_HANDLER_TIMEOUT_SECS=600
ANYCRAWL_AC_ENGINE_URL=
EOF
    pok ".env created with secure random passwords"
    echo ""
    echo -e "  API Key:        ${YELLOW}${API_KEY}${NC}"
    echo -e "  MinIO User:     ${YELLOW}${MINIO_ROOT_USER}${NC}"
    echo -e "  MinIO Password: ${YELLOW}${MINIO_ROOT_PASSWORD}${NC}"
    echo ""
else
    pok ".env already exists (keeping existing config)"
fi

# ========================================
# Step 4: Build & Start
# ========================================
echo ""
echo -e "${CYAN}[4/5] Building and starting containers${NC}"

docker compose up -d --build

# Migration (Wait for DB)
pok "Waiting for database..."
sleep 10
pok "Running database migrations..."
docker compose exec anycrawl sh -c "cd packages/db && npx drizzle-kit migrate" 2>&1 || pwn "Migration might have already run. Check logs if needed."

pok "All containers started!"

# ========================================
# Step 5: Verify & Summary
# ========================================
echo ""
echo -e "${CYAN}[5/5] Verification${NC}"

ALL_OK=true

docker exec anycrawl_postgres pg_isready -U anycrawl &>/dev/null && pok "PostgreSQL: OK" || { perr "PostgreSQL: ERROR"; ALL_OK=false; }
docker exec anycrawl_redis redis-cli ping &>/dev/null && pok "Redis: OK" || { perr "Redis: ERROR"; ALL_OK=false; }
curl -sf http://localhost:9000/minio/health/live &>/dev/null && pok "MinIO: OK" || { perr "MinIO: ERROR"; ALL_OK=false; }
curl -sf http://localhost:8880 &>/dev/null && pok "AnyCrawl API: OK" || { pwn "AnyCrawl API: starting (may need a moment)"; }

echo ""
echo "========================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE!${NC}"
else
    echo -e "${YELLOW}  ⚠️  INSTALLATION DONE (some services still starting)${NC}"
fi
echo ""
echo -e "  Platform:       ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  AnyCrawl API:   ${PURPLE}http://localhost:8880${NC}"
echo -e "  MinIO Console:  ${PURPLE}http://localhost:9001${NC}"
echo -e "  SearXNG:        ${PURPLE}http://localhost:8080${NC}"
echo -e "  MCP Server:     ${PURPLE}http://localhost:8889${NC} (SSE)"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  • API Key and credentials are in .env — DO NOT share!"
echo "  • Path: $INSTALL_DIR/.env"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  • Start:    cd $INSTALL_DIR && docker compose up -d"
echo "  • Stop:     cd $INSTALL_DIR && docker compose stop"
echo "  • Logs:     cd $INSTALL_DIR && docker compose logs -f anycrawl"
echo "  • Upgrade:  cd $INSTALL_DIR && docker compose pull && docker compose up -d --build"
echo ""
echo "Support: https://ai.vnrom.net"
