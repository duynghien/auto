#!/bin/bash
################################################################
# Matomo Unified Auto-Install
# Supports: macOS (Apple Silicon/Intel), Raspberry Pi, VPS (amd64/arm64)
# Based on official matomo + mariadb Docker deployment
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
    echo "           Matomo Setup — $PLATFORM_LABEL"
    echo "      Self-hosted Analytics · Privacy-first"
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

TEST_MODE="${MATOMO_SETUP_TEST_MODE:-0}"
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
        perr "$(say "Docker is not installed. Install OrbStack or Docker Desktop first." "Docker chưa được cài. Hãy cài OrbStack hoặc Docker Desktop trước.")"
    fi

    if ! docker info >/dev/null 2>&1; then
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
        docker info >/dev/null 2>&1 || perr "$(say "Docker daemon is still not available." "Docker daemon vẫn chưa sẵn sàng.")"
    fi

    if ! docker compose version >/dev/null 2>&1; then
        perr "$(say "Docker Compose plugin not found." "Không tìm thấy Docker Compose plugin.")"
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
            perr "$(say "Please install Docker Compose plugin manually for this distro." "Vui lòng cài Docker Compose plugin thủ công cho distro này.")"
        fi
    fi

    install_linux_package curl
    install_linux_package openssl
    install_linux_package ca-certificates
fi

for cmd in curl openssl awk sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        perr "$(say "Missing required command:" "Thiếu command bắt buộc:") $cmd"
    fi
done

refresh_docker_cmd || perr "$(say "Docker daemon is not accessible." "Không thể truy cập Docker daemon.")"
dc version >/dev/null 2>&1 || perr "$(say "Docker Compose command is not ready." "Docker Compose chưa sẵn sàng.")"

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

if [[ "$TOTAL_MEM_MB" -lt 2000 ]]; then
    pwn "$(say "Matomo is recommended with 2GB+ RAM for stable usage." "Matomo khuyến nghị RAM 2GB+ để chạy ổn định.")"
fi

if [[ "$PLATFORM" == "pi" && "$TOTAL_MEM_MB" -lt 3000 ]]; then
    if ! swapon --show | grep -q '/swapfile'; then
        pwn "$(say "Creating 2GB swap for Raspberry Pi..." "Đang tạo swap 2GB cho Raspberry Pi...")"
        run_privileged fallocate -l 2G /swapfile 2>/dev/null || run_privileged dd if=/dev/zero of=/swapfile bs=1M count=2048
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

read -rp "  $(say "HTTP port for Matomo" "Cổng HTTP cho Matomo") [8080]: " APP_PORT
APP_PORT=${APP_PORT:-8080}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid port." "Cổng không hợp lệ.")"
fi

if port_in_use "$APP_PORT"; then
    perr "$(say "Port is already in use:" "Cổng đang được sử dụng:") $APP_PORT"
fi

NETWORK_MODE="localhost"
APP_URL="http://localhost:${APP_PORT}"
ACCESS_HOST="localhost:${APP_PORT}"

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
        ACCESS_HOST="${LAN_IP}:${APP_PORT}"
        APP_URL="http://${ACCESS_HOST}"
        ;;
    3)
        NETWORK_MODE="domain"
        read -rp "  $(say "Enter public domain or URL (e.g. https://analytics.example.com)" "Nhập domain hoặc URL public (ví dụ: https://analytics.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ACCESS_HOST=$(host_from_url "$APP_URL")
        ;;
    *)
        NETWORK_MODE="localhost"
        ACCESS_HOST="localhost:${APP_PORT}"
        APP_URL="http://localhost:${APP_PORT}"
        ;;
esac

TRUSTED_HOSTS_VALUE="$ACCESS_HOST"
[[ -z "$TRUSTED_HOSTS_VALUE" ]] && TRUSTED_HOSTS_VALUE="localhost:${APP_PORT}"

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"

# ========================================
# Step 3: Directory setup
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

INSTALL_DIR="$HOME/self-hosted/matomo"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

# ========================================
# Step 4: Environment & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

OLD_MARIADB_ROOT_PASSWORD=$(read_env_value "MARIADB_ROOT_PASSWORD" ".env")
OLD_MARIADB_DATABASE=$(read_env_value "MARIADB_DATABASE" ".env")
OLD_MARIADB_USER=$(read_env_value "MARIADB_USER" ".env")
OLD_MARIADB_PASSWORD=$(read_env_value "MARIADB_PASSWORD" ".env")
OLD_MATOMO_IMAGE_TAG=$(read_env_value "MATOMO_IMAGE_TAG" ".env")
OLD_MARIADB_IMAGE=$(read_env_value "MARIADB_IMAGE" ".env")
OLD_MATOMO_TABLES_PREFIX=$(read_env_value "MATOMO_TABLES_PREFIX" ".env")
OLD_MATOMO_TIMEZONE=$(read_env_value "MATOMO_TIMEZONE" ".env")

