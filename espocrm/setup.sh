#!/bin/bash
################################################################
# EspoCRM Unified Auto-Install
# Supports: macOS (Apple Silicon/Intel), Raspberry Pi, VPS (amd64/arm64)
# Based on official espocrm/espocrm-docker deployment
################################################################

set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Helpers
pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

say() {
    local en="$1"
    local vi="$2"
    if [[ "${APP_LANG:-en}" == "vi" ]]; then
        echo "$vi"
    else
        echo "$en"
    fi
}

step_title() {
    case "$1" in
        1) say "[1/9] System check" "[1/9] Kiểm tra hệ thống" ;;
        2) say "[2/9] Access mode" "[2/9] Chế độ truy cập" ;;
        3) say "[3/9] Directory setup" "[3/9] Thiết lập thư mục" ;;
        4) say "[4/9] Environment & secrets" "[4/9] Biến môi trường & secrets" ;;
        5) say "[5/9] Docker Compose file" "[5/9] Tạo file Docker Compose" ;;
        6) say "[6/9] Compose validation" "[6/9] Kiểm tra Compose" ;;
        7) say "[7/9] Start containers" "[7/9] Khởi động containers" ;;
        8) say "[8/9] Verify services" "[8/9] Xác minh services" ;;
        9) say "[9/9] Helper & summary" "[9/9] Helper & tổng kết" ;;
        *) echo "[x]" ;;
    esac
}

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
    echo "           EspoCRM Setup — $PLATFORM_LABEL"
    echo "        CRM Platform · Self-hosted"
    echo -e "================================================================${NC}"
}

