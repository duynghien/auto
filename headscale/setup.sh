#!/bin/bash
################################################################
# Headscale Unified Auto-Install
# Supports: macOS (Apple Silicon), Raspberry Pi, VPS (amd64/arm64)
# Full features: Headscale (Tailscale Control Server), Headscale-UI
################################################################
set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -f "docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
# Functions
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
    # Detect Raspberry Pi
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
pheader() {
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
    echo "        Headscale Setup — $PLATFORM_LABEL"
    echo "   Self-hosted Tailscale Control Server + Web UI"
    echo "================================================================${NC}"
}
# Read a single key from an existing .env file without sourcing it.
read_env_value() {
    local key="$1"
    local file="$2"
    local line=""
    [ -f "$file" ] || return 0
    line=$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)
    [ -n "$line" ] && echo "${line#*=}"
}
# Normalize URL:
# - remove trailing slash
# - prepend http:// if scheme is missing
normalize_url() {
    local raw="$1"
    local normalized="${raw%/}"
    if [[ -n "$normalized" && ! "$normalized" =~ ^https?:// ]]; then
        normalized="http://$normalized"
    fi
    echo "$normalized"
}
# ========================================
# Language Selection / Chọn ngôn ngữ
# ========================================
clear
pheader
echo ""
echo "  Select language / Chọn ngôn ngữ:"
echo ""
echo "    1) English (default)"
echo "    2) Tiếng Việt"
echo ""
read -p "  Enter 1 or 2 [1]: " LANG_CHOICE
LANG_CHOICE=${LANG_CHOICE:-1}
if [[ "$LANG_CHOICE" == "2" ]]; then
    LANG="vi"
else
    LANG="en"
fi
# ========================================
# Network Mode Allocation
# ========================================
# Auto-detect LAN IP (platform-specific)
if [[ "$PLATFORM" == "mac" ]]; then
    LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ipconfig getifaddr en1 2>/dev/null || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' || echo "")
else
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}' || echo "")
fi
echo ""
if [[ "$LANG" == "vi" ]]; then
    echo "  Lưu ý quan trọng cho Headscale:"
    echo "  Headscale hoạt động tốt nhất dưới một tên miền công khai (public domain) kèm HTTPS."
    echo "  Tuy nhiên, bạn vẫn có thể dùng IP LAN/Public IP cho môi trường nội bộ."
    echo ""
    echo "  Chế độ truy cập:"
    echo "    1) Localhost (chỉ thử nghiệm - thường không hoạt động để mesh VPN)"
    echo "    2) LAN / Public IP (thiết bị phải kết nối được tới IP này)"
    echo "    3) Domain (Khuyến nghị: ví dụ https://vpn.domain.com)"
else
    echo "  Important note for Headscale:"
    echo "  Headscale works best configured behind a public domain with HTTPS."
    echo "  However, you can still use a LAN/Public IP for strictly internal environments."
    echo ""
    echo "  Access mode:"
    echo "    1) Localhost (testing only - usually fails at mesh VPN)"
    echo "    2) LAN / Public IP (devices must be able to reach this IP)"
    echo "    3) Domain (Recommended: e.g. https://vpn.domain.com)"
fi
echo ""
read -p "  Enter 1, 2 or 3 [3]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-3}
if [[ "$NET_CHOICE" == "1" ]]; then
    SERVER_URL="http://127.0.0.1:8080"
elif [[ "$NET_CHOICE" == "2" ]]; then
    if [ -n "$LAN_IP" ]; then
        if [[ "$LANG" == "vi" ]]; then
            echo ""
            read -p "  Sử dụng IP $LAN_IP? (Enter = OK, hoặc nhập IP khác): " CUSTOM_IP
        else
            echo ""
            read -p "  Use IP $LAN_IP? (Enter = OK, or type another): " CUSTOM_IP
        fi
        [ -n "$CUSTOM_IP" ] && LAN_IP="$CUSTOM_IP"
    else
        if [[ "$LANG" == "vi" ]]; then
            read -p "  Nhập IP: " LAN_IP
        else
            read -p "  Enter IP: " LAN_IP
        fi
        if [ -z "$LAN_IP" ]; then
            perr "IP is required"
            exit 1
        fi
    fi
    SERVER_URL="http://${LAN_IP}:8080"
elif [[ "$NET_CHOICE" == "3" ]]; then
    echo ""
    if [[ "$LANG" == "vi" ]]; then
        echo "  Nhập domain của Headscale (ví dụ: https://vpn.example.com):"
        read -p "  Domain Headscale: " APP_DOMAIN
    else
        echo "  Enter your Headscale domain (e.g. https://vpn.example.com):"
        read -p "  Headscale domain: " APP_DOMAIN
    fi
    
    if [ -z "$APP_DOMAIN" ]; then
        perr "Domain is required"
        exit 1
    fi
    APP_DOMAIN=$(normalize_url "$APP_DOMAIN")
    SERVER_URL="$APP_DOMAIN"
else
    SERVER_URL="http://127.0.0.1:8080"
fi
if [[ "$LANG" == "vi" ]]; then
    pok "Nền tảng: $PLATFORM_LABEL"
else
    pok "Platform: $PLATFORM_LABEL"
fi
pok "Server URL: $SERVER_URL"
# ========================================
# i18n: All translatable strings
# ========================================
t() {
    local key="$1"
    shift
    local text=""
    case "$key" in
        # Step titles
        step1)
            [[ "$LANG" == "vi" ]] && text="[1/8] Kiểm tra hệ thống" || text="[1/8] Checking system";;
        step2)
            [[ "$LANG" == "vi" ]] && text="[2/8] Cấu hình hệ thống & Docker" || text="[2/8] System setup & Docker";;
        step3)
            [[ "$LANG" == "vi" ]] && text="[3/8] Khởi tạo thư mục & Sinh Secrets" || text="[3/8] Creating directory & Generating Secrets";;
        step4)
            [[ "$LANG" == "vi" ]] && text="[4/8] Cấu hình Headscale UI" || text="[4/8] Headscale UI Configuration";;
        step5)
            [[ "$LANG" == "vi" ]] && text="[5/8] Lưu cấu hình environment" || text="[5/8] Saving environment config";;
        step6)
            [[ "$LANG" == "vi" ]] && text="[6/8] Tạo file cấu hình Headscale" || text="[6/8] Creating Headscale config file";;
        step7)
            [[ "$LANG" == "vi" ]] && text="[7/8] Tạo Docker Compose" || text="[7/8] Creating Docker Compose";;
        step8)
            [[ "$LANG" == "vi" ]] && text="[8/8] Khởi động Container" || text="[8/8] Starting Containers";;
            
        # UI Options
        ui_prompt)
            [[ "$LANG" == "vi" ]] && text="  Bạn có muốn cài đặt Headscale Web UI dashboard không? (Y/n) [Y]: " || text="  Do you want to install Headscale Web UI dashboard? (Y/n) [Y]: ";;
        ok_ui)
            [[ "$LANG" == "vi" ]] && text="Headscale UI: Bật (Sẽ chạy ở port 9090 mặc định)" || text="Headscale UI: Enabled (Will run on port 9090 by default)";;
        no_ui)
            [[ "$LANG" == "vi" ]] && text="Headscale UI: Tắt" || text="Headscale UI: Disabled";;
        # System check
        err_arch)
            [[ "$LANG" == "vi" ]] && text="Kiến trúc không hỗ trợ: $ARCH" || text="Unsupported architecture: $ARCH";;
        err_disk)
            [[ "$LANG" == "vi" ]] && text="Ổ đĩa chỉ còn ${1}GB < 2GB tối thiểu!" || text="Disk only has ${1}GB < 2GB minimum!";;
        err_missing)
            [[ "$LANG" == "vi" ]] && text="Thiếu: $1" || text="Missing: $1";;
        warn_not_apple_silicon)
            [[ "$LANG" == "vi" ]] && text="Không phải Apple Silicon, hiệu năng sẽ ảnh hưởng" || text="Not Apple Silicon, performance may be affected";;
        ok_apple_silicon)
            [[ "$LANG" == "vi" ]] && text="Kiến trúc: Apple Silicon ARM64 (M1/M2/M3/M4)" || text="Architecture: Apple Silicon ARM64 (M1/M2/M3/M4)";;
        err_docker)
            [[ "$LANG" == "vi" ]] && text="Docker chưa cài đặt!" || text="Docker is not installed!";;
        err_docker_dl)
            [[ "$LANG" == "vi" ]] && text="Tải: https://orbstack.dev hoặc https://docker.com" || text="Download: https://orbstack.dev or https://docker.com";;
        warn_docker_desktop)
            [[ "$LANG" == "vi" ]] && text="Docker Desktop có thể chưa chạy" || text="Docker Desktop may not be running";;
        err_compose)
            [[ "$LANG" == "vi" ]] && text="Docker Compose Plugin chưa cài đặt!" || text="Docker Compose Plugin is not installed!";;
        # Swap & Docker
        ok_swap)
            [[ "$LANG" == "vi" ]] && text="Swap: $1" || text="Swap: $1";;
        warn_logout)
            [[ "$LANG" == "vi" ]] && text="Cần logout/login lại để dùng docker không sudo" || text="Need to logout/login to use docker without sudo";;
        # Save .env
        env_warning)
            [[ "$LANG" == "vi" ]] && text="# ⚠️  KHÔNG chia sẻ file này! Chứa thông tin nhạy cảm" || text="# ⚠️  DO NOT share this file! Contains sensitive information";;
        ok_env_saved)
            [[ "$LANG" == "vi" ]] && text="Config đã lưu vào .env" || text="Config saved to .env";;
        # Start services
        ok_stop_old)
            [[ "$LANG" == "vi" ]] && text="Dừng containers cũ (nếu có)..." || text="Stopping old containers (if any)...";;
        ok_pull)
            [[ "$LANG" == "vi" ]] && text="Tải Docker images (lần đầu sẽ lâu)..." || text="Pulling Docker images (first time may take a while)...";;
        ok_start)
            [[ "$LANG" == "vi" ]] && text="Khởi động Headscale..." || text="Starting Headscale...";;
        ok_ready)
            [[ "$LANG" == "vi" ]] && text="Headscale: sẵn sàng!" || text="Headscale: ready!";;
        err_start)
            [[ "$LANG" == "vi" ]] && text="LỖI khởi động!" || text="ERROR during startup!";;
        # Finish
        finish_ok)
            [[ "$LANG" == "vi" ]] && text="🎉 CÀI ĐẶT HOÀN TẤT!" || text="🎉 INSTALLATION COMPLETE!";;
        important_title)
            [[ "$LANG" == "vi" ]] && text="⚠️  QUAN TRỌNG:" || text="⚠️  IMPORTANT:";;
        important_env)
            [[ "$LANG" == "vi" ]] && text="  • Các node sẽ kết nối đến: $SERVER_URL" || text="  • Endpoints connect to: $SERVER_URL";;
        usage_title)
            [[ "$LANG" == "vi" ]] && text="Sử dụng / Connecting clients:" || text="Usage / Connecting clients:";;
        usage_1)
            [[ "$LANG" == "vi" ]] && text="  1. Quản lý user/node qua script: ./headscale.sh" || text="  1. Manage users/nodes using script: ./headscale.sh";;
        usage_2)
            [[ "$LANG" == "vi" ]] && text="  2. Tạo user: ./headscale.sh users create alice" || text="  2. Create user: ./headscale.sh users create alice";;
        usage_3)
            [[ "$LANG" == "vi" ]] && text="  3. Kết nối client: tailscale up --login-server $SERVER_URL" || text="  3. Connect client: tailscale up --login-server $SERVER_URL";;
        ui_title)
            [[ "$LANG" == "vi" ]] && text="Giao diện Web / Web UI:" || text="Web UI:";;
        ui_text)
            [[ "$LANG" == "vi" ]] && text="  • Truy cập: http://localhost:9090 (hoặc IP:9090)" || text="  • Access: http://localhost:9090 (or IP:9090)";;
        notes_title)
            [[ "$LANG" == "vi" ]] && text="📝 Ghi chú:" || text="📝 Notes:";;
        note_1)
            [[ "$LANG" == "vi" ]] && text="  • Tất cả file config, DB nằm trong thư mục data/" || text="  • All configuration and DB files are inside data/ folder";;
        note_2)
            [[ "$LANG" == "vi" ]] && text="  • Truy cập tài liệu tại https://headscale.net" || text="  • Check documentation at https://headscale.net";;
        *)
            text="[MISSING: $key]";;
    esac
    echo "$text"
}
# ========================================
# Step 1: System Check
# ========================================
echo ""
echo "$(t step1)"
if [[ "$PLATFORM" == "mac" ]]; then
    # macOS checks
    if [[ "$ARCH" != "arm64" ]]; then
        pwn "$(t warn_not_apple_silicon)"
    else
        pok "$(t ok_apple_silicon)"
    fi
    if ! command -v docker &> /dev/null; then
        perr "$(t err_docker)"
        perr "$(t err_docker_dl)"
        exit 1
    fi
    # Detect Docker environment
    if command -v orb &> /dev/null; then
        pok "OrbStack: OK"
    elif docker context ls 2>/dev/null | grep -q orbstack; then
        pok "OrbStack (context): OK"
    else
        pwn "$(t warn_docker_desktop)"
    fi