MARIADB_ROOT_PASSWORD=${OLD_MARIADB_ROOT_PASSWORD:-$(openssl rand -hex 24)}
MARIADB_DATABASE=${OLD_MARIADB_DATABASE:-matomo}
MARIADB_USER=${OLD_MARIADB_USER:-matomo}
MARIADB_PASSWORD=${OLD_MARIADB_PASSWORD:-$(openssl rand -hex 18)}
MATOMO_IMAGE_TAG=${OLD_MATOMO_IMAGE_TAG:-latest}
MARIADB_IMAGE=${OLD_MARIADB_IMAGE:-mariadb:11.4}
MATOMO_TABLES_PREFIX=${OLD_MATOMO_TABLES_PREFIX:-matomo_}
MATOMO_TIMEZONE=${OLD_MATOMO_TIMEZONE:-${TZ:-Etc/UTC}}

cat > .env <<ENVEOF
# =================================================================
# Matomo Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Access
MATOMO_HTTP_PORT=$APP_PORT
MATOMO_URL=$APP_URL
MATOMO_TRUSTED_HOSTS=$TRUSTED_HOSTS_VALUE
MATOMO_TIMEZONE=$MATOMO_TIMEZONE

# Image tags
MATOMO_IMAGE_TAG=$MATOMO_IMAGE_TAG
MARIADB_IMAGE=$MARIADB_IMAGE

# Database
MARIADB_ROOT_PASSWORD=$MARIADB_ROOT_PASSWORD
MARIADB_DATABASE=$MARIADB_DATABASE
MARIADB_USER=$MARIADB_USER
MARIADB_PASSWORD=$MARIADB_PASSWORD

# Matomo DB config
MATOMO_TABLES_PREFIX=$MATOMO_TABLES_PREFIX
ENVEOF

pok "$(say "Saved .env with secure defaults." "Đã lưu .env với cấu hình bảo mật.")"

# ========================================
# Step 5: Docker Compose file
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

cat > docker-compose.yml <<'COMPOSEEOF'
name: matomo

services:
  db:
    image: ${MARIADB_IMAGE:-mariadb:11.4}
    container_name: matomo-db
    restart: unless-stopped
    command:
      - --max-allowed-packet=128M
      - --transaction-isolation=READ-COMMITTED
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      TZ: ${MATOMO_TIMEZONE:-Etc/UTC}
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -h localhost -uroot -p${MARIADB_ROOT_PASSWORD} --silent || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 30s
    networks:
      - matomo-network

  matomo:
    image: matomo:${MATOMO_IMAGE_TAG:-latest}
    container_name: matomo-app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "${MATOMO_HTTP_PORT:-8080}:80"
    environment:
      MATOMO_DATABASE_HOST: db
      MATOMO_DATABASE_ADAPTER: mysql
      MATOMO_DATABASE_TABLES_PREFIX: ${MATOMO_TABLES_PREFIX:-matomo_}
      MATOMO_DATABASE_USERNAME: ${MARIADB_USER}
      MATOMO_DATABASE_PASSWORD: ${MARIADB_PASSWORD}
      MATOMO_DATABASE_DBNAME: ${MARIADB_DATABASE}
      "MATOMO_GENERAL_TRUSTED_HOSTS[]": ${MATOMO_TRUSTED_HOSTS}
      PHP_MEMORY_LIMIT: 512M
      PHP_MAX_EXECUTION_TIME: 120
      TZ: ${MATOMO_TIMEZONE:-Etc/UTC}
    volumes:
      - matomo_data:/var/www/html
    networks:
      - matomo-network

volumes:
  db_data:
  matomo_data:

networks:
  matomo-network:
    driver: bridge
COMPOSEEOF

pok "$(say "Docker Compose file generated." "Đã tạo file Docker Compose.")"

# ========================================
# Step 6: Compose validation
# ========================================
echo ""
echo -e "${BOLD}$(step_title 6)${NC}"

if dc config >/dev/null 2>&1; then
    pok "$(say "docker compose config: OK" "docker compose config: OK")"
else
    perr "$(say "docker compose config failed." "docker compose config lỗi.")"
fi

# ========================================
# Step 7: Start containers
# ========================================
echo ""
echo -e "${BOLD}$(step_title 7)${NC}"

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping docker compose up." "Test mode: bỏ qua docker compose up.")"
else
    MAX_START_ATTEMPTS=${MATOMO_START_RETRIES:-3}
    SUCCESS_START=false

    for attempt in $(seq 1 "$MAX_START_ATTEMPTS"); do
        pwn "$(say "Starting stack (attempt $attempt/$MAX_START_ATTEMPTS)..." "Đang khởi động stack (lần $attempt/$MAX_START_ATTEMPTS)...")"
        if dc up -d --pull always; then
            SUCCESS_START=true
            break
        fi
        sleep 10
    done

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start Matomo stack." "Không thể khởi động stack Matomo.")"
    pok "$(say "Containers started." "Containers đã khởi động.")"
fi

# ========================================
# Step 8: Verify services
# ========================================
echo ""
echo -e "${BOLD}$(step_title 8)${NC}"

