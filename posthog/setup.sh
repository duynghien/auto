#!/bin/bash
################################################################
# PostHog Unified Auto-Install
# Supports: macOS (Apple Silicon/Intel), Raspberry Pi, VPS (amd64/arm64)
# Based on official PostHog docker-compose hobby deployment
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
        3) say "[3/9] Directory & source" "[3/9] Thư mục & source" ;;
        4) say "[4/9] Environment & secrets" "[4/9] Biến môi trường & secrets" ;;
        5) say "[5/9] Docker Compose files" "[5/9] Tạo file Docker Compose" ;;
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
    echo "           PostHog Setup — $PLATFORM_LABEL"
    echo "      Self-hosted Analytics · Replay · Feature Flags"
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

sync_posthog_source_snapshot() {
    local ref="${POSTHOG_SOURCE_REF:-master}"
    local archive_url="https://codeload.github.com/PostHog/posthog/tar.gz/refs/heads/${ref}"
    local archive_file=""
    local tmp_dir=""

    archive_file=$(mktemp)
    tmp_dir=$(mktemp -d)

    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 "$archive_url" -o "$archive_file"
    tar -xzf "$archive_file" -C "$tmp_dir" --strip-components=1

    rm -f "$archive_file"
    rm -rf posthog
    mv "$tmp_dir" posthog
}

prepare_test_source_stub() {
    mkdir -p posthog
    curl -fL --retry 2 --connect-timeout 15 --max-time 120 \
        https://raw.githubusercontent.com/PostHog/posthog/HEAD/docker-compose.base.yml \
        -o posthog/docker-compose.base.yml
    curl -fL --retry 2 --connect-timeout 15 --max-time 120 \
        https://raw.githubusercontent.com/PostHog/posthog/HEAD/docker-compose.hobby.yml \
        -o posthog/docker-compose.hobby.yml
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

TEST_MODE="${POSTHOG_SETUP_TEST_MODE:-0}"
SKIP_SOURCE_SYNC="${POSTHOG_SETUP_SKIP_SOURCE_SYNC:-0}"
if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "TEST MODE enabled: skip docker compose up and health check." "TEST MODE đã bật: bỏ qua docker compose up và health check.")"
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
        run_privileged apt-get update -qq
        run_privileged apt-get install -y -qq docker-compose-plugin
    fi

    run_privileged apt-get install -y -qq curl openssl python3 ca-certificates >/dev/null 2>&1 || true
fi

for cmd in curl openssl python3; do
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

if [[ "${DISK_GB:-0}" -lt 15 ]]; then
    perr "$(say "At least 15GB free disk is required." "Cần tối thiểu 15GB dung lượng trống.")"
fi

if [[ "$TOTAL_MEM_MB" -lt 8000 ]]; then
    pwn "$(say "PostHog hobby deploy is recommended with 8GB+ RAM." "PostHog hobby deploy khuyến nghị RAM 8GB+.")"

    if [[ "$PLATFORM" != "mac" ]]; then
        if ! swapon --show | grep -q '/swapfile'; then
            pwn "$(say "Creating 4GB swap to improve stability..." "Đang tạo swap 4GB để tăng ổn định...")"
            run_privileged fallocate -l 4G /swapfile 2>/dev/null || \
                run_privileged dd if=/dev/zero of=/swapfile bs=1M count=4096
            run_privileged chmod 600 /swapfile
            run_privileged mkswap /swapfile >/dev/null
            run_privileged swapon /swapfile
            if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
                echo '/swapfile none swap sw 0 0' | run_privileged tee -a /etc/fstab >/dev/null
            fi
            pok "$(say "Swap 4GB configured." "Đã cấu hình swap 4GB.")"
        else
            pok "$(say "Swap already exists." "Swap đã tồn tại.")"
        fi
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
    echo "    3) Domain (đi qua reverse proxy)"
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

read -rp "  $(say "HTTP port for PostHog" "Cổng HTTP cho PostHog") [8000]: " APP_PORT
APP_PORT=${APP_PORT:-8000}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid port." "Cổng không hợp lệ.")"
fi

if port_in_use "$APP_PORT"; then
    perr "$(say "Port is already in use:" "Cổng đang được sử dụng:") $APP_PORT"
fi