elif [[ "$PLATFORM" == "pi" ]]; then
    # Pi checks
    if [[ "$ARCH" != "aarch64" ]]; then
        perr "$(t err_arch)"
        exit 1
    fi
    pok "Arch: aarch64 (ARM64)"
    MEM=$(free -m | awk '/Mem/{print $2}')
    pok "RAM: ${MEM}MB"
    DSK=$(df -BG "$HOME" | awk 'NR==2{gsub(/G/,"",$4);print $4}')
    if [ "${DSK:-0}" -lt 2 ]; then
        perr "$(t err_disk "$DSK")"
        exit 1
    fi
    pok "Disk: ${DSK}GB"
else
    # VPS checks
    pok "Arch: $ARCH"
    MEM=$(free -m | awk '/Mem/{print $2}')
    pok "RAM: ${MEM}MB"
    DSK=$(df -BG "$HOME" | awk 'NR==2{gsub(/G/,"",$4);print $4}')
    if [ "${DSK:-0}" -lt 2 ]; then
        perr "$(t err_disk "$DSK")"
        exit 1
    fi
    pok "Disk: ${DSK}GB"
fi
# ========================================
# Step 2: System Setup & Docker
# ========================================
echo ""
echo "$(t step2)"
if [[ "$PLATFORM" == "pi" ]]; then
    # Configure swap (Pi-specific)
    if command -v dphys-swapfile &>/dev/null; then
        CS=$(grep 'CONF_SWAPSIZE=' /etc/dphys-swapfile 2>/dev/null | cut -d= -f2)
        if [ "${CS:-0}" -lt 1024 ]; then
            sudo dphys-swapfile swapoff 2>/dev/null || true
            sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
            sudo dphys-swapfile setup && sudo dphys-swapfile swapon
            pok "$(t ok_swap "1024MB")"
        else
            pok "$(t ok_swap "${CS}MB (OK)")"
        fi
    fi