ALL_OK=true
LOCAL_URL="http://localhost:${APP_PORT}"

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping runtime health checks." "Test mode: bỏ qua health check runtime.")"
else
    HEALTH_TIMEOUT=${MATOMO_HEALTH_TIMEOUT:-600}
    ELAPSED=0
    WEB_OK=false

    pwn "$(say "Waiting for Matomo web endpoint..." "Đang đợi endpoint web Matomo...")"
    while [[ "$ELAPSED" -lt "$HEALTH_TIMEOUT" ]]; do
        if curl -fsS "$LOCAL_URL" >/dev/null 2>&1; then
            WEB_OK=true
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [[ "$WEB_OK" == "true" ]]; then
        pok "$(say "Matomo web is ready:" "Matomo web đã sẵn sàng:") $LOCAL_URL"
    else
        pwn "$(say "Matomo web health timeout:" "Matomo web health timeout:") $LOCAL_URL"
        ALL_OK=false
    fi

    if dc exec -T db mariadb-admin ping -h localhost -uroot -p"$MARIADB_ROOT_PASSWORD" --silent >/dev/null 2>&1; then
        pok "MariaDB: ready"
    else
        pwn "MariaDB: not ready"
        ALL_OK=false
    fi

    RUNNING_SERVICES=$(dc ps --status running --services 2>/dev/null || true)
    for svc in db matomo; do
        if echo "$RUNNING_SERVICES" | grep -qx "$svc"; then
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

cat > matomo.sh <<'HELPEOF'
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

app_url() {
  grep '^MATOMO_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:8080"
}

http_port() {
  grep '^MATOMO_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "8080"
}

backup_name() {
  date +"matomo-db-backup-%Y%m%d-%H%M%S.sql"
}

case "${1:-}" in
  start)
    echo "🚀 Starting Matomo..."
    dc up -d --pull always
    echo "✅ Started: $(app_url)"
    ;;
  stop)
    echo "🛑 Stopping Matomo..."
    dc stop
    echo "✅ Stopped"
    ;;
  restart)
    echo "🔄 Restarting Matomo..."
    dc restart
    echo "✅ Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-matomo}"
    ;;
  health)
    PORT=$(http_port)
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "✅ Health OK: http://localhost:${PORT}"
    else
      echo "❌ Health failed: http://localhost:${PORT}"
      exit 1
    fi
    ;;
  backup)
    FILE="$(backup_name)"
    echo "📦 Creating DB backup: $FILE"
    dc exec -T db sh -c 'exec mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' > "$FILE"
    echo "✅ Backup saved: $FILE"
    ;;
  upgrade)
    echo "⬆️  Upgrading Matomo images..."
    dc pull
    dc up -d
    echo "✅ Upgrade complete"
    ;;
  reset)
    echo "⚠️  This will DELETE all Matomo data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "✅ Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Matomo Helper"
    echo ""
    echo "Usage: ./matomo.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start      - Start/upgrade stack"
    echo "  stop       - Stop services"
    echo "  restart    - Restart services"
    echo "  status     - Show service status"
    echo "  logs [svc] - Follow logs (default: matomo)"
    echo "  health     - Check Matomo web endpoint"
    echo "  backup     - Backup MariaDB to current directory"
    echo "  upgrade    - Pull latest images and restart"
    echo "  reset      - Delete all local data"
    ;;
esac
HELPEOF

chmod +x matomo.sh
pok "$(say "Helper script created: ./matomo.sh" "Đã tạo helper script: ./matomo.sh")"

echo ""
echo "========================================================"
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${GREEN}  $(say "INSTALLATION COMPLETE" "CÀI ĐẶT HOÀN TẤT")${NC}"
else
    echo -e "${YELLOW}  $(say "INSTALL FINISHED WITH WARNINGS" "CÀI ĐẶT XONG (CÓ CẢNH BÁO)")${NC}"
fi
echo ""
echo -e "  $(say "Platform" "Nền tảng"):       ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "App URL" "URL truy cập"):     ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Local URL" "URL local"):      ${PURPLE}${LOCAL_URL}${NC}"
echo -e "  $(say "Directory" "Thư mục"):       ${CYAN}${INSTALL_DIR}${NC}"

echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  • ./matomo.sh status"
echo "  • ./matomo.sh logs matomo"
echo "  • ./matomo.sh health"
echo "  • ./matomo.sh backup"
echo "  • ./matomo.sh restart"
echo ""

echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  • $(say "Do not share .env (contains secrets)." "Không chia sẻ file .env (chứa secrets).")"
echo "  • $(say "Complete Matomo web installer at first access." "Hoàn tất trình cài đặt web Matomo khi truy cập lần đầu.")"
if [[ "$NETWORK_MODE" == "domain" ]]; then
    echo "  • $(say "Ensure reverse proxy forwards your domain to http://127.0.0.1:${APP_PORT}" "Đảm bảo reverse proxy trỏ domain vào http://127.0.0.1:${APP_PORT}")"
fi

echo ""
echo "Branding: vnROM Self-hosted Scripts"
echo "Support:  https://ai.vnrom.net"
echo "Docs:     https://github.com/matomo-org/matomo"
