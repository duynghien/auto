#!/bin/bash

# setup.sh - Scrapling Docker Setup
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
echo "            Scrapling Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${CYAN}[1/4] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    # macOS: Docker must be pre-installed
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed."
        echo "  Install OrbStack: https://orbstack.dev"
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

    # Pi-specific: Swap check (Scrapling builds are memory-heavy)
    if [[ "$PLATFORM" == "pi" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        pok "RAM: ${TOTAL_MEM}MB"
        if [ "$TOTAL_MEM" -lt 4000 ]; then
            if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
                pwn "Low RAM ($TOTAL_MEM MB). Adding 2GB swap for Chromium build..."
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

pok "Platform: $PLATFORM_LABEL"

# ========================================
# Step 2: Setup Directory & Config
# ========================================
echo ""
echo -e "${CYAN}[2/4] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Create data directory for scraped output
mkdir -p data
pok "Output directory: $SCRIPT_DIR/data"

# Setup .env
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        pok ".env created from .env.example"
    fi
else
    pok ".env already exists (keeping existing config)"
fi

# ========================================
# Step 3: Build Docker Image
# ========================================
echo ""
echo -e "${CYAN}[3/4] Building Docker image${NC}"
pwn "This may take 5–15 minutes (downloading Playwright Chromium ~106MB)..."
echo ""

# Check if image already exists
if docker image inspect scrapling:latest &>/dev/null 2>&1; then
    pwn "Image scrapling:latest already exists. Rebuilding..."
fi

docker build -t scrapling:latest .
pok "Docker image built: scrapling:latest"

# ========================================
# Step 4: Smoke Test
# ========================================
echo ""
echo -e "${CYAN}[4/4] Running smoke test${NC}"

if docker run --rm -v "$SCRIPT_DIR/data:/data" scrapling:latest \
    extract get "https://quotes.toscrape.com" "/data/test_output.html" 2>&1; then
    pok "Scraping test: OK (data/test_output.html)"
else
    pwn "Scraping test failed. Binary check..."
    docker run --rm scrapling:latest --help &>/dev/null && pok "Binary: OK" || perr "Scrapling binary not working"
fi

# ========================================
# Summary
# ========================================
echo ""
echo "========================================================"
echo -e "${GREEN}  🎉 INSTALLATION COMPLETE!${NC}"
echo ""
echo -e "  Platform:       ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  Output dir:     ${PURPLE}${SCRIPT_DIR}/data${NC}"
echo ""
echo -e "${CYAN}Usage:${NC}"
echo "  # HTTP GET → HTML"
echo "  docker run --rm -v \"$(pwd)/data:/data\" scrapling:latest \\"
echo "    extract get https://example.com /data/output.html"
echo ""
echo "  # HTTP GET → Markdown"
echo "  docker run --rm -v \"$(pwd)/data:/data\" scrapling:latest \\"
echo "    extract get https://example.com /data/output.md"
echo ""
echo "  # Playwright (JS-heavy sites)"
echo "  docker run --rm -v \"$(pwd)/data:/data\" scrapling:latest \\"
echo "    extract fetch https://example.com /data/output.html"
echo ""
echo "  # Stealthy (max bot evasion)"
echo "  docker run --rm -v \"$(pwd)/data:/data\" scrapling:latest \\"
echo "    extract stealthy-fetch https://example.com /data/output.html"
echo ""
echo "  # CSS selector"
echo "  docker run --rm -v \"$(pwd)/data:/data\" scrapling:latest \\"
echo "    extract get https://example.com /data/output.html -s \"h1, p\""
echo ""
echo "  # MCP Server (for Claude Desktop, LobeHub, n8n...)"
echo "  docker compose --profile mcp up -d"
echo -e "  URL: ${PURPLE}http://localhost:8000/mcp${NC}"
echo ""
echo -e "${CYAN}MCP add to Claude Desktop config:${NC}"
echo '  { "mcpServers": { "scrapling": { "url": "http://localhost:8000/mcp" } } }'
echo ""
echo -e "${YELLOW}⚠ Note:${NC}"
echo "  • Scrapling uses stealth headers by default (browser fingerprint)"
echo "  • Use 'extract fetch' for JavaScript-heavy sites"
echo "  • Output: HTML, Markdown, or plain text (by file extension)"
echo ""
echo "Support: https://ai.vnrom.net"