fi
if [[ "$PLATFORM" != "mac" ]]; then
    # Linux: Install Docker if needed
    if ! command -v docker &>/dev/null; then
        pok "Installing Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$USER"
        pwn "$(t warn_logout)"
    else
        pok "Docker: OK"
    fi
    # Install Docker Compose plugin if needed
    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
else
    # macOS: Docker Compose check
    if ! docker compose version &> /dev/null; then
        perr "$(t err_compose)"
        exit 1
    fi
fi
pok "Docker Compose: OK"
# ========================================
# Step 3: Directory
# ========================================
echo ""
echo "$(t step3)"
INSTALL_DIR="$HOME/self-hosted/headscale"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/config"
mkdir -p "$INSTALL_DIR/data"
cd "$INSTALL_DIR"
pok "Directory: $INSTALL_DIR"
touch data/db.sqlite
pok "Database initialized"
# ========================================
# Step 4: Web UI Configuration
# ========================================
echo ""
echo "$(t step4)"
echo ""
read -p "$(t ui_prompt)" ENABLE_UI
ENABLE_UI=${ENABLE_UI:-"Y"}
if [[ "$ENABLE_UI" == "Y" || "$ENABLE_UI" == "y" ]]; then
    UI_ENABLED="true"
    pok "$(t ok_ui)"
