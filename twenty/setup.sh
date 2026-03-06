#!/bin/bash

# setup.sh - Twenty CRM Unified Setup v1.0
# Supports: macOS (Apple Silicon / Intel), Raspberry Pi, VPS (amd64/arm64)
# Created by vnROM.net

set -euo pipefail

# ========================================
# Colors & Helpers
# ========================================
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
    PLATFORM_LABEL="macOS ($(uname -m))"
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
        PLATFORM="vps-other"
        PLATFORM_LABEL="Linux ($ARCH)"
    fi
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

# ========================================
# Language Selection / Chọn ngôn ngữ
# ========================================
echo ""
echo -e "${CYAN}Select language / Chọn ngôn ngữ:${NC}"
echo "  1) English"
echo "  2) Tiếng Việt"
read -rp "  Choice [1/2] (default: 1): " lang_choice

if [[ "$lang_choice" == "2" ]]; then
    LANG_SELECTED="vi"
    MSG_STEP1="[1/5] Kiểm tra hệ thống"
    MSG_STEP2="[2/5] Cấu hình môi trường"
    MSG_STEP3="[3/5] Cấu hình cổng & URL"
    MSG_STEP4="[4/5] Khởi động containers"
    MSG_STEP5="[5/5] Kiểm tra & hoàn tất"
    MSG_DOCKER_MISSING="Chưa cài Docker."
    MSG_DOCKER_INSTALL_MAC="  Cài OrbStack: https://orbstack.dev\n  Hoặc Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
    MSG_DOCKER_INSTALLING="Chưa có Docker, đang cài..."
    MSG_COMPOSE_MISSING="Không tìm thấy Docker Compose Plugin!"
    MSG_SWAP_LOW="RAM thấp. Đang thêm 2GB swap..."
    MSG_SWAP_OK="Swap đã được cấu hình"
    MSG_ENV_CREATED=".env đã tạo với mật khẩu ngẫu nhiên"
    MSG_ENV_EXISTS=".env đã tồn tại (giữ nguyên cấu hình cũ)"
    MSG_PORT_PROMPT="  Nhập cổng web (mặc định: 3000): "
    MSG_PORT_IN_USE="Cổng đã được sử dụng. Vui lòng chọn cổng khác."
    MSG_SERVER_URL_PROMPT="  Nhập SERVER_URL (mặc định: http://localhost"
    MSG_STARTING="Đang khởi động containers..."
    MSG_WAITING="Đang đợi server khởi động"
    MSG_DONE="🎉 CÀI ĐẶT HOÀN TẤT!"
    MSG_PARTIAL="⚠️  XONG (một số dịch vụ vẫn đang khởi động)"
    MSG_MGMT="Quản lý:"
    MSG_IMPORTANT="QUAN TRỌNG:"
    MSG_SECRET_WARNING="Thông tin đăng nhập lưu trong .env — ĐỪNG CHIA SẺ!"
    MSG_SUPPORT="Hỗ trợ: https://ai.vnrom.net"
else
    LANG_SELECTED="en"
    MSG_STEP1="[1/5] System Check"
    MSG_STEP2="[2/5] Environment Configuration"
    MSG_STEP3="[3/5] Port & URL Configuration"
    MSG_STEP4="[4/5] Starting Containers"
    MSG_STEP5="[5/5] Verification & Summary"
    MSG_DOCKER_MISSING="Docker is not installed."
    MSG_DOCKER_INSTALL_MAC="  Install OrbStack: https://orbstack.dev\n  Or Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
    MSG_DOCKER_INSTALLING="Docker not found, installing..."
    MSG_COMPOSE_MISSING="Docker Compose Plugin not found!"
    MSG_ENV_CREATED=".env created with secure random credentials"
    MSG_ENV_EXISTS=".env already exists (keeping existing config)"
    MSG_PORT_PROMPT="  Enter web port (default: 3000): "
    MSG_PORT_IN_USE="Port is already in use. Please choose another."
    MSG_SERVER_URL_PROMPT="  Enter SERVER_URL (default: http://localhost"
    MSG_STARTING="Starting containers..."
    MSG_WAITING="Waiting for server to become healthy"
    MSG_DONE="🎉 INSTALLATION COMPLETE!"
    MSG_PARTIAL="⚠️  DONE (some services still starting)"
    MSG_MGMT="Management:"
    MSG_IMPORTANT="IMPORTANT:"
    MSG_SECRET_WARNING="Credentials are in .env — DO NOT share!"
    MSG_SUPPORT="Support: https://ai.vnrom.net"
