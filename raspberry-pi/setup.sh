#!/bin/bash

# ============================================
# Raspberry Pi Unified Setup v1.0
# Supports: Raspberry Pi 4/5 (64-bit OS)
# Features: Docker, Portainer, Optimization
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

# Check Root
if [ "$EUID" -ne 0 ]; then
    perr "Please run as root (sudo ./setup.sh)"
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
echo "          Raspberry Pi Toolset — vnROM.net"
echo "================================================================${NC}"
echo ""

install_docker() {
    echo -e "${BOLD}Installing Docker...${NC}"
    if command -v docker &> /dev/null; then
        pok "Docker already installed"
    else
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        # Add current user (usually 'pi' or user invoking sudo) to docker group
        REAL_USER=${SUDO_USER:-$USER}
        usermod -aG docker "$REAL_USER"
        pok "Docker installed"
    fi

    echo -e "${BOLD}Installing Docker Compose Plugin...${NC}"
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin python3-pip libffi-dev python3-dev
    pok "Docker Compose Plugin installed"

    systemctl enable docker
    systemctl start docker
    pok "Docker service enabled"
}

install_portainer() {
    echo -e "${BOLD}Installing Portainer CE...${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        pok "Portainer container already exists"
    else
        docker run -d -p 9000:9000 -p 9443:9443 --name portainer \
            --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            cr.portainer.io/portainer/portainer-ce:latest
        pok "Portainer deployed"
        
        IP=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}Portainer URL: https://${IP}:9443${NC}"
    fi
}

optimize_system() {
    echo -e "${BOLD}Optimizing System...${NC}"
    
    # 1. Update Packages
    echo "Updating package lists..."
    apt-get update -qq && apt-get upgrade -y -qq
    pok "System updated"

    # 2. Install Tools
    echo "Installing utilities (htop, btop, neofetch, git, curl)..."
    apt-get install -y -qq htop btop neofetch git curl
    pok "Utilities installed"

    # 3. Configure Swap
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 3000 ]; then
        if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
            echo "Low RAM detected ($TOTAL_MEM MB). Adding 2GB swap..."
            fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
            pok "Swap 2GB added"
        else
            pok "Swap already configured"
        fi
    fi
}

# Menu
echo -e "${BOLD}Select Option:${NC}"
echo "  1) Install Docker & Compose"
echo "  2) Install Portainer CE"
echo "  3) Install Full Stack (Docker + Portainer)"
echo "  4) System Optimization (Update + Utilities + Swap)"
echo "  5) Exit"
echo ""
read -p "Choose [1-5]: " CHOICE

case "$CHOICE" in
    1)
        install_docker
        ;;
    2)
        install_portainer
        ;;
    3)
        install_docker
        install_portainer
        ;;
    4)
        optimize_system
        ;;
    5)
        exit 0
        ;;
    *)
        perr "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
