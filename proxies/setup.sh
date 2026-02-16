#!/bin/bash

# ============================================
# Universal Proxy Setup v1.0
# Supports: macOS, Raspberry Pi, Linux VPS
# Proxies: Nginx Proxy Manager, Cloudflare Tunnel, Caddy
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
    else
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux VPS (AMD64)"
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
echo "          Universal Proxy Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${BOLD}[1/4] System Check${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &> /dev/null; then
        perr "Docker is not installed."
        echo "  Recommended: Install OrbStack (https://orbstack.dev)"
        exit 1
    fi
    pok "Docker: OK"
else
    # Linux: Auto-install Docker
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
fi

# ========================================
# Step 2: Select Proxy Type
# ========================================
echo ""
echo -e "${BOLD}[2/4] Select Proxy Type:${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} ${BOLD}Nginx Proxy Manager (NPM)${NC} (Recommended)"
echo -e "     - Web GUI for managing hosts & SSL"
echo -e "     - Ports: 80, 443, 81 (Admin)"
echo ""
echo -e "  ${GREEN}2)${NC} ${BOLD}Cloudflare Tunnel${NC} (Remote Access)"
echo -e "     - No open ports required"
echo -e "     - Secure access via Cloudflare Edge"
echo ""
echo -e "  ${GREEN}3)${NC} ${BOLD}Caddy${NC} (Simple)"
echo -e "     - Single file config (Caddyfile)"
echo -e "     - Automatic HTTPS"
echo ""

read -p "Choose [1/2/3] (default: 1): " PROXY_TYPE
PROXY_TYPE=${PROXY_TYPE:-1}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/proxies"
mkdir -p "$INSTALL_DIR"

if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Setting up in $INSTALL_DIR ...${NC}"
fi
cd "$INSTALL_DIR"

# ========================================
# Step 3: Configure & Generate Compose
# ========================================
echo ""
echo -e "${BOLD}[3/4] Configuring...${NC}"

if [ "$PROXY_TYPE" == "1" ]; then
    # --- NPM ---
    echo -e "${CYAN}Setting up Nginx Proxy Manager...${NC}"
    mkdir -p npm_data npm_letsencrypt

    cat > docker-compose.yml <<EOF
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./npm_data:/data
      - ./npm_letsencrypt:/etc/letsencrypt
    networks:
      - proxy-network

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
EOF
    pok "Created docker-compose.yml for NPM"
    echo ""
    echo -e "${YELLOW}Default Login:${NC}"
    echo "  Email:    admin@example.com"
    echo "  Password: changeme"

elif [ "$PROXY_TYPE" == "2" ]; then
    # --- Cloudflare Tunnel ---
    echo -e "${CYAN}Setting up Cloudflare Tunnel...${NC}"
    
    echo ""
    echo -e "${YELLOW}Enter your Cloudflare Tunnel Token:${NC}"
    echo "  (Create at https://one.dash.cloudflare.com -> Networks -> Tunnels)"
    read -p "Token: " CF_TOKEN

    if [ -z "$CF_TOKEN" ]; then
        perr "Token is required!"
        exit 1
    fi

    cat > docker-compose.yml <<EOF
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CF_TOKEN}
    networks:
      - proxy-network

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
EOF
    pok "Created docker-compose.yml for Cloudflare Tunnel"

elif [ "$PROXY_TYPE" == "3" ]; then
    # --- Caddy ---
    echo -e "${CYAN}Setting up Caddy...${NC}"
    
    cat > docker-compose.yml <<EOF
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - proxy-network

volumes:
  caddy_data:
  caddy_config:

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
EOF

    if [ ! -f Caddyfile ]; then
        cat > Caddyfile <<EOF
# Example Caddyfile
# domain.com {
#     reverse_proxy app:8080
# }

:80 {
    respond "Caddy is running!"
}
EOF
        pok "Created default Caddyfile"
    else
        pok "Caddyfile already exists"
    fi
fi

# ========================================
# Step 4: Deploy
# ========================================
echo ""
echo -e "${BOLD}[4/4] Deploying...${NC}"

docker compose up -d

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
if [ "$PROXY_TYPE" == "1" ]; then
    echo -e "  Admin UI:   ${PURPLE}http://localhost:81${NC}"
    echo -e "  Email:      ${BOLD}admin@example.com${NC}"
    echo -e "  Password:   ${BOLD}changeme${NC}"
    if [[ "$PLATFORM" != "mac" ]]; then
        IP=$(hostname -I | awk '{print $1}')
        echo -e "  LAN URL:    ${PURPLE}http://${IP}:81${NC}"
    fi
elif [ "$PROXY_TYPE" == "2" ]; then
    echo -e "  Status:     ${GREEN}Running${NC} (Check Cloudflare Dashboard)"
elif [ "$PROXY_TYPE" == "3" ]; then
    echo -e "  Status:     ${GREEN}Running${NC}"
    echo -e "  Config:     ${BOLD}./Caddyfile${NC}"
fi

echo ""
echo -e "${YELLOW}Network Info:${NC}"
echo "  To connect other containers to this proxy, add them to the networking:"
echo "  networks:"
echo "    - proxy-network"
echo "  external: true"
echo ""
echo "Support: https://ai.vnrom.net"