fi

# ========================================
# Banner
# ========================================
echo ""
echo "================================================================"
echo -e "${PURPLE}"
cat << 'EOF'
      _                         _     _             
     | |                       | |   (_)            
   __| |_   _ _   _ ____   ____| |__  _ _____ ____  
  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ 
 ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |
  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|
             (____/      (_____|                    
EOF
echo ""
echo -e "         Twenty CRM Setup v1.0 — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo ""

# ========================================
# Step 1: System Check & Dependencies
# ========================================
echo -e "${CYAN}${MSG_STEP1}${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &>/dev/null; then
        perr "$MSG_DOCKER_MISSING"
        echo -e "$MSG_DOCKER_INSTALL_MAC"
        exit 1
    fi
    pok "Docker: OK"

    if ! docker compose version &>/dev/null; then
        perr "$MSG_COMPOSE_MISSING"
        exit 1
    fi
    pok "Docker Compose: OK"
else
    # Linux (Pi / VPS): Auto-install Docker
    if ! command -v docker &>/dev/null; then
        pwn "$MSG_DOCKER_INSTALLING"
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

    # Raspberry Pi: Check swap
    if [[ "$PLATFORM" == "pi" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        pok "RAM: ${TOTAL_MEM}MB"
        if [ "$TOTAL_MEM" -lt 4000 ]; then
            if [ ! -f /swapfile ] && ! swapon --show | grep -q '/swapfile'; then
                pwn "${TOTAL_MEM}MB — ${MSG_SWAP_LOW}"
                sudo fallocate -l 2G /swapfile
                sudo chmod 600 /swapfile
                sudo mkswap /swapfile
                sudo swapon /swapfile
                echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
                pok "Swap: 2GB added"
            else
                pok "${MSG_SWAP_OK}"
            fi
        fi
    fi
fi

for c in openssl curl; do
    if ! command -v $c &>/dev/null; then
        perr "Missing required tool: $c"
        exit 1
    fi
done
pok "Platform: $PLATFORM_LABEL"

# ========================================
# Step 2: Install Directory
# ========================================
echo ""
echo -e "${CYAN}${MSG_STEP2}${NC}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/self-hosted/twenty"
mkdir -p "$INSTALL_DIR"

# Copy config files from script dir to install dir (skip if already there)
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    pok "Copying configs to $INSTALL_DIR ..."
    for f in docker-compose.yml .env.example; do
        [[ -f "$SCRIPT_DIR/$f" ]] && cp -n "$SCRIPT_DIR/$f" "$INSTALL_DIR/" 2>/dev/null || true
    done
fi
cd "$INSTALL_DIR"

# Always download fresh docker-compose.yml (ensures clean port config)
pwn "Downloading docker-compose.yml..."
curl -fsSO https://raw.githubusercontent.com/twentyhq/twenty/main/packages/twenty-docker/docker-compose.yml
pok "docker-compose.yml: downloaded"
if [ ! -f .env.example ]; then
    pwn "Downloading .env.example..."
    curl -fsSO https://raw.githubusercontent.com/twentyhq/twenty/main/packages/twenty-docker/.env.example
    pok ".env.example: downloaded"
fi
pok "Install dir: $INSTALL_DIR"

# ========================================
# Step 3: Port & URL Configuration
# ========================================
echo ""
echo -e "${CYAN}${MSG_STEP3}${NC}"

# --- Custom Port ---
read -rp "$MSG_PORT_PROMPT" user_port
APP_PORT="${user_port:-3000}"

# Validate it's a number
if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]]; then
    perr "Invalid port: $APP_PORT"
    exit 1
fi

# Check if port is in use
port_in_use=false
if command -v lsof &>/dev/null; then
    lsof -Pi :"$APP_PORT" -sTCP:LISTEN -t >/dev/null 2>&1 && port_in_use=true || true
elif command -v ss &>/dev/null; then
    ss -tlnp | grep -q ":${APP_PORT} " && port_in_use=true || true
fi
if [ "$port_in_use" = true ]; then
    perr "$MSG_PORT_IN_USE (port $APP_PORT)"
    exit 1
fi
pok "Port: $APP_PORT (available)"

# --- SERVER_URL ---
DEFAULT_SERVER_URL="http://localhost:${APP_PORT}"
read -rp "${MSG_SERVER_URL_PROMPT}:${APP_PORT}): " user_server_url
SERVER_URL="${user_server_url:-$DEFAULT_SERVER_URL}"
pok "SERVER_URL: $SERVER_URL"

# --- Generate secrets ---
PG_PASSWORD=$(openssl rand -hex 24)
APP_SECRET=$(openssl rand -base64 32)

# --- Write .env ---
if [ ! -f .env ]; then
    cat > .env << EOF
TAG=latest

PG_DATABASE_USER=postgres
PG_DATABASE_PASSWORD=${PG_PASSWORD}
PG_DATABASE_HOST=db
PG_DATABASE_PORT=5432
REDIS_URL=redis://redis:6379

SERVER_URL=${SERVER_URL}
APP_SECRET=${APP_SECRET}

STORAGE_TYPE=local
STORAGE_S3_REGION=
STORAGE_S3_NAME=
STORAGE_S3_ENDPOINT=

DISABLE_DB_MIGRATIONS=
DISABLE_CRON_JOBS_REGISTRATION=
EOF
    pok "$MSG_ENV_CREATED"
    echo ""
    echo -e "  DB Password: ${YELLOW}${PG_PASSWORD}${NC}"
    echo -e "  App Secret:  ${YELLOW}(generated, stored in .env)${NC}"
    echo ""
else
    pok "$MSG_ENV_EXISTS"
fi

# Patch docker-compose.yml ports if not using default 3000
if [[ "$APP_PORT" != "3000" ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        sed -i '' "s|\"3000:3000\"|\"${APP_PORT}:3000\"|g" docker-compose.yml
    else
        sed -i "s|\"3000:3000\"|\"${APP_PORT}:3000\"|g" docker-compose.yml
    fi
    pok "Port mapping updated: $APP_PORT → 3000 (internal)"
fi

# ========================================
# Step 4: Start Containers
# ========================================
echo ""
echo -e "${CYAN}${MSG_STEP4}${NC}"
pwn "$MSG_STARTING"

DOCKER_COMPOSE_CMD="docker compose"
command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null && DOCKER_COMPOSE_CMD="docker-compose"

$DOCKER_COMPOSE_CMD up -d

pok "All containers launched"

# ========================================
# Step 5: Verify & Summary
# ========================================
echo ""
echo -e "${CYAN}${MSG_STEP5}${NC}"

HEALTH_URL="http://localhost:${APP_PORT}/healthz"
echo -n "  → $MSG_WAITING ."
MAX_WAIT=60
COUNT=0
SERVER_OK=false
while [ $COUNT -lt $MAX_WAIT ]; do
    status=$(curl -sf -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        SERVER_OK=true
        break
    fi
    echo -n "."
    sleep 5
    COUNT=$((COUNT + 1))
done
echo ""

if [ "$SERVER_OK" = true ]; then
    pok "Twenty CRM server: OK"
else
    pwn "Twenty CRM: still starting (check: docker compose logs server)"
fi

echo ""
echo "================================================================"
if [ "$SERVER_OK" = true ]; then
    echo -e "${GREEN}  ${MSG_DONE}${NC}"
else
    echo -e "${YELLOW}  ${MSG_PARTIAL}${NC}"
fi
echo ""
echo -e "  Platform:    ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  Twenty CRM:  ${PURPLE}${SERVER_URL}${NC}"
echo ""
echo -e "${YELLOW}⚠️  ${MSG_IMPORTANT}${NC}"
echo "  • $MSG_SECRET_WARNING"
echo "  • Path: $INSTALL_DIR/.env"
echo ""
echo -e "${CYAN}${MSG_MGMT}${NC}"
echo "  • Start:   cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD up -d"
echo "  • Stop:    cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD stop"
echo "  • Logs:    cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD logs -f server"
echo "  • Upgrade: cd $INSTALL_DIR && $DOCKER_COMPOSE_CMD pull && $DOCKER_COMPOSE_CMD up -d"
echo ""
echo "$MSG_SUPPORT"