else
    UI_ENABLED="false"
    pok "$(t no_ui)"
fi
# ========================================
# Step 5: Save .env
# ========================================
echo ""
echo "$(t step5)"
HEADSCALE_PORT=8080
HEADSCALE_UI_PORT=9090
# Pre-generate an API key for UI if UI is enabled
UI_API_KEY=""
if [[ "$UI_ENABLED" == "true" ]]; then
    UI_API_KEY=$(openssl rand -hex 16)
fi
cat > .env << ENVEOF
# =================================================================
# Headscale - Configuration
$(t env_warning)
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# =================================================================
# Server Connection Address
SERVER_URL=$SERVER_URL
# Port Map (Host)
HEADSCALE_PORT=$HEADSCALE_PORT
HEADSCALE_UI_PORT=$HEADSCALE_UI_PORT
# Internal values
UI_ENABLED=$UI_ENABLED
ENVEOF
chmod 600 .env
pok "$(t ok_env_saved)"
# ========================================
# Step 6: Create config.yaml
# ========================================
echo ""
echo "$(t step6)"
# We construct a minimum viable config for headscale that is 100% stable
cat > config/config.yaml << CONFIGEOF
# Headscale configuration
# The url clients will connect to.
server_url: ${SERVER_URL}
# Address to listen to / bind to
listen_addr: 0.0.0.0:8080
# Address to listen to /metrics
metrics_listen_addr: 0.0.0.0:9090
# Address to listen to for gRPC.
grpc_listen_addr: 0.0.0.0:50443
# Allow insecure gRPC
grpc_allow_insecure: false
# Directory where private keys will be stored
private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential
dns:
  magic_dns: true
  base_domain: headscale.internal
  nameservers:
    global:
      - 1.1.1.1
      - 8.8.8.8
  search_domains: []