normalize_url() {
    local raw="$1"
    local normalized="${raw%/}"

    if [[ -z "$normalized" ]]; then
        echo ""
        return
    fi

    if [[ ! "$normalized" =~ ^https?:// ]]; then
        normalized="https://$normalized"
    fi

    echo "$normalized"
}

normalize_ws_url() {
    local raw="$1"
    local default_scheme="${2:-wss}"
    local normalized="${raw%/}"

    if [[ -z "$normalized" ]]; then
        echo ""
        return
    fi

    if [[ ! "$normalized" =~ ^wss?:// ]]; then
        normalized="${default_scheme}://$normalized"
    fi

    echo "$normalized"
}

host_from_url() {
    local url="$1"
    echo "$url" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##'
}

read_env_value() {
    local key="$1"
    local file="$2"
    local line=""

    [[ -f "$file" ]] || return 0
    line=$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)
    [[ -n "$line" ]] && echo "${line#*=}"
}

port_in_use() {
    local port="$1"

    if command -v lsof >/dev/null 2>&1; then
        lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -tln 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    else
        return 1
    fi
}

detect_lan_ip() {
    if [[ "$PLATFORM" == "mac" ]]; then
        local ip
        ip=$(ipconfig getifaddr en0 2>/dev/null || true)
        [[ -z "$ip" ]] && ip=$(ipconfig getifaddr en1 2>/dev/null || true)
        [[ -z "$ip" ]] && ip=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}' || true)
        echo "$ip"
    else
        local ip
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
        [[ -z "$ip" ]] && ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || true)
        echo "$ip"
    fi
}

run_privileged() {
    if [[ -n "$SUDO" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

install_linux_package() {
    local pkg="$1"

    if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get install -y -qq "$pkg" >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y "$pkg" >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y "$pkg" >/dev/null 2>&1 || true
    fi
}

DOCKER_CMD=(docker)
dc() {
    "${DOCKER_CMD[@]}" compose "$@"
}

refresh_docker_cmd() {
    DOCKER_CMD=(docker)
    if "${DOCKER_CMD[@]}" info >/dev/null 2>&1; then
        return 0
    fi

    if [[ "$PLATFORM" != "mac" ]] && run_privileged docker info >/dev/null 2>&1; then
        DOCKER_CMD=(sudo docker)
        return 0
    fi

    return 1
}

# ========================================
# Platform detection
# ========================================
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    PLATFORM_LABEL="macOS ($ARCH)"
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

SUDO=""
if [[ "$PLATFORM" != "mac" && $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        perr "sudo is required on Linux when not running as root."
    fi
fi

# ========================================
# Language selection
# ========================================
clear 2>/dev/null || true
pheader

echo ""
echo "  Select language / Chọn ngôn ngữ:"
echo ""
echo "    1) English (default)"
echo "    2) Tiếng Việt"
echo ""
read -rp "  Enter 1 or 2 [1]: " LANG_CHOICE
LANG_CHOICE=${LANG_CHOICE:-1}

if [[ "$LANG_CHOICE" == "2" ]]; then
    APP_LANG="vi"
else
    APP_LANG="en"
fi

TEST_MODE="${ESPOCRM_SETUP_TEST_MODE:-0}"
SKIP_DOCKER_COMMANDS=0
if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "TEST MODE enabled: skip runtime start/health checks." "TEST MODE đã bật: bỏ qua start/health check runtime.")"
fi

# ========================================
# Step 1: System check
# ========================================
echo ""
echo -e "${BOLD}$(step_title 1)${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        if [[ "$TEST_MODE" == "1" ]]; then
            pwn "$(say "Docker is not installed. TEST MODE will continue without runtime checks." "Docker chưa được cài. TEST MODE sẽ tiếp tục không cần runtime checks.")"
            SKIP_DOCKER_COMMANDS=1
        else
            perr "$(say "Docker is not installed. Install OrbStack or Docker Desktop first." "Docker chưa được cài. Hãy cài OrbStack hoặc Docker Desktop trước.")"
        fi
    fi

    if [[ "$SKIP_DOCKER_COMMANDS" == "0" ]] && ! docker info >/dev/null 2>&1; then
        pwn "$(say "Docker daemon is not running. Trying to start Docker..." "Docker daemon chưa chạy. Đang thử khởi động Docker...")"
        open -a OrbStack 2>/dev/null || open -a Docker 2>/dev/null || true
        echo -n "  Waiting"
        for _ in {1..30}; do
            if docker info >/dev/null 2>&1; then
                break
            fi
            echo -n "."
            sleep 2
        done
        echo ""
        if ! docker info >/dev/null 2>&1; then
            if [[ "$TEST_MODE" == "1" ]]; then
                pwn "$(say "Docker daemon is unavailable. TEST MODE will continue without docker commands." "Docker daemon chưa sẵn sàng. TEST MODE sẽ tiếp tục không chạy docker commands.")"
                SKIP_DOCKER_COMMANDS=1
            else
                perr "$(say "Docker daemon is still not available." "Docker daemon vẫn chưa sẵn sàng.")"
            fi
        fi
    fi

    if [[ "$SKIP_DOCKER_COMMANDS" == "0" ]] && ! docker compose version >/dev/null 2>&1; then
        if [[ "$TEST_MODE" == "1" ]]; then
            pwn "$(say "Docker Compose plugin not found. TEST MODE will skip compose execution." "Không tìm thấy Docker Compose plugin. TEST MODE sẽ bỏ qua chạy compose.")"
            SKIP_DOCKER_COMMANDS=1
        else
            perr "$(say "Docker Compose plugin not found." "Không tìm thấy Docker Compose plugin.")"
        fi
    fi
else
    if ! command -v docker >/dev/null 2>&1; then
        pwn "$(say "Docker not found, installing..." "Không tìm thấy Docker, đang cài...")"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        run_privileged sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
        if [[ -n "$SUDO" ]]; then
            run_privileged usermod -aG docker "$USER" 2>/dev/null || true
            pwn "$(say "If needed, logout/login to use docker without sudo." "Nếu cần, hãy logout/login để dùng docker không cần sudo.")"
        fi
    fi

    if ! docker compose version >/dev/null 2>&1; then
        pwn "$(say "Docker Compose plugin missing, installing..." "Thiếu Docker Compose plugin, đang cài...")"
        if command -v apt-get >/dev/null 2>&1; then
            run_privileged apt-get update -qq
            run_privileged apt-get install -y -qq docker-compose-plugin
        else
            pwn "$(say "Could not auto-install compose plugin on this distro. Please install docker compose manually if command is unavailable." "Không thể tự cài compose plugin trên distro này. Hãy cài docker compose thủ công nếu lệnh chưa dùng được.")"
        fi
    fi

    install_linux_package curl
    install_linux_package openssl
    install_linux_package python3
    install_linux_package ca-certificates
fi

for cmd in curl openssl python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        perr "$(say "Missing required command:" "Thiếu command bắt buộc:") $cmd"
    fi
done

if [[ "$SKIP_DOCKER_COMMANDS" == "0" ]]; then
    refresh_docker_cmd || perr "$(say "Docker daemon is not accessible." "Không thể truy cập Docker daemon.")"
    dc version >/dev/null 2>&1 || perr "$(say "Docker Compose command is not ready." "Docker Compose chưa sẵn sàng.")"
else
    pwn "$(say "Skipping Docker command checks in TEST MODE." "Bỏ qua kiểm tra Docker command trong TEST MODE.")"
fi

if [[ "$PLATFORM" == "mac" ]]; then
    TOTAL_MEM_MB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
else
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
fi
DISK_GB=$(df -k "$HOME" | awk 'NR==2{print int($4/1024/1024)}')

pok "$(say "Platform:" "Nền tảng:") $PLATFORM_LABEL"
pok "RAM: ${TOTAL_MEM_MB}MB"
pok "$(say "Free disk:" "Dung lượng trống:") ${DISK_GB}GB"

if [[ "${DISK_GB:-0}" -lt 8 ]]; then
    perr "$(say "At least 8GB free disk is required." "Cần tối thiểu 8GB dung lượng trống.")"
fi

if [[ "${TOTAL_MEM_MB:-0}" -lt 2048 ]]; then
    pwn "$(say "Less than 2GB RAM detected. EspoCRM may run slowly." "Phát hiện dưới 2GB RAM. EspoCRM có thể chạy chậm.")"
fi

if [[ "$PLATFORM" == "pi" && "${TOTAL_MEM_MB:-0}" -lt 3000 ]]; then
    if ! swapon --show | grep -q '^'; then
        pwn "$(say "No swap detected. Creating 2GB swap..." "Không có swap. Đang tạo swap 2GB...")"
        run_privileged fallocate -l 2G /swapfile || run_privileged dd if=/dev/zero of=/swapfile bs=1M count=2048
        run_privileged chmod 600 /swapfile
        run_privileged mkswap /swapfile >/dev/null
        run_privileged swapon /swapfile
        if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
            echo '/swapfile none swap sw 0 0' | run_privileged tee -a /etc/fstab >/dev/null
        fi
        pok "$(say "Swap 2GB configured." "Đã cấu hình swap 2GB.")"
    else
        pok "$(say "Swap already exists." "Swap đã tồn tại.")"
    fi
fi

# ========================================
# Step 2: Access mode
# ========================================
echo ""
echo -e "${BOLD}$(step_title 2)${NC}"

LAN_IP=$(detect_lan_ip)
if [[ "$PLATFORM" == "mac" ]]; then
    DEFAULT_NET="1"
else
    DEFAULT_NET="2"
fi

echo ""
if [[ "$APP_LANG" == "vi" ]]; then
    echo "  Chọn chế độ truy cập:"
    echo ""
    [[ "$DEFAULT_NET" == "1" ]] && echo "    1) Localhost (mặc định)" || echo "    1) Localhost"
    if [[ -n "$LAN_IP" ]]; then
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server ($LAN_IP) (mặc định)" || echo "    2) LAN / Home Server ($LAN_IP)"
    else
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server (nhập IP thủ công) (mặc định)" || echo "    2) LAN / Home Server (nhập IP thủ công)"
    fi
    echo "    3) Domain (reverse proxy)"
else
    echo "  Choose access mode:"
    echo ""
    [[ "$DEFAULT_NET" == "1" ]] && echo "    1) Localhost (default)" || echo "    1) Localhost"
    if [[ -n "$LAN_IP" ]]; then
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server ($LAN_IP) (default)" || echo "    2) LAN / Home Server ($LAN_IP)"
    else
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server (manual IP) (default)" || echo "    2) LAN / Home Server (manual IP)"
    fi
    echo "    3) Domain (behind reverse proxy)"
fi

read -rp "  $(say "Enter 1, 2 or 3" "Nhập 1, 2 hoặc 3") [${DEFAULT_NET}]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-$DEFAULT_NET}

read -rp "  $(say "HTTP port for EspoCRM" "Cổng HTTP cho EspoCRM") [8080]: " APP_PORT
APP_PORT=${APP_PORT:-8080}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid HTTP port." "Cổng HTTP không hợp lệ.")"
fi

DEFAULT_WS_PORT=$((APP_PORT + 1))
if [[ "$DEFAULT_WS_PORT" -gt 65535 ]]; then
    DEFAULT_WS_PORT=8081
fi

read -rp "  $(say "WebSocket port for EspoCRM" "Cổng WebSocket cho EspoCRM") [${DEFAULT_WS_PORT}]: " WS_PORT
WS_PORT=${WS_PORT:-$DEFAULT_WS_PORT}

if ! [[ "$WS_PORT" =~ ^[0-9]+$ ]] || [[ "$WS_PORT" -lt 1 || "$WS_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid WebSocket port." "Cổng WebSocket không hợp lệ.")"
fi

if [[ "$TEST_MODE" != "1" ]]; then
    if port_in_use "$APP_PORT"; then
        perr "$(say "HTTP port is already in use:" "Cổng HTTP đang được sử dụng:") $APP_PORT"
    fi
    if [[ "$WS_PORT" != "$APP_PORT" ]] && port_in_use "$WS_PORT"; then
        perr "$(say "WebSocket port is already in use:" "Cổng WebSocket đang được sử dụng:") $WS_PORT"
    fi
fi

NETWORK_MODE="localhost"
APP_URL="http://localhost:${APP_PORT}"
WS_URL="ws://localhost:${WS_PORT}"

case "$NET_CHOICE" in
    2)
        NETWORK_MODE="lan"
        if [[ -n "$LAN_IP" ]]; then
            read -rp "  $(say "Use IP $LAN_IP? (Enter=OK, or type another)" "Dùng IP $LAN_IP? (Enter=OK, hoặc nhập IP khác)"): " CUSTOM_IP
            [[ -n "$CUSTOM_IP" ]] && LAN_IP="$CUSTOM_IP"
        else
            read -rp "  $(say "Enter LAN IP" "Nhập IP LAN"): " LAN_IP
            [[ -z "$LAN_IP" ]] && perr "$(say "LAN IP is required." "Bắt buộc nhập IP LAN.")"
        fi
        APP_URL="http://${LAN_IP}:${APP_PORT}"
        WS_URL="ws://${LAN_IP}:${WS_PORT}"
        ;;
    3)
        NETWORK_MODE="domain"
        read -rp "  $(say "Enter public domain or URL (e.g. https://crm.example.com)" "Nhập domain hoặc URL public (ví dụ: https://crm.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"

        WS_SCHEME="wss"
        if [[ "$APP_URL" =~ ^http:// ]]; then
            WS_SCHEME="ws"
        fi
        DEFAULT_WS_URL="${WS_SCHEME}://$(host_from_url "$APP_URL"):${WS_PORT}"
        read -rp "  $(say "Public WebSocket URL" "URL WebSocket public") [${DEFAULT_WS_URL}]: " DOMAIN_WS_INPUT
        DOMAIN_WS_INPUT=${DOMAIN_WS_INPUT:-$DEFAULT_WS_URL}
        WS_URL=$(normalize_ws_url "$DOMAIN_WS_INPUT" "$WS_SCHEME")
        [[ -z "$WS_URL" ]] && perr "$(say "WebSocket URL is required." "Bắt buộc nhập URL WebSocket.")"
        ;;
    *)
        NETWORK_MODE="localhost"
        APP_URL="http://localhost:${APP_PORT}"
        WS_URL="ws://localhost:${WS_PORT}"
        ;;
esac

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"
pok "$(say "WebSocket URL:" "URL WebSocket:") $WS_URL"

# ========================================
# Step 3: Directory setup
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

INSTALL_DIR="$HOME/self-hosted/espocrm"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p backups
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

# ========================================
# Step 4: Environment & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

OLD_ESPOCRM_DB_NAME=$(read_env_value "ESPOCRM_DATABASE_NAME" ".env")
OLD_ESPOCRM_DB_USER=$(read_env_value "ESPOCRM_DATABASE_USER" ".env")
OLD_ESPOCRM_DB_PASSWORD=$(read_env_value "ESPOCRM_DATABASE_PASSWORD" ".env")
OLD_MARIADB_ROOT_PASSWORD=$(read_env_value "MARIADB_ROOT_PASSWORD" ".env")
OLD_ESPOCRM_ADMIN_USERNAME=$(read_env_value "ESPOCRM_ADMIN_USERNAME" ".env")
OLD_ESPOCRM_ADMIN_PASSWORD=$(read_env_value "ESPOCRM_ADMIN_PASSWORD" ".env")
OLD_ESPOCRM_IMAGE=$(read_env_value "ESPOCRM_IMAGE" ".env")
OLD_MARIADB_IMAGE=$(read_env_value "MARIADB_IMAGE" ".env")
OLD_ESPOCRM_LANGUAGE=$(read_env_value "ESPOCRM_LANGUAGE" ".env")
OLD_ESPOCRM_TIME_ZONE=$(read_env_value "ESPOCRM_TIME_ZONE" ".env")

ESPOCRM_DB_NAME=${OLD_ESPOCRM_DB_NAME:-espocrm}
ESPOCRM_DB_USER=${OLD_ESPOCRM_DB_USER:-espocrm}
ESPOCRM_DB_PASSWORD=${OLD_ESPOCRM_DB_PASSWORD:-$(openssl rand -hex 20)}
MARIADB_ROOT_PASSWORD=${OLD_MARIADB_ROOT_PASSWORD:-$(openssl rand -hex 24)}
ESPOCRM_ADMIN_USERNAME=${OLD_ESPOCRM_ADMIN_USERNAME:-admin}
ESPOCRM_ADMIN_PASSWORD=${OLD_ESPOCRM_ADMIN_PASSWORD:-$(openssl rand -hex 12)}
ESPOCRM_IMAGE=${OLD_ESPOCRM_IMAGE:-espocrm/espocrm:latest}
MARIADB_IMAGE=${OLD_MARIADB_IMAGE:-mariadb:11.4}
if [[ "$APP_LANG" == "vi" ]]; then
    ESPOCRM_LANGUAGE=${OLD_ESPOCRM_LANGUAGE:-vi_VN}
else
    ESPOCRM_LANGUAGE=${OLD_ESPOCRM_LANGUAGE:-en_US}
fi
ESPOCRM_TIME_ZONE=${OLD_ESPOCRM_TIME_ZONE:-${TZ:-Etc/UTC}}

cat > .env <<ENVEOF
# =================================================================
# EspoCRM Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Access
ESPOCRM_HTTP_PORT=$APP_PORT
ESPOCRM_WS_PORT=$WS_PORT
ESPOCRM_SITE_URL=$APP_URL
ESPOCRM_WS_URL=$WS_URL
ESPOCRM_TIME_ZONE=$ESPOCRM_TIME_ZONE
ESPOCRM_LANGUAGE=$ESPOCRM_LANGUAGE

# Images
ESPOCRM_IMAGE=$ESPOCRM_IMAGE
MARIADB_IMAGE=$MARIADB_IMAGE

# Database (EspoCRM)
ESPOCRM_DATABASE_PLATFORM=Mysql
ESPOCRM_DATABASE_HOST=db
ESPOCRM_DATABASE_PORT=3306
ESPOCRM_DATABASE_NAME=$ESPOCRM_DB_NAME
ESPOCRM_DATABASE_USER=$ESPOCRM_DB_USER
ESPOCRM_DATABASE_PASSWORD=$ESPOCRM_DB_PASSWORD

# Database (MariaDB)
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
MARIADB_DATABASE=$ESPOCRM_DB_NAME
MARIADB_USER=$ESPOCRM_DB_USER
MARIADB_PASSWORD=$ESPOCRM_DB_PASSWORD

# Bootstrap admin (used on first install)
ESPOCRM_ADMIN_USERNAME=$ESPOCRM_ADMIN_USERNAME
ESPOCRM_ADMIN_PASSWORD=$ESPOCRM_ADMIN_PASSWORD
ENVEOF

pok "$(say "Saved .env with secure defaults." "Đã lưu .env với cấu hình bảo mật.")"

# ========================================
# Step 5: Docker Compose file
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

cat > docker-compose.yml <<'COMPOSEEOF'
name: espocrm

services:
  db:
    image: ${MARIADB_IMAGE:-mariadb:11.4}
    container_name: espocrm-db
    restart: unless-stopped
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max-allowed-packet=64M
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE:-espocrm}
      MARIADB_USER: ${MARIADB_USER:-espocrm}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      TZ: ${ESPOCRM_TIME_ZONE:-Etc/UTC}
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 20s
      start_period: 10s
      timeout: 10s
      retries: 10
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - espocrm-network

  app:
    image: ${ESPOCRM_IMAGE:-espocrm/espocrm:latest}
    container_name: espocrm
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "${ESPOCRM_HTTP_PORT:-8080}:80"
    environment:
      ESPOCRM_DATABASE_PLATFORM: ${ESPOCRM_DATABASE_PLATFORM:-Mysql}
      ESPOCRM_DATABASE_HOST: ${ESPOCRM_DATABASE_HOST:-db}
      ESPOCRM_DATABASE_PORT: ${ESPOCRM_DATABASE_PORT:-3306}
      ESPOCRM_DATABASE_NAME: ${ESPOCRM_DATABASE_NAME:-espocrm}
      ESPOCRM_DATABASE_USER: ${ESPOCRM_DATABASE_USER:-espocrm}
      ESPOCRM_DATABASE_PASSWORD: ${ESPOCRM_DATABASE_PASSWORD}
      ESPOCRM_ADMIN_USERNAME: ${ESPOCRM_ADMIN_USERNAME:-admin}
      ESPOCRM_ADMIN_PASSWORD: ${ESPOCRM_ADMIN_PASSWORD}
      ESPOCRM_LANGUAGE: ${ESPOCRM_LANGUAGE:-en_US}
      ESPOCRM_SITE_URL: ${ESPOCRM_SITE_URL:-http://localhost:8080}
      ESPOCRM_TIME_ZONE: ${ESPOCRM_TIME_ZONE:-Etc/UTC}
    volumes:
      - espocrm_data:/var/www/html
    networks:
      - espocrm-network

  daemon:
    image: ${ESPOCRM_IMAGE:-espocrm/espocrm:latest}
    container_name: espocrm-daemon
    restart: unless-stopped
    depends_on:
      - app
    entrypoint: docker-daemon.sh
    volumes:
      - espocrm_data:/var/www/html
    networks:
      - espocrm-network

  websocket:
    image: ${ESPOCRM_IMAGE:-espocrm/espocrm:latest}
    container_name: espocrm-websocket
    restart: unless-stopped
    depends_on:
      - app
    entrypoint: docker-websocket.sh
    environment:
      ESPOCRM_CONFIG_USE_WEB_SOCKET: "true"
      ESPOCRM_CONFIG_WEB_SOCKET_URL: ${ESPOCRM_WS_URL:-ws://localhost:8081}
      ESPOCRM_CONFIG_WEB_SOCKET_ZERO_M_Q_SUBSCRIBER_DSN: "tcp://*:7777"
      ESPOCRM_CONFIG_WEB_SOCKET_ZERO_M_Q_SUBMISSION_DSN: "tcp://websocket:7777"
    ports:
      - "${ESPOCRM_WS_PORT:-8081}:8080"
    volumes:
      - espocrm_data:/var/www/html
    networks:
      - espocrm-network

volumes:
  db_data:
  espocrm_data:

networks:
  espocrm-network:
    driver: bridge
COMPOSEEOF

pok "$(say "Docker Compose file generated." "Đã tạo file Docker Compose.")"

# ========================================
# Step 6: Compose validation
# ========================================
echo ""
echo -e "${BOLD}$(step_title 6)${NC}"

if [[ "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
    pwn "$(say "Skipping docker compose config in TEST MODE (compose unavailable)." "Bỏ qua docker compose config trong TEST MODE (compose chưa sẵn sàng).")"
elif dc config >/dev/null 2>&1; then
    pok "$(say "docker compose config: OK" "docker compose config: OK")"
else
    perr "$(say "docker compose config failed." "docker compose config lỗi.")"
fi

# ========================================
# Step 7: Start containers
# ========================================
echo ""
echo -e "${BOLD}$(step_title 7)${NC}"

if [[ "$TEST_MODE" == "1" || "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
    pwn "$(say "Test mode: skipping docker compose up." "Test mode: bỏ qua docker compose up.")"
else
    MAX_START_ATTEMPTS=${ESPOCRM_START_RETRIES:-3}
    SUCCESS_START=false

    dc down --remove-orphans >/dev/null 2>&1 || true

    for attempt in $(seq 1 "$MAX_START_ATTEMPTS"); do
        pwn "$(say "Starting stack (attempt $attempt/$MAX_START_ATTEMPTS)..." "Đang khởi động stack (lần $attempt/$MAX_START_ATTEMPTS)...")"
        if dc up -d --pull always; then
            SUCCESS_START=true
            break
        fi
        sleep 8
    done

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start EspoCRM stack." "Không thể khởi động stack EspoCRM.")"
    pok "$(say "Containers started." "Containers đã khởi động.")"
fi

# ========================================
# Step 8: Verify services
# ========================================
echo ""
echo -e "${BOLD}$(step_title 8)${NC}"

ALL_OK=true
LOCAL_URL="http://localhost:${APP_PORT}"
LOCAL_WS="ws://localhost:${WS_PORT}"

if [[ "$TEST_MODE" == "1" || "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
    pwn "$(say "Test mode: skipping runtime health checks." "Test mode: bỏ qua health check runtime.")"
else
    HEALTH_TIMEOUT=${ESPOCRM_HEALTH_TIMEOUT:-720}
    ELAPSED=0
    WEB_OK=false

    pwn "$(say "Waiting for EspoCRM web endpoint..." "Đang đợi endpoint web EspoCRM...")"
    while [[ "$ELAPSED" -lt "$HEALTH_TIMEOUT" ]]; do
        if curl -fsS "$LOCAL_URL" >/dev/null 2>&1; then
            WEB_OK=true
            break
        fi
        sleep 8
        ELAPSED=$((ELAPSED + 8))
    done

    if [[ "$WEB_OK" == "true" ]]; then
        pok "$(say "EspoCRM web is ready:" "EspoCRM web đã sẵn sàng:") $LOCAL_URL"
    else
        pwn "$(say "EspoCRM web health timeout:" "EspoCRM web health timeout:") $LOCAL_URL"
        ALL_OK=false
    fi

    if dc exec -T db mariadb-admin ping -h localhost -uroot -p"$MARIADB_ROOT_PASSWORD" >/dev/null 2>&1; then
        pok "MariaDB: ready"
    else
        pwn "MariaDB: not ready"
        ALL_OK=false
    fi

    SERVICE_WAIT_TIMEOUT=${ESPOCRM_SERVICE_WAIT_TIMEOUT:-180}
    for svc in db app daemon websocket; do
        SERVICE_OK=false
        SERVICE_ELAPSED=0

        while [[ "$SERVICE_ELAPSED" -le "$SERVICE_WAIT_TIMEOUT" ]]; do
            RUNNING_SERVICES=$(dc ps --status running --services 2>/dev/null || true)
            if echo "$RUNNING_SERVICES" | grep -qx "$svc"; then
                SERVICE_OK=true
                break
            fi

            sleep 5
            SERVICE_ELAPSED=$((SERVICE_ELAPSED + 5))
        done

        if [[ "$SERVICE_OK" == "true" ]]; then
            pok "$svc: running"
        else
            pwn "$svc: not running"
            ALL_OK=false
        fi
    done
fi

# ========================================
# Step 9: Helper & summary
# ========================================
echo ""
echo -e "${BOLD}$(step_title 9)${NC}"

cat > espocrm.sh <<'HELPEOF'
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

dc() {
  if docker info >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker compose "$@"
  else
    echo "Docker daemon is not accessible."
    exit 1
  fi
}

read_env() {
  local key="$1"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2- || true
}

app_url() {
  local value
  value=$(read_env "ESPOCRM_SITE_URL")
  echo "${value:-http://localhost:8080}"
}

ws_url() {
  local value
  value=$(read_env "ESPOCRM_WS_URL")
  echo "${value:-ws://localhost:8081}"
}

http_port() {
  local value
  value=$(read_env "ESPOCRM_HTTP_PORT")
  echo "${value:-8080}"
}

ws_port() {
  local value
  value=$(read_env "ESPOCRM_WS_PORT")
  echo "${value:-8081}"
}

db_name() {
  local value
  value=$(read_env "MARIADB_DATABASE")
  echo "${value:-espocrm}"
}

db_user() {
  local value
  value=$(read_env "MARIADB_USER")
  echo "${value:-espocrm}"
}

db_password() {
  local value
  value=$(read_env "MARIADB_PASSWORD")
  echo "${value:-}"
}

backup_name() {
  date +"backups/espocrm-db-backup-%Y%m%d-%H%M%S.sql"
}

case "${1:-}" in
  start)
    echo "Starting EspoCRM..."
    dc up -d --pull always
    echo "Started: $(app_url)"
    ;;
  stop)
    echo "Stopping EspoCRM..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting EspoCRM..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-app}"
    ;;
  health)
    PORT=$(http_port)
    WS_PORT=$(ws_port)
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "Web OK: http://localhost:${PORT}"
    else
      echo "Web failed: http://localhost:${PORT}"
      exit 1
    fi

    if dc exec -T db mariadb-admin ping -h localhost -uroot -p"$(read_env MARIADB_ROOT_PASSWORD)" >/dev/null 2>&1; then
      echo "DB OK"
    else
      echo "DB failed"
      exit 1
    fi

    if (echo > /dev/tcp/127.0.0.1/"${WS_PORT}") >/dev/null 2>&1; then
      echo "WebSocket port open: ${WS_PORT}"
    else
      echo "WebSocket port not reachable: ${WS_PORT}"
      exit 1
    fi
    ;;
  backup)
    mkdir -p backups
    FILE="$(backup_name)"
    USERNAME="$(db_user)"
    DATABASE="$(db_name)"
    PASSWORD="$(db_password)"
    if [[ -z "$PASSWORD" ]]; then
      echo "Database password is missing in .env"
      exit 1
    fi
    echo "Creating DB backup: $FILE"
    dc exec -T db mariadb-dump -u"$USERNAME" -p"$PASSWORD" "$DATABASE" > "$FILE"
    echo "Backup saved: $FILE"
    ;;
  db-shell)
    USERNAME="$(db_user)"
    DATABASE="$(db_name)"
    PASSWORD="$(db_password)"
    if [[ -z "$PASSWORD" ]]; then
      echo "Database password is missing in .env"
      exit 1
    fi
    dc exec db mariadb -u"$USERNAME" -p"$PASSWORD" "$DATABASE"
    ;;
  admin)
    echo "Initial admin bootstrap (first run only):"
    grep -E '^(ESPOCRM_ADMIN_USERNAME|ESPOCRM_ADMIN_PASSWORD)=' .env || true
    ;;
  upgrade)
    echo "Upgrading EspoCRM images..."
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  reset)
    echo "WARNING: This will DELETE all EspoCRM data volumes and backups."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      rm -rf backups
      mkdir -p backups
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "EspoCRM Helper"
    echo ""
    echo "Usage: ./espocrm.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start       - Start/upgrade stack"
    echo "  stop        - Stop services"
    echo "  restart     - Restart services"
    echo "  status      - Show service status"
    echo "  logs [svc]  - Follow logs (default: app)"
    echo "  health      - Check web, db and websocket ports"
    echo "  backup      - Backup MariaDB to backups/"
    echo "  db-shell    - Open MariaDB shell"
    echo "  admin       - Show bootstrap admin credentials"
    echo "  upgrade     - Pull latest images and restart"
    echo "  reset       - Delete all local data"
    ;;
esac
HELPEOF

chmod +x espocrm.sh
pok "$(say "Helper script created: ./espocrm.sh" "Đã tạo helper script: ./espocrm.sh")"

echo ""
echo "========================================================"
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${GREEN}  $(say "INSTALLATION COMPLETE" "CÀI ĐẶT HOÀN TẤT")${NC}"
else
    echo -e "${YELLOW}  $(say "INSTALL FINISHED WITH WARNINGS" "CÀI ĐẶT XONG (CÓ CẢNH BÁO)")${NC}"
fi
echo ""
echo -e "  $(say "Platform" "Nền tảng"):         ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "App URL" "URL truy cập"):       ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "WebSocket URL" "URL WebSocket"): ${PURPLE}${WS_URL}${NC}"
echo -e "  $(say "Local URL" "URL local"):        ${PURPLE}${LOCAL_URL}${NC}"
echo -e "  $(say "Directory" "Thư mục"):         ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  $(say "Backups" "Backups"):           ${CYAN}${INSTALL_DIR}/backups${NC}"

echo ""
echo -e "${CYAN}$(say "Admin bootstrap (first run only)" "Admin bootstrap (chỉ lần đầu)"):${NC}"
echo "  • ESPOCRM_ADMIN_USERNAME=$ESPOCRM_ADMIN_USERNAME"
echo "  • ESPOCRM_ADMIN_PASSWORD=$ESPOCRM_ADMIN_PASSWORD"

echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  • ./espocrm.sh status"
echo "  • ./espocrm.sh logs app"
echo "  • ./espocrm.sh health"
echo "  • ./espocrm.sh backup"
echo "  • ./espocrm.sh restart"
echo ""

echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  • $(say "Do not share .env (contains secrets)." "Không chia sẻ file .env (chứa secrets).")"
echo "  • $(say "The bootstrap admin password should be changed after first login." "Hãy đổi mật khẩu admin bootstrap sau lần đăng nhập đầu.")"
if [[ "$NETWORK_MODE" == "domain" ]]; then
    echo "  • $(say "Ensure reverse proxy forwards HTTP to http://127.0.0.1:${APP_PORT} and WebSocket to http://127.0.0.1:${WS_PORT}" "Đảm bảo reverse proxy trỏ HTTP về http://127.0.0.1:${APP_PORT} và WebSocket về http://127.0.0.1:${WS_PORT}")"
fi

echo ""
echo "Branding: vnROM Self-hosted Scripts"
echo "Support:  https://ai.vnrom.net"
echo "Docs:     https://github.com/espocrm/espocrm"
