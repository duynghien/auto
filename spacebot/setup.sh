#!/bin/bash

# setup.sh - Spacebot Auto-Installer
# Supports: macOS (Apple Silicon), Raspberry Pi, VPS (amd64/arm64)
# Created for spacebot multi-platform deployment

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
    PLATFORM_LABEL="macOS"
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
echo "          Spacebot Setup — $PLATFORM_LABEL"
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
for c in curl; do
    if ! command -v $c &> /dev/null; then
        perr "Missing: $c"
        exit 1
    fi
done
pok "Platform: $PLATFORM_LABEL"

# ========================================
# Step 2: Install Directory
# ========================================
echo ""
echo -e "${CYAN}[2/5] Setting up directory${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/spacebot"
mkdir -p "$INSTALL_DIR"

# Copy config files from working dir to install dir (skip if already there)
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pok "Copying configs to $INSTALL_DIR ..."
    for f in docker-compose.yml .env .env.example; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/"
    done
fi
cd "$INSTALL_DIR"

# Create directories
mkdir -p data
pok "Directories: OK"

# ========================================
# Step 3: Environment Configuration
# ========================================
echo ""
echo -e "${CYAN}[3/5] Environment configuration${NC}"

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        pok ".env created from .env.example"
    else
        touch .env
        pok "Empty .env created"
    fi
else
    pok ".env already exists (keeping existing config)"
fi

# ========================================
# Step 4: Build & Start
# ========================================
echo ""
echo -e "${CYAN}[4/5] Starting containers${NC}"

docker compose up -d

pok "Container started!"

# ========================================
# Step 5: Verify & Summary
# ========================================
echo ""
echo -e "${CYAN}[5/5] Verification${NC}"

ALL_OK=true

# Wait a moment for the service to bind port
sleep 3
curl -sf http://localhost:19898 &>/dev/null && pok "Spacebot UI: OK" || { pwn "Spacebot UI: starting (may need a moment to boot)"; ALL_OK=false; }

echo ""
echo "========================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE!${NC}"
else
    echo -e "${YELLOW}  ⚠️  INSTALLATION DONE (service might still be booting)${NC}"
fi
echo ""
echo -e "  Platform:       ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  Spacebot UI:    ${PURPLE}http://localhost:19898${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  • Open the Spacebot UI in your browser to complete onboarding"
echo "  • Path: $INSTALL_DIR"
echo ""
echo -e "${CYAN}Management:${NC}"
echo "  • Start:    cd $INSTALL_DIR && docker compose up -d"
echo "  • Stop:     cd $INSTALL_DIR && docker compose stop"
echo "  • Logs:     cd $INSTALL_DIR && docker compose logs -f spacebot"
echo "  • Upgrade:  cd $INSTALL_DIR && docker compose pull && docker compose up -d"
echo ""