NETWORK_MODE="localhost"
APP_URL="http://localhost:${APP_PORT}"
ACCESS_HOST="localhost"

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
        ACCESS_HOST="$LAN_IP"
        APP_URL="http://${ACCESS_HOST}:${APP_PORT}"
        ;;
    3)
        NETWORK_MODE="domain"
        read -rp "  $(say "Enter public domain or URL (e.g. https://hog.example.com)" "Nhập domain hoặc URL public (ví dụ: https://hog.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ACCESS_HOST=$(host_from_url "$APP_URL")
        ;;
    *)
        NETWORK_MODE="localhost"
        ACCESS_HOST="localhost"
        APP_URL="http://localhost:${APP_PORT}"
        ;;
esac

DOMAIN_VALUE=$(host_from_url "$APP_URL")
[[ -z "$DOMAIN_VALUE" ]] && DOMAIN_VALUE="localhost"

SITE_URL="$APP_URL"
LIVESTREAM_URL="${SITE_URL%/}/livestream"
OBJECT_STORAGE_PUBLIC_ENDPOINT="$SITE_URL"
CADDY_TLS_BLOCK="auto_https off"
CADDY_HOST=":80"
LOCAL_HEALTH_URL="http://localhost:${APP_PORT}/_health"

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"

# ========================================
# Step 3: Directory & source
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

INSTALL_DIR="$HOME/self-hosted/posthog"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

if [[ "$SKIP_SOURCE_SYNC" == "1" ]]; then
    if [[ ! -d posthog ]]; then
        if [[ "$TEST_MODE" == "1" ]]; then
            pwn "$(say "Creating minimal PostHog source stub for test mode..." "Đang tạo source stub PostHog tối thiểu cho test mode...")"
            prepare_test_source_stub
            pok "$(say "Minimal source stub ready." "Source stub tối thiểu đã sẵn sàng.")"
        else
            perr "$(say "POSTHOG_SETUP_SKIP_SOURCE_SYNC=1 but posthog source is missing." "POSTHOG_SETUP_SKIP_SOURCE_SYNC=1 nhưng thiếu source posthog.")"
        fi
    fi

    if [[ ! -f posthog/docker-compose.base.yml || ! -f posthog/docker-compose.hobby.yml ]]; then
        if [[ "$TEST_MODE" == "1" ]]; then
            pwn "$(say "Source exists but compose files are missing. Rebuilding test stub..." "Source có sẵn nhưng thiếu compose files. Đang dựng lại test stub...")"
            prepare_test_source_stub
            pok "$(say "Compose stub files restored." "Đã khôi phục compose stub files.")"
        else
            perr "$(say "Source folder is incomplete. Disable skip mode or re-sync source." "Source chưa đầy đủ. Hãy tắt skip mode hoặc đồng bộ source lại.")"
        fi
    fi

    pwn "$(say "Skipping source sync (POSTHOG_SETUP_SKIP_SOURCE_SYNC=1)." "Bỏ qua đồng bộ source (POSTHOG_SETUP_SKIP_SOURCE_SYNC=1).")"
else
    if [[ ! -d posthog ]]; then
        pwn "$(say "Downloading PostHog source snapshot..." "Đang tải source snapshot PostHog...")"
        sync_posthog_source_snapshot
        pok "$(say "PostHog source downloaded." "Đã tải source PostHog.")"
    else
        pwn "$(say "Refreshing PostHog source snapshot..." "Đang làm mới source snapshot PostHog...")"
        sync_posthog_source_snapshot
        pok "$(say "PostHog source refreshed." "Đã làm mới source PostHog.")"
    fi
fi

read -rp "  $(say "PostHog image tag" "Tag image PostHog") [latest]: " POSTHOG_APP_TAG
POSTHOG_APP_TAG=${POSTHOG_APP_TAG:-latest}
read -rp "  $(say "PostHog Node image tag" "Tag image PostHog Node") [latest]: " POSTHOG_NODE_TAG
POSTHOG_NODE_TAG=${POSTHOG_NODE_TAG:-latest}

# ========================================
# Step 4: Environment & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

OLD_POSTHOG_SECRET=$(read_env_value "POSTHOG_SECRET" ".env")
OLD_ENCRYPTION_SALT_KEYS=$(read_env_value "ENCRYPTION_SALT_KEYS" ".env")
OLD_REGISTRY_URL=$(read_env_value "REGISTRY_URL" ".env")
OLD_OPT_OUT_CAPTURE=$(read_env_value "OPT_OUT_CAPTURE" ".env")

