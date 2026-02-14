#!/bin/bash

# install-pi.sh - AnyCrawl/OpenClaw Setup for Raspberry Pi
# Created by vnROM.net

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== AnyCrawl Setup for Raspberry Pi ===${NC}"

# Check for Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo ./install-pi.sh)${NC}"
  exit 1
fi

# Update System
echo "Updating system..."
apt-get update && apt-get upgrade -y

# Install Docker if missing
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
    echo "Docker installed."
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

# Install dependencies for building native modules (sometimes needed for MCP/Node)
apt-get install -y build-essential libssl-dev git

# Clone AnyCrawl Source (Required for build)
if [ ! -d "anycrawl-source" ]; then
    echo -e "${YELLOW}Cloning AnyCrawl source code...${NC}"
    git clone https://github.com/any4ai/AnyCrawl.git anycrawl-source
fi

# Setup Directory
INSTALL_DIR="/opt/anycrawl"
mkdir -p $INSTALL_DIR
cp -r ./* $INSTALL_DIR/
chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR
cd $INSTALL_DIR

# Run generic setup (reuse logic)
chmod +x setup.sh
# Run as non-root user (the SUDO_USER) for docker commands to work with group permission, 
# or just run as root if configured. simpler to run as is.
./setup.sh

echo -e "${GREEN}=== Raspberry Pi Setup Complete ===${NC}"
# Add swap check?
# If RAM < 4GB, add swap
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 4000 ]; then
    echo -e "${YELLOW}Warning: Low RAM ($TOTAL_MEM MB). Adding 2GB Swap...${NC}"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
fi
