#!/bin/bash

# ============================================
# Crawl4AI Setup for Raspberry Pi (4/5)
# Created by vnROM.net
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

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
echo "              Crawl4AI Setup for Raspberry Pi"
echo "              ARM64 optimized • Low resource mode"
echo ""
echo -e "================================================================${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo ./install-pi.sh${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ──────────────────────────────────────────────
# 1. System Preparation
# ──────────────────────────────────────────────
echo -e "${BOLD}[1/5] Preparing system...${NC}"

# Update system
apt-get update -qq

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}⚠ Warning: Expected ARM64 architecture, detected: ${ARCH}${NC}"
    read -p "Continue anyway? [y/N]: " CONTINUE
    [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ] && exit 1
fi
echo -e "${GREEN}✓ Architecture: ${ARCH}${NC}"

# ──────────────────────────────────────────────
# 2. Install Docker
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[2/5] Checking Docker...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    # Add current user to docker group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        echo -e "${GREEN}✓ Docker installed. User '$SUDO_USER' added to docker group.${NC}"
    fi
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

# Ensure Docker is running
systemctl enable docker
systemctl start docker

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose plugin...${NC}"
    apt-get install -y docker-compose-plugin
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

# ──────────────────────────────────────────────
# 3. Memory & Swap Check
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[3/5] Checking memory...${NC}"

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
echo -e "  Total RAM: ${BOLD}${TOTAL_MEM}MB${NC}"

if [ "$TOTAL_MEM" -lt 3000 ]; then
    echo -e "${YELLOW}⚠ Low RAM detected. Crawl4AI needs at least 2GB.${NC}"

    # Check existing swap
    SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$SWAP_TOTAL" -lt 1500 ]; then
        echo -e "${YELLOW}Adding 2GB swap file...${NC}"
        if [ ! -f /swapfile ]; then
            fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            echo -e "${GREEN}✓ 2GB swap added${NC}"
        else
            echo -e "${GREEN}✓ Swap file already exists${NC}"
        fi
    else
        echo -e "${GREEN}✓ Sufficient swap: ${SWAP_TOTAL}MB${NC}"
    fi
fi

# Adjust memory limits for Pi
# Create .env from template if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env from template${NC}"
fi

if [ "$TOTAL_MEM" -lt 4000 ]; then
    # Pi with 2/4GB RAM - conservative limits
    sed -i "s/^C4AI_MEMORY_LIMIT=.*/C4AI_MEMORY_LIMIT=2G/" .env
    sed -i "s/^C4AI_MEMORY_RESERVE=.*/C4AI_MEMORY_RESERVE=512M/" .env
    echo -e "${GREEN}✓ Memory limits adjusted for ${TOTAL_MEM}MB RAM${NC}"
else
    # Pi 5 with 8GB - more generous
    sed -i "s/^C4AI_MEMORY_LIMIT=.*/C4AI_MEMORY_LIMIT=4G/" .env
    sed -i "s/^C4AI_MEMORY_RESERVE=.*/C4AI_MEMORY_RESERVE=1G/" .env
    echo -e "${GREEN}✓ Memory limits set for ${TOTAL_MEM}MB RAM${NC}"
fi

# ──────────────────────────────────────────────
# 4. Configure & Deploy
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[4/5] Deploying Crawl4AI...${NC}"

# Create .llm.env if not exists
if [ ! -f .llm.env ]; then
    cp .llm.env.example .llm.env
    echo -e "${GREEN}✓ Created .llm.env (edit later to add API keys)${NC}"
fi

# Ensure INSTALL_TYPE is default for Pi (no torch/transformers)
sed -i "s/^INSTALL_TYPE=.*/INSTALL_TYPE=default/" .env

# Pull and start (pre-built ARM64 image - NO building on Pi)
echo -e "${YELLOW}Pulling Crawl4AI ARM64 image... (this may take a few minutes)${NC}"
docker compose pull
docker compose up -d

# ──────────────────────────────────────────────
# 5. Systemd Service (Auto-start on boot)
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[5/5] Setting up auto-start...${NC}"

COMPOSE_PATH="$SCRIPT_DIR/docker-compose.yml"

cat > /etc/systemd/system/crawl4ai.service << EOF
[Unit]
Description=Crawl4AI Web Crawler
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/docker compose -f $COMPOSE_PATH up -d
ExecStop=/usr/bin/docker compose -f $COMPOSE_PATH down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable crawl4ai.service
echo -e "${GREEN}✓ Systemd service created (auto-start on boot)${NC}"

# ──────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}Waiting for Crawl4AI to start...${NC}"

PI_IP=$(hostname -I | awk '{print $1}')
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf http://localhost:11235/health > /dev/null 2>&1; then
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
    echo -ne "\r  Waiting... (${WAITED}s/${MAX_WAIT}s)"
done
echo ""

if curl -sf http://localhost:11235/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Crawl4AI is running!${NC}"
else
    echo -e "${YELLOW}⚠ Still starting. Check: docker compose logs -f${NC}"
fi

# Summary
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}${BOLD}✅ Raspberry Pi Setup Complete!${NC}                 ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Local:${NC}  http://localhost:11235                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}LAN:${NC}    http://${PI_IP}:11235               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Dashboard:${NC}    /dashboard                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Playground:${NC}   /playground                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}MCP Endpoints:${NC}                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🔌 SSE${NC}         /mcp/sse                        ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}📡 Streamable${NC}  /mcp/streamable                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🌐 WebSocket${NC}   /mcp/ws                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Service:${NC} sudo systemctl [start|stop] crawl4ai  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Manage:${NC}  ./c4ai.sh [start|stop|logs|test]     ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Add LLM API keys later: nano .llm.env${NC}"
echo ""