POSTHOG_SECRET=${OLD_POSTHOG_SECRET:-$(openssl rand -hex 28)}
ENCRYPTION_SALT_KEYS=${OLD_ENCRYPTION_SALT_KEYS:-$(openssl rand -hex 16)}
REGISTRY_URL=${OLD_REGISTRY_URL:-posthog/posthog}
OPT_OUT_CAPTURE=${OLD_OPT_OUT_CAPTURE:-false}

cat > .env <<ENVEOF
# =================================================================
# PostHog Hobby Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Core PostHog settings
POSTHOG_SECRET=$POSTHOG_SECRET
ENCRYPTION_SALT_KEYS=$ENCRYPTION_SALT_KEYS
DOMAIN=$DOMAIN_VALUE
REGISTRY_URL=$REGISTRY_URL
POSTHOG_APP_TAG=$POSTHOG_APP_TAG
POSTHOG_NODE_TAG=$POSTHOG_NODE_TAG
OPT_OUT_CAPTURE=$OPT_OUT_CAPTURE

# Portable networking (override file uses these)
SITE_URL=$SITE_URL
LIVESTREAM_URL=$LIVESTREAM_URL
OBJECT_STORAGE_PUBLIC_ENDPOINT=$OBJECT_STORAGE_PUBLIC_ENDPOINT
POSTHOG_HTTP_PORT=$APP_PORT
CADDY_TLS_BLOCK=$CADDY_TLS_BLOCK
CADDY_HOST=$CADDY_HOST

# Keep compatibility with official hobby compose variables
TLS_BLOCK=$CADDY_TLS_BLOCK
ELAPSED=0
TIMEOUT=60
ENVEOF

pok "$(say "Saved .env with secure secrets." "Đã lưu .env với secrets bảo mật.")"

# ========================================
# Step 5: Docker Compose files
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

mkdir -p compose share

cp -f posthog/docker-compose.base.yml docker-compose.base.yml
cp -f posthog/docker-compose.hobby.yml docker-compose.yml

cat > docker-compose.override.yml <<'OVEREOF'
services:
  proxy:
    ports:
      - "${POSTHOG_HTTP_PORT}:80"
    environment:
      CADDY_TLS_BLOCK: "${CADDY_TLS_BLOCK}"
      CADDY_HOST: "${CADDY_HOST}"

  worker:
    environment:
      SITE_URL: "${SITE_URL}"
      OBJECT_STORAGE_PUBLIC_ENDPOINT: "${OBJECT_STORAGE_PUBLIC_ENDPOINT}"

  web:
    environment:
      SITE_URL: "${SITE_URL}"
      LIVESTREAM_HOST: "${LIVESTREAM_URL}"
      OBJECT_STORAGE_PUBLIC_ENDPOINT: "${OBJECT_STORAGE_PUBLIC_ENDPOINT}"

  plugins:
    environment:
      SITE_URL: "${SITE_URL}"
      OBJECT_STORAGE_PUBLIC_ENDPOINT: "${OBJECT_STORAGE_PUBLIC_ENDPOINT}"

  asyncmigrationscheck:
    environment:
      SITE_URL: "${SITE_URL}"

  temporal-django-worker:
    profiles: ["temporal"]
    environment:
      SITE_URL: "${SITE_URL}"

  temporal:
    profiles: ["temporal"]

  temporal-ui:
    profiles: ["temporal"]

  temporal-admin-tools:
    profiles: ["temporal"]

  elasticsearch:
    profiles: ["temporal"]

  cymbal:
    profiles: ["exceptions"]

  cyclotron-janitor:
    profiles: ["exceptions"]
OVEREOF

cat > compose/start <<'SCRIPTEOF'
#!/bin/bash
set -e
/compose/wait
./bin/migrate
./bin/docker-server
SCRIPTEOF

cat > compose/temporal-django-worker <<'SCRIPTEOF'
#!/bin/bash
set -e
./bin/temporal-django-worker
SCRIPTEOF

cat > compose/wait <<'PYEOF'
#!/usr/bin/env python3
import socket
import time

def wait_for(host, port, name):
    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(2)
                s.connect((host, port))
            print(f"{name} is ready")
            return
        except OSError:
            print(f"Waiting for {name} ({host}:{port})...")
            time.sleep(5)

wait_for("clickhouse", 9000, "ClickHouse")
wait_for("db", 5432, "Postgres")
PYEOF