derp:
  server:
    enabled: false
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
node_update_check_interval: 10s
database:
  type: sqlite3
  sqlite:
    path: /var/lib/headscale/db.sqlite
CONFIGEOF
pok "Headscale config.yaml created"
# ========================================
# Step 7: Create Docker Compose
# ========================================
echo ""
echo "$(t step7)"
cat > docker-compose.yml << 'COMPOSEEOF'
services:
  headscale:
    image: headscale/headscale:latest
    container_name: headscale
    restart: unless-stopped
    command: serve
    ports:
      - "${HEADSCALE_PORT:-8080}:8080"
      - "50443:50443"
    volumes:
      - ./config:/etc/headscale/
      - ./data:/var/lib/headscale
COMPOSEEOF
if [[ "$UI_ENABLED" == "true" ]]; then
    cat >> docker-compose.yml << 'COMPOSEEOF'
  headscale-ui:
    image: ghcr.io/gurucomputing/headscale-ui:latest
    container_name: headscale-ui
    restart: unless-stopped
    ports:
      - "${HEADSCALE_UI_PORT:-9090}:8080"
    environment:
      - HTTP_PROXY=
      - HTTPS_PROXY=
      - NO_PROXY=
    depends_on:
      - headscale
COMPOSEEOF
fi
pok "docker-compose.yml created"
# Generate Management Script (Gen 4 Standard)
cat > headscale.sh << 'SCREOF'
#!/usr/bin/env bash
# headscale.sh - Headscale Management Helper (Gen 4 Standard)
# Usage: ./headscale.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CMD="${1:-help}"