chmod +x compose/start compose/temporal-django-worker compose/wait

if [[ ! -f share/GeoLite2-City.mmdb ]]; then
    if [[ "$TEST_MODE" == "1" || "${POSTHOG_SETUP_SKIP_GEOIP:-0}" == "1" ]]; then
        pwn "$(say "Skipping GeoIP download in test mode." "Bỏ qua tải GeoIP trong test mode.")"
    elif command -v brotli >/dev/null 2>&1; then
        pwn "$(say "Downloading GeoIP database..." "Đang tải GeoIP database...")"
        if curl -fsSL --http1.1 https://mmdbcdn.posthog.net/ | brotli --decompress > share/GeoLite2-City.mmdb; then
            echo "{\"date\":\"$(date +%F)\"}" > share/GeoLite2-City.json
            chmod 644 share/GeoLite2-City.mmdb share/GeoLite2-City.json
            pok "$(say "GeoIP database downloaded." "Đã tải GeoIP database.")"
        else
            rm -f share/GeoLite2-City.mmdb
            pwn "$(say "Could not download GeoIP database (optional)." "Không tải được GeoIP database (không bắt buộc).")"
        fi
    else
        pwn "$(say "brotli not found, skipping GeoIP download (optional)." "Không có brotli, bỏ qua tải GeoIP (không bắt buộc).")"
    fi
fi

pok "$(say "Compose files prepared." "Đã chuẩn bị xong file Compose.")"

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
    pwn "$(say "Test mode: skipping 'docker compose up'." "Test mode: bỏ qua 'docker compose up'.")"
else
    MAX_START_ATTEMPTS=${POSTHOG_START_RETRIES:-5}
    PULL_PARALLEL_LIMIT=${POSTHOG_PULL_PARALLEL_LIMIT:-4}
    SUCCESS_START=false
    for attempt in $(seq 1 "$MAX_START_ATTEMPTS"); do
        pwn "$(say "Starting stack (attempt $attempt/$MAX_START_ATTEMPTS, parallel limit=$PULL_PARALLEL_LIMIT)..." "Đang khởi động stack (lần $attempt/$MAX_START_ATTEMPTS, giới hạn pull song song=$PULL_PARALLEL_LIMIT)...")"
        if COMPOSE_PARALLEL_LIMIT="$PULL_PARALLEL_LIMIT" dc up -d --pull always --build; then
            SUCCESS_START=true
            break
        fi
        sleep 20
    done

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start PostHog stack." "Không thể khởi động stack PostHog.")"
    pok "$(say "Containers started." "Containers đã khởi động.")"
fi

# ========================================
# Step 8: Verify services
# ========================================
echo ""
echo -e "${BOLD}$(step_title 8)${NC}"

ALL_OK=true

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping runtime health checks." "Test mode: bỏ qua health check runtime.")"
else
    HEALTH_TIMEOUT=${POSTHOG_HEALTH_TIMEOUT:-1200}
    ELAPSED=0
    HEALTH_OK=false

    pwn "$(say "Waiting for PostHog health endpoint..." "Đang đợi health endpoint của PostHog...")"
    while [[ "$ELAPSED" -lt "$HEALTH_TIMEOUT" ]]; do
        if curl -fsS "$LOCAL_HEALTH_URL" >/dev/null 2>&1; then
            HEALTH_OK=true
            break
        fi
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done

    if [[ "$HEALTH_OK" == "true" ]]; then
        pok "$(say "Health endpoint is ready:" "Health endpoint đã sẵn sàng:") $LOCAL_HEALTH_URL"
    else
        pwn "$(say "Health check timeout:" "Health check timeout:") $LOCAL_HEALTH_URL"
        ALL_OK=false
    fi

    RUNNING_SERVICES=$(dc ps --status running --services 2>/dev/null || true)
    for svc in proxy web db redis7 clickhouse kafka plugins worker; do
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

cat > hog.sh <<'HELPEOF'
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
  grep '^SITE_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:8000"
}

http_port() {
  grep '^POSTHOG_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "8000"
}

compose_up() {
  local parallel="${POSTHOG_PULL_PARALLEL_LIMIT:-4}"
  COMPOSE_PARALLEL_LIMIT="$parallel" dc up -d --pull always --build
}

refresh_source_snapshot() {
  local ref="${POSTHOG_SOURCE_REF:-master}"
  local archive_url="https://codeload.github.com/PostHog/posthog/tar.gz/refs/heads/${ref}"
  local archive_file=""
  local tmp_dir=""

  archive_file=$(mktemp)
  tmp_dir=$(mktemp -d)

  curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 "$archive_url" -o "$archive_file"
  tar -xzf "$archive_file" -C "$tmp_dir" --strip-components=1

  rm -f "$archive_file"
  rm -rf posthog
  mv "$tmp_dir" posthog
}

case "${1:-}" in
  start)
    echo "🚀 Starting PostHog..."
    compose_up
    echo "✅ Started: $(app_url)"
    ;;
  start-full)
    echo "🚀 Starting PostHog with optional profiles (temporal + exceptions)..."
    COMPOSE_PARALLEL_LIMIT="${POSTHOG_PULL_PARALLEL_LIMIT:-4}" dc --profile temporal --profile exceptions up -d --pull always --build
    echo "✅ Full stack started: $(app_url)"
    ;;
  stop)
    echo "🛑 Stopping PostHog..."
    dc stop
    echo "✅ Stopped"
    ;;
  restart)
    echo "🔄 Restarting PostHog..."
    dc restart
    echo "✅ Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-web}"
    ;;
  health)
    PORT=$(http_port)
    if curl -fsS "http://localhost:${PORT}/_health" >/dev/null 2>&1; then
      echo "✅ Health OK: http://localhost:${PORT}/_health"
    else
      echo "❌ Health failed: http://localhost:${PORT}/_health"
      exit 1
    fi
    ;;
  upgrade)
    echo "⬆️  Upgrading PostHog source and containers..."
    if [[ -d posthog ]]; then
      refresh_source_snapshot || true
      cp -f posthog/docker-compose.base.yml docker-compose.base.yml
      cp -f posthog/docker-compose.hobby.yml docker-compose.yml
    fi
    compose_up
    echo "✅ Upgrade complete"
    ;;
  reset)
    echo "⚠️  This will DELETE all PostHog data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      rm -rf compose share
      echo "✅ Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "PostHog Helper"
    echo ""
    echo "Usage: ./hog.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start      - Start/upgrade stack"
    echo "  start-full - Start with optional profiles (temporal + exceptions)"
    echo "  stop       - Stop services"
    echo "  restart    - Restart services"
    echo "  status     - Show service status"
    echo "  logs [svc] - Follow logs (default: web)"
    echo "  health     - Check /_health endpoint"
    echo "  upgrade    - Pull latest source and restart"
    echo "  reset      - Delete all local data"
    ;;
esac
HELPEOF

chmod +x hog.sh
pok "$(say "Helper script created: ./hog.sh" "Đã tạo helper script: ./hog.sh")"

echo ""
echo "========================================================"
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${GREEN}  $(say "INSTALLATION COMPLETE" "CÀI ĐẶT HOÀN TẤT")${NC}"
else
    echo -e "${YELLOW}  $(say "INSTALL FINISHED WITH WARNINGS" "CÀI ĐẶT XONG (CÓ CẢNH BÁO)")${NC}"
fi
echo ""
echo -e "  $(say "Platform" "Nền tảng"):        ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "App URL" "URL truy cập"):      ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Health URL" "URL health"):     ${PURPLE}${LOCAL_HEALTH_URL}${NC}"
echo -e "  $(say "Directory" "Thư mục"):        ${CYAN}${INSTALL_DIR}${NC}"

echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  • ./hog.sh status"
echo "  • ./hog.sh logs web"
echo "  • ./hog.sh health"
echo "  • ./hog.sh restart"
echo "  • ./hog.sh upgrade"
echo "  • ./hog.sh start-full"
echo ""

echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  • $(say "Do not share .env (contains secrets)." "Không chia sẻ file .env (chứa secrets).")"
echo "  • $(say "PostHog hobby deployment is best with 8GB+ RAM." "PostHog hobby chạy tốt nhất với RAM 8GB+.")"
if [[ "$NETWORK_MODE" == "domain" ]]; then
    echo "  • $(say "Ensure reverse proxy forwards domain to http://127.0.0.1:${APP_PORT}" "Đảm bảo reverse proxy trỏ domain vào http://127.0.0.1:${APP_PORT}")"
fi

echo ""
echo "Support: https://ai.vnrom.net"
echo "Docs:    https://posthog.com/docs/self-host/deploy/hobby"