case "$CMD" in
    start)
        echo -e "${GREEN}Starting Headscale...${NC}"
        docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}Stopping Headscale...${NC}"
        docker compose stop
        ;;
    restart)
        echo -e "${YELLOW}Restarting Headscale...${NC}"
        docker compose restart
        ;;
    upgrade|update)
        echo -e "${YELLOW}Backing up .env & configs...${NC}"
        mkdir -p -m 700 backups
        cp -r config "backups/config.pre-update.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        echo -e "${YELLOW}Pulling latest images...${NC}"
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}✓ Update complete!${NC}"
        ;;
    logs)
        shift || true
        svc="${1:-headscale}"
        docker compose logs -f "$svc"
        ;;
    status)
        echo -e "${CYAN}=== Headscale Container Status ===${NC}"
        docker compose ps
        echo ""
        echo "Health check:"
        if curl -sf "http://localhost:8080/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
            echo -e "  [OK] Headscale API health: ${GREEN}Healthy${NC}"
        else
            echo -e "  [WARN] Headscale API health: ${YELLOW}Not ready${NC}"
        fi
        ;;
    users)
        docker compose exec headscale headscale users list
        ;;
    nodes)
        docker compose exec headscale headscale nodes list
        ;;
    apikey)
        echo -e "${GREEN}Creating API Key for UI access (expires in 90 days)...${NC}"
        docker compose exec headscale headscale apikeys create --expiration 90d
        ;;
    cmd)
        shift || true
        docker compose exec headscale headscale "$@"
        ;;
    backup)
        BACKUP_DIR="./backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/headscale_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Archiving Headscale configuration, keys, and SQLite database...${NC}"
        tar -czf "$ARCHIVE" config/ .env docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;
    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./headscale.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${YELLOW}Taking pre-restore safety snapshot...${NC}"
        mkdir -p -m 700 backups
        tar -czf "backups/config-pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz" config/ 2>/dev/null || true
        
        echo -e "${RED}WARNING: This will overwrite current Headscale configuration and nodes database!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            echo "Stopping headscale container..."
            docker compose stop headscale 2>/dev/null || true
            tar -xzf "$FILE"
            echo "Restarting stack..."
            docker compose up -d
            echo -e "${GREEN}✓ Restore completed successfully!${NC}"
        else
            echo "Restore aborted."
        fi
        ;;
    doctor)
        echo -e "${BOLD}=== Headscale Diagnostic Doctor ===${NC}"
        echo -n "Checking Docker... "
        if docker --version >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Docker not found${NC}"
        fi
        echo -n "Checking Docker Compose... "
        if docker compose version >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${RED}✗ Docker Compose not found${NC}"
        fi
        echo "Disk space:"
        df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
        echo "Configuration files:"
        for f in .env config/config.yaml config/db.sqlite; do
            if [[ -f "$f" ]]; then
                P=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%Lp" "$f" 2>/dev/null || echo "unknown")
                echo "  $f: $P"
            else
                echo "  $f: not found"
            fi
        done
        echo "Port bindings (8080, 9090):"
        for p in 8080 9090; do
            if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
                echo "  [BOUND] Port $p is listening"
            else
                echo "  [OPEN/UNKNOWN] Port $p"
            fi
        done
        ;;
    uninstall)
        echo -e "${RED}WARNING: This will stop Headscale and remove all containers and data volumes.${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ Headscale containers and volumes removed.${NC}"
        else
            echo "Uninstall cancelled."
        fi
        ;;
    help|*)
        echo -e "${BOLD}Headscale Management Helper (Gen 4 Standard)${NC}"
        echo ""
        echo "Usage: ./headscale.sh [command]"
        echo ""
        echo "Service Commands:"
        echo "  start      - Start all services"
        echo "  stop       - Stop all services"
        echo "  restart    - Restart all services"
        echo "  update     - Pull latest images & restart"
        echo "  logs [svc] - View logs"
        echo "  status     - Show container status + health"
        echo ""
        echo "Headscale Commands:"
        echo "  users      - List all Headscale users"
        echo "  nodes      - List all registered nodes"
        echo "  apikey     - Generate API key for Web UI"
        echo "  cmd ...    - Run arbitrary headscale CLI command"
        echo ""
        echo "Maintenance Commands:"
        echo "  backup     - Archive SQLite database and config to ./backups/"
        echo "  restore <f>- Restore database and config from archive"
        echo "  doctor     - Run diagnostic health check"
        echo "  uninstall  - Remove containers and volumes"
        ;;
esac
SCREOF
chmod +x headscale.sh
sudo ln -sf "$(pwd)/headscale.sh" /usr/local/bin/headscale 2>/dev/null || true
pok "headscale.sh helper created (symlinked to /usr/local/bin/headscale)"
# ========================================
# Step 8: Start Services
# ========================================
echo ""
echo "$(t step8)"
pok "$(t ok_stop_old)"
docker compose down >/dev/null 2>&1 || true
pok "$(t ok_pull)"
docker compose pull -q || true
pok "$(t ok_start)"
if docker compose up -d; then
    pok "$(t ok_ready)"
    echo "Waiting for Headscale API readiness..."
    for i in $(seq 1 30); do
        if curl -sf "http://localhost:${HEADSCALE_PORT:-8080}/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:${HEADSCALE_PORT:-8080}/health" >/dev/null 2>&1; then
            pok "Headscale API is healthy!"
            break
        fi
        sleep 2
    done
else
    perr "$(t err_start)"
    exit 1
fi
# ========================================
# Finish
# ========================================
echo ""
echo "================================================================"
echo "$(t finish_ok)"
echo ""
echo "$(t important_title)"
echo "$(t important_env)"
echo ""
echo "$(t usage_title)"
echo "$(t usage_1)"
echo "$(t usage_2)"
echo "$(t usage_3)"
if [[ "$UI_ENABLED" == "true" ]]; then
    echo ""
    echo "$(t ui_title)"
    echo "$(t ui_text)"
    echo "  • Quản lý qua UI cần tạo API Key (Settings -> API Keys)"
    echo "  • Lệnh tạo: ./headscale.sh apikey"
fi
echo ""
echo "$(t notes_title)"
echo "$(t note_1)"
echo "$(t note_2)"
echo "================================================================"
echo ""