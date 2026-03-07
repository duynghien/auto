#!/bin/bash
################################################################
# n8n Unified Auto-Install
# Supports: macOS, Raspberry Pi, VPS (amd64/arm64)
# Features: worker, queue mode, postgres, redis, FFmpeg, Puppeteer, runners
# Based on official n8n docker deployment patterns
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
pwn()  { echo -e "${YELLOW}  !${NC} $1"; }
perr() { echo -e "${RED}  x${NC} $1"; exit 1; }

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
        1) say "[1/10] System check" "[1/10] Kiểm tra hệ thống" ;;
        2) say "[2/10] Access mode" "[2/10] Chế độ truy cập" ;;
        3) say "[3/10] n8n options" "[3/10] Tùy chọn n8n" ;;
        4) say "[4/10] Directory & secrets" "[4/10] Thư mục & secrets" ;;
        5) say "[5/10] Docker files" "[5/10] Tạo file Docker" ;;
        6) say "[6/10] Compose validation" "[6/10] Kiểm tra Compose" ;;
        7) say "[7/10] Start containers" "[7/10] Khởi động containers" ;;
        8) say "[8/10] Verify services" "[8/10] Xác minh services" ;;
        9) say "[9/10] Helper script" "[9/10] Script quản lý" ;;
        10) say "[10/10] Summary" "[10/10] Tổng kết" ;;
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
    echo "            n8n Setup — $PLATFORM_LABEL"
    echo "        Automation Workflow Self-Hosted Stack"
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

scheme_from_url() {
    local url="$1"
    echo "$url" | sed -E 's#^([a-zA-Z]+)://.*#\1#'
}

read_env_value() {
    local key="$1"
    local file="$2"
    local line=""

    [[ -f "$file" ]] || return 0
    line=$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)
    [[ -n "$line" ]] && echo "${line#*=}"
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

ask_yes_no() {
    local prompt_en="$1"
    local prompt_vi="$2"
    local default="${3:-n}"
    local answer=""
    local normalized=""

    if [[ "$default" == "y" ]]; then
        read -rp "  $(say "$prompt_en [Y/n]: " "$prompt_vi [Y/n]: ")" answer
        answer="${answer:-y}"
    else
        read -rp "  $(say "$prompt_en [y/N]: " "$prompt_vi [y/N]: ")" answer
        answer="${answer:-n}"
    fi

    normalized=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    case "$normalized" in
        y|yes|1|c|co|có)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

ask_number() {
    local prompt_en="$1"
    local prompt_vi="$2"
    local default="$3"
    local min="$4"
    local max="$5"
    local value=""

    while true; do
        read -rp "  $(say "$prompt_en [$default]: " "$prompt_vi [$default]: ")" value
        value="${value:-$default}"

        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= min && value <= max )); then
            echo "$value"
            return
        fi

        pwn "$(say "Invalid number. Please enter ${min}-${max}." "Số không hợp lệ. Vui lòng nhập ${min}-${max}.")"
    done
}

detect_timezone() {
    if [[ -n "${TZ:-}" ]]; then
        echo "$TZ"
        return
    fi

    if [[ "$PLATFORM" == "mac" ]] && command -v systemsetup >/dev/null 2>&1; then
        local tz
        tz=$(systemsetup -gettimezone 2>/dev/null | awk -F': ' '{print $2}' || true)
        if [[ -n "$tz" ]]; then
            echo "$tz"
            return
        fi
    fi

    if [[ -f /etc/timezone ]]; then
        local tz
        tz=$(cat /etc/timezone 2>/dev/null || true)
        if [[ -n "$tz" ]]; then
            echo "$tz"
            return
        fi
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        local tz
        tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)
        if [[ -n "$tz" ]]; then
            echo "$tz"
            return
        fi
    fi

    echo "UTC"
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

TEST_MODE="${N8N_SETUP_TEST_MODE:-0}"
if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "TEST MODE enabled: skip 'docker compose up' and runtime health checks." "TEST MODE đã bật: bỏ qua 'docker compose up' và health check runtime.")"
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
        pwn "$(say "Docker daemon is not running. Trying to launch Docker..." "Docker daemon chưa chạy. Đang thử khởi động Docker...")"
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
        if command -v apt-get >/dev/null 2>&1; then
            pwn "$(say "Docker Compose plugin missing, installing..." "Thiếu Docker Compose plugin, đang cài...")"
            run_privileged apt-get update -qq
            run_privileged apt-get install -y -qq docker-compose-plugin
        else
            perr "$(say "Docker Compose plugin is required. Install it manually and rerun." "Cần Docker Compose plugin. Hãy cài thủ công rồi chạy lại.")"
        fi
    fi

    if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get install -y -qq curl openssl ca-certificates >/dev/null 2>&1 || true
    fi
fi

for cmd in curl openssl; do
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
    pwn "$(say "n8n is recommended with 2GB+ RAM." "n8n khuyến nghị RAM từ 2GB trở lên.")"
fi

if [[ "$PLATFORM" == "pi" && "$TOTAL_MEM_MB" -lt 4000 ]]; then
    pwn "$(say "Raspberry Pi with <4GB RAM should use swap for better stability." "Raspberry Pi <4GB RAM nên dùng swap để ổn định hơn.")"
    if ! swapon --show | grep -q '/swapfile'; then
        CREATE_SWAP=$(ask_yes_no "Create 2GB swap now?" "Tạo swap 2GB ngay bây giờ?" "y")
        if [[ "$CREATE_SWAP" == "true" ]]; then
            run_privileged fallocate -l 2G /swapfile 2>/dev/null || \
                run_privileged dd if=/dev/zero of=/swapfile bs=1M count=2048
            run_privileged chmod 600 /swapfile
            run_privileged mkswap /swapfile >/dev/null
            run_privileged swapon /swapfile
            if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
                echo '/swapfile none swap sw 0 0' | run_privileged tee -a /etc/fstab >/dev/null
            fi
            pok "$(say "Swap 2GB configured." "Đã cấu hình swap 2GB.")"
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

read -rp "  $(say "HTTP port for n8n" "Cổng HTTP cho n8n") [5678]: " APP_PORT
APP_PORT=${APP_PORT:-5678}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid port." "Cổng không hợp lệ.")"
fi

if port_in_use "$APP_PORT"; then
    perr "$(say "Port is already in use:" "Cổng đang được sử dụng:") $APP_PORT"
fi

NETWORK_MODE="localhost"
APP_URL="http://localhost:${APP_PORT}"
ACCESS_HOST="localhost"
N8N_PROTOCOL="http"

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
        N8N_PROTOCOL="http"
        ;;
    3)
        NETWORK_MODE="domain"
        read -rp "  $(say "Enter public domain or URL (e.g. https://n8n.example.com)" "Nhập domain hoặc URL public (ví dụ: https://n8n.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ACCESS_HOST=$(host_from_url "$APP_URL")
        [[ -z "$ACCESS_HOST" ]] && perr "$(say "Invalid domain/URL." "Domain/URL không hợp lệ.")"
        N8N_PROTOCOL=$(scheme_from_url "$APP_URL")
        ;;
    *)
        NETWORK_MODE="localhost"
        ACCESS_HOST="localhost"
        APP_URL="http://localhost:${APP_PORT}"
        N8N_PROTOCOL="http"
        ;;
esac

N8N_HOST="$ACCESS_HOST"
WEBHOOK_URL="${APP_URL%/}/"
N8N_EDITOR_BASE_URL="${APP_URL%/}"
LOCAL_HEALTH_URL="http://localhost:${APP_PORT}/healthz"

if [[ "$N8N_PROTOCOL" == "https" ]]; then
    N8N_SECURE_COOKIE="true"
else
    N8N_SECURE_COOKIE="false"
fi

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"

# ========================================
# Step 3: n8n options
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

read -rp "  $(say "n8n image tag" "Tag image n8n") [latest]: " N8N_IMAGE_TAG
N8N_IMAGE_TAG=${N8N_IMAGE_TAG:-latest}

TZ_DEFAULT=$(detect_timezone)
read -rp "  $(say "Timezone" "Múi giờ") [$TZ_DEFAULT]: " GENERIC_TIMEZONE
GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-$TZ_DEFAULT}

echo ""
echo -e "${CYAN}$(say "Optional n8n features (default = NO):" "Tính năng tùy chọn n8n (mặc định = KHÔNG):")${NC}"

USE_POSTGRES=$(ask_yes_no "Use PostgreSQL database?" "Dùng cơ sở dữ liệu PostgreSQL?" "n")
USE_REDIS=$(ask_yes_no "Use Redis service?" "Dùng Redis service?" "n")
ENABLE_QUEUE_MODE=$(ask_yes_no "Enable queue mode?" "Bật queue mode?" "n")
ENABLE_WORKER=$(ask_yes_no "Enable worker service?" "Bật worker service?" "n")
ENABLE_WEBHOOK_PROCESSOR=$(ask_yes_no "Enable webhook processor service?" "Bật webhook processor service?" "n")
ENABLE_TASK_RUNNERS_EXTERNAL=$(ask_yes_no "Enable external task runners sidecar?" "Bật task runners sidecar external?" "n")
ENABLE_METRICS=$(ask_yes_no "Enable /metrics endpoint?" "Bật endpoint /metrics?" "n")
DISABLE_TELEMETRY=$(ask_yes_no "Disable telemetry + version checks?" "Tắt telemetry + kiểm tra version?" "n")
DISABLE_PUBLIC_API=$(ask_yes_no "Disable public REST API + Swagger UI?" "Tắt public REST API + Swagger UI?" "n")
ENABLE_EXECUTION_PRUNE=$(ask_yes_no "Enable automatic execution pruning?" "Bật xóa execution tự động?" "n")
ENABLE_FFMPEG=$(ask_yes_no "Enable FFmpeg helper service?" "Bật FFmpeg helper service?" "n")
ENABLE_PUPPETEER=$(ask_yes_no "Enable Browserless (Puppeteer) service?" "Bật Browserless (Puppeteer) service?" "n")
ENABLE_COMMUNITY_PACKAGES_TOOL_USAGE=$(ask_yes_no "Allow tool usage in community packages?" "Cho phép tool usage trong community packages?" "n")
ENABLE_S3_BINARY_MODE=$(ask_yes_no "Enable S3 binary data mode (Enterprise feature)?" "Bật S3 binary data mode (Enterprise)?" "n")

ENABLE_BROWSERLESS="false"
ENABLE_FFMPEG_HELPER="false"

WORKER_CONCURRENCY=10
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS="false"
EXECUTIONS_DATA_MAX_AGE=336

if [[ "$ENABLE_WORKER" == "true" || "$ENABLE_WEBHOOK_PROCESSOR" == "true" ]]; then
    if [[ "$ENABLE_QUEUE_MODE" != "true" ]]; then
        pwn "$(say "Worker/webhook requires queue mode. Auto-enabling queue mode." "Worker/webhook cần queue mode. Tự động bật queue mode.")"
        ENABLE_QUEUE_MODE="true"
    fi
fi

if [[ "$ENABLE_QUEUE_MODE" == "true" ]]; then
    if [[ "$USE_POSTGRES" != "true" ]]; then
        pwn "$(say "Queue mode requires PostgreSQL. Auto-enabling PostgreSQL." "Queue mode cần PostgreSQL. Tự động bật PostgreSQL.")"
        USE_POSTGRES="true"
    fi
    if [[ "$USE_REDIS" != "true" ]]; then
        pwn "$(say "Queue mode requires Redis. Auto-enabling Redis." "Queue mode cần Redis. Tự động bật Redis.")"
        USE_REDIS="true"
    fi
    if [[ "$ENABLE_WORKER" != "true" ]]; then
        pwn "$(say "Queue mode without worker is not recommended. Auto-enabling worker." "Queue mode không có worker không được khuyến nghị. Tự động bật worker.")"
        ENABLE_WORKER="true"
    fi
fi

if [[ "$ENABLE_WORKER" == "true" ]]; then
    WORKER_CONCURRENCY=$(ask_number "Worker concurrency" "Worker concurrency" "10" "1" "100")
    OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS="true"
    OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=$(ask_yes_no "Offload manual executions to workers?" "Đẩy manual executions sang workers?" "y")
fi

if [[ "$ENABLE_EXECUTION_PRUNE" == "true" ]]; then
    EXECUTIONS_DATA_MAX_AGE=$(ask_number "Execution max age (hours)" "Thời gian giữ execution (giờ)" "336" "1" "87600")
fi

S3_HOST=""
S3_BUCKET_NAME=""
S3_BUCKET_REGION=""
S3_ACCESS_KEY=""
S3_ACCESS_SECRET=""
S3_AUTH_AUTO_DETECT="false"

if [[ "$ENABLE_S3_BINARY_MODE" == "true" ]]; then
    echo ""
    read -rp "  $(say "S3 host (e.g. s3.us-east-1.amazonaws.com)" "S3 host (ví dụ: s3.us-east-1.amazonaws.com)"): " S3_HOST
    read -rp "  $(say "S3 bucket name" "Tên bucket S3"): " S3_BUCKET_NAME
    read -rp "  $(say "S3 bucket region (or auto)" "S3 bucket region (hoặc auto)") [auto]: " S3_BUCKET_REGION
    S3_BUCKET_REGION=${S3_BUCKET_REGION:-auto}
    read -rp "  $(say "S3 access key (leave empty if auto-detect)" "S3 access key (để trống nếu auto-detect)"): " S3_ACCESS_KEY
    read -rp "  $(say "S3 access secret (leave empty if auto-detect)" "S3 access secret (để trống nếu auto-detect)"): " S3_ACCESS_SECRET

    if [[ -z "$S3_HOST" || -z "$S3_BUCKET_NAME" ]]; then
        perr "$(say "S3 host and bucket are required when S3 mode is enabled." "Cần nhập S3 host và bucket khi bật S3 mode.")"
    fi

    if [[ -z "$S3_ACCESS_KEY" || -z "$S3_ACCESS_SECRET" ]]; then
        S3_AUTH_AUTO_DETECT="true"
        pwn "$(say "S3 credentials empty: using auto-detect credential chain." "S3 credentials để trống: dùng auto-detect credential chain.")"
    fi
fi

if [[ "$ENABLE_QUEUE_MODE" == "true" && "$ENABLE_S3_BINARY_MODE" != "true" ]]; then
    pwn "$(say "Queue mode + filesystem binary data is not recommended by n8n docs. Consider S3 mode." "Queue mode + filesystem binary data không được n8n khuyến nghị. Nên cân nhắc S3 mode.")"
fi

ENABLE_CUSTOM_IMAGE="false"
if [[ "$ENABLE_PUPPETEER" == "true" ]]; then
    ENABLE_BROWSERLESS="true"
fi
if [[ "$ENABLE_FFMPEG" == "true" ]]; then
    ENABLE_FFMPEG_HELPER="true"
fi

if [[ "$ENABLE_BROWSERLESS" == "true" || "$ENABLE_FFMPEG_HELPER" == "true" ]]; then
    pwn "$(say "n8n hardened image does not support apt/apk package install. Script will enable helper sidecars instead of rebuilding n8n image." "Image n8n hardened không hỗ trợ cài package qua apt/apk. Script sẽ bật sidecar helper thay vì rebuild image n8n.")"
fi

if [[ "$USE_POSTGRES" == "true" ]]; then
    DB_TYPE="postgresdb"
else
    DB_TYPE="sqlite"
fi

if [[ "$ENABLE_QUEUE_MODE" == "true" ]]; then
    EXECUTIONS_MODE="queue"
else
    EXECUTIONS_MODE="regular"
fi

NEED_MAIN_RUNNER_SIDECAR="false"
if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" ]]; then
    if [[ "$ENABLE_QUEUE_MODE" == "true" ]]; then
        if [[ "$OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS" != "true" ]]; then
            NEED_MAIN_RUNNER_SIDECAR="true"
        fi
    else
        NEED_MAIN_RUNNER_SIDECAR="true"
    fi
fi

# ========================================
# Step 4: Directory & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

INSTALL_DIR="${N8N_SETUP_INSTALL_DIR:-$HOME/self-hosted/n8n}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

OLD_N8N_ENCRYPTION_KEY=$(read_env_value "N8N_ENCRYPTION_KEY" ".env")
OLD_POSTGRES_USER=$(read_env_value "POSTGRES_USER" ".env")
OLD_POSTGRES_DB=$(read_env_value "POSTGRES_DB" ".env")
OLD_POSTGRES_PASSWORD=$(read_env_value "POSTGRES_PASSWORD" ".env")
OLD_N8N_RUNNERS_AUTH_TOKEN=$(read_env_value "N8N_RUNNERS_AUTH_TOKEN" ".env")
OLD_S3_HOST=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_HOST" ".env")
OLD_S3_BUCKET_NAME=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME" ".env")
OLD_S3_BUCKET_REGION=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION" ".env")
OLD_S3_ACCESS_KEY=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY" ".env")
OLD_S3_ACCESS_SECRET=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET" ".env")
OLD_S3_AUTH_AUTO_DETECT=$(read_env_value "N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT" ".env")

N8N_ENCRYPTION_KEY=${OLD_N8N_ENCRYPTION_KEY:-$(openssl rand -hex 16)}
POSTGRES_USER=${OLD_POSTGRES_USER:-n8n}
POSTGRES_DB=${OLD_POSTGRES_DB:-n8n}
POSTGRES_PASSWORD=${OLD_POSTGRES_PASSWORD:-$(openssl rand -hex 18)}
N8N_RUNNERS_AUTH_TOKEN=${OLD_N8N_RUNNERS_AUTH_TOKEN:-$(openssl rand -hex 24)}

if [[ "$ENABLE_S3_BINARY_MODE" == "true" ]]; then
    [[ -z "$S3_HOST" ]] && S3_HOST=${OLD_S3_HOST:-""}
    [[ -z "$S3_BUCKET_NAME" ]] && S3_BUCKET_NAME=${OLD_S3_BUCKET_NAME:-""}
    [[ -z "$S3_BUCKET_REGION" ]] && S3_BUCKET_REGION=${OLD_S3_BUCKET_REGION:-auto}
    [[ -z "$S3_ACCESS_KEY" ]] && S3_ACCESS_KEY=${OLD_S3_ACCESS_KEY:-""}
    [[ -z "$S3_ACCESS_SECRET" ]] && S3_ACCESS_SECRET=${OLD_S3_ACCESS_SECRET:-""}
    if [[ -z "$S3_ACCESS_KEY" || -z "$S3_ACCESS_SECRET" ]]; then
        S3_AUTH_AUTO_DETECT="true"
    else
        S3_AUTH_AUTO_DETECT="${OLD_S3_AUTH_AUTO_DETECT:-false}"
    fi
fi

if [[ "$ENABLE_CUSTOM_IMAGE" == "true" ]]; then
    N8N_BASE_IMAGE="docker.n8n.io/n8nio/n8n:${N8N_IMAGE_TAG}"
    N8N_IMAGE="n8n-custom:${N8N_IMAGE_TAG}"
else
    N8N_BASE_IMAGE=""
    N8N_IMAGE="docker.n8n.io/n8nio/n8n:${N8N_IMAGE_TAG}"
fi
N8N_RUNNERS_IMAGE="n8nio/runners:${N8N_IMAGE_TAG}"

cat > .env <<ENVEOF
# =================================================================
# n8n Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Core
N8N_IMAGE_TAG=$N8N_IMAGE_TAG
N8N_IMAGE=$N8N_IMAGE
N8N_BASE_IMAGE=$N8N_BASE_IMAGE
N8N_RUNNERS_IMAGE=$N8N_RUNNERS_IMAGE
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_PORT=$APP_PORT
N8N_HOST=$N8N_HOST
N8N_PROTOCOL=$N8N_PROTOCOL
N8N_EDITOR_BASE_URL=$N8N_EDITOR_BASE_URL
WEBHOOK_URL=$WEBHOOK_URL
N8N_SECURE_COOKIE=$N8N_SECURE_COOKIE
GENERIC_TIMEZONE=$GENERIC_TIMEZONE

# Mode
DB_TYPE=$DB_TYPE
EXECUTIONS_MODE=$EXECUTIONS_MODE
USE_POSTGRES=$USE_POSTGRES
USE_REDIS=$USE_REDIS
ENABLE_QUEUE_MODE=$ENABLE_QUEUE_MODE
ENABLE_WORKER=$ENABLE_WORKER
ENABLE_WEBHOOK_PROCESSOR=$ENABLE_WEBHOOK_PROCESSOR
WORKER_CONCURRENCY=$WORKER_CONCURRENCY
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=$OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS

# PostgreSQL
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB

# Task runners
ENABLE_TASK_RUNNERS_EXTERNAL=$ENABLE_TASK_RUNNERS_EXTERNAL
NEED_MAIN_RUNNER_SIDECAR=$NEED_MAIN_RUNNER_SIDECAR
N8N_RUNNERS_AUTH_TOKEN=$N8N_RUNNERS_AUTH_TOKEN

# Advanced toggles
ENABLE_METRICS=$ENABLE_METRICS
DISABLE_TELEMETRY=$DISABLE_TELEMETRY
DISABLE_PUBLIC_API=$DISABLE_PUBLIC_API
ENABLE_EXECUTION_PRUNE=$ENABLE_EXECUTION_PRUNE
EXECUTIONS_DATA_MAX_AGE=$EXECUTIONS_DATA_MAX_AGE
ENABLE_FFMPEG=$ENABLE_FFMPEG
ENABLE_PUPPETEER=$ENABLE_PUPPETEER
ENABLE_CUSTOM_IMAGE=$ENABLE_CUSTOM_IMAGE
ENABLE_BROWSERLESS=$ENABLE_BROWSERLESS
ENABLE_FFMPEG_HELPER=$ENABLE_FFMPEG_HELPER
ENABLE_COMMUNITY_PACKAGES_TOOL_USAGE=$ENABLE_COMMUNITY_PACKAGES_TOOL_USAGE
ENABLE_S3_BINARY_MODE=$ENABLE_S3_BINARY_MODE

# S3 binary mode (Enterprise)
N8N_EXTERNAL_STORAGE_S3_HOST=$S3_HOST
N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME=$S3_BUCKET_NAME
N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION=$S3_BUCKET_REGION
N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY=$S3_ACCESS_KEY
N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET=$S3_ACCESS_SECRET
N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT=$S3_AUTH_AUTO_DETECT
ENVEOF

pok "$(say "Saved .env with generated secrets." "Đã lưu .env với secrets mới.")"

# ========================================
# Step 5: Docker files
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

if [[ "$ENABLE_CUSTOM_IMAGE" == "true" ]]; then
    APT_PACKAGES=()
    APK_PACKAGES=()
    if [[ "$ENABLE_FFMPEG" == "true" ]]; then
        APT_PACKAGES+=(ffmpeg)
        APK_PACKAGES+=(ffmpeg)
    fi
    if [[ "$ENABLE_PUPPETEER" == "true" ]]; then
        APT_PACKAGES+=(
            chromium
            ca-certificates
            fonts-liberation
            fonts-noto-color-emoji
            fonts-noto-cjk
            libasound2
            libatk-bridge2.0-0
            libatk1.0-0
            libcups2
            libdrm2
            libgbm1
            libgtk-3-0
            libnspr4
            libnss3
            libx11-6
            libx11-xcb1
            libxcb1
            libxcomposite1
            libxdamage1
            libxext6
            libxfixes3
            libxrandr2
            xdg-utils
        )
        APK_PACKAGES+=(
            chromium
            nss
            freetype
            harfbuzz
            ca-certificates
            ttf-freefont
        )
    fi

    APT_PKG_LINE=$(printf '%s ' "${APT_PACKAGES[@]}")
    APK_PKG_LINE=$(printf '%s ' "${APK_PACKAGES[@]}")

    cat > Dockerfile.n8n <<DOCKEREOF
ARG N8N_BASE_IMAGE=docker.n8n.io/n8nio/n8n:latest
FROM \${N8N_BASE_IMAGE}

USER root
RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${APT_PKG_LINE}; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache ${APK_PKG_LINE}; \
    else \
      echo "Unsupported package manager in base image"; \
      exit 1; \
    fi

USER node
DOCKEREOF

    pok "$(say "Created Dockerfile.n8n for custom dependencies." "Đã tạo Dockerfile.n8n cho dependencies tùy chỉnh.")"
else
    rm -f Dockerfile.n8n
fi

cat > docker-compose.yml <<'COMPOSEEOF'
services:
  n8n:
    image: ${N8N_IMAGE}
COMPOSEEOF

if [[ "$ENABLE_CUSTOM_IMAGE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
    build:
      context: .
      dockerfile: Dockerfile.n8n
      args:
        N8N_BASE_IMAGE: ${N8N_BASE_IMAGE}
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    restart: unless-stopped
    ports:
      - "${N8N_PORT}:5678"
    environment:
      - TZ=${GENERIC_TIMEZONE}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - N8N_HOST=${N8N_HOST}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - N8N_PORT=5678
      - N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - N8N_SECURE_COOKIE=${N8N_SECURE_COOKIE}
COMPOSEEOF

if [[ "$USE_POSTGRES" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
COMPOSEEOF
else
cat >> docker-compose.yml <<'COMPOSEEOF'
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
COMPOSEEOF
fi

if [[ "$ENABLE_QUEUE_MODE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=${OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS}
COMPOSEEOF
fi

if [[ "$ENABLE_METRICS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_METRICS=true
COMPOSEEOF
fi

if [[ "$DISABLE_TELEMETRY" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
COMPOSEEOF
fi

if [[ "$DISABLE_PUBLIC_API" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_PUBLIC_API_DISABLED=true
      - N8N_PUBLIC_API_SWAGGERUI_DISABLED=true
COMPOSEEOF
fi

if [[ "$ENABLE_EXECUTION_PRUNE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
COMPOSEEOF
fi

if [[ "$ENABLE_COMMUNITY_PACKAGES_TOOL_USAGE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
COMPOSEEOF
fi

if [[ "$ENABLE_S3_BINARY_MODE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_AVAILABLE_BINARY_DATA_MODES=filesystem,s3
      - N8N_DEFAULT_BINARY_DATA_MODE=s3
      - N8N_EXTERNAL_STORAGE_S3_HOST=${N8N_EXTERNAL_STORAGE_S3_HOST}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME=${N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION=${N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY=${N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET=${N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET}
      - N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT=${N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT}
COMPOSEEOF
fi

if [[ "$ENABLE_BROWSERLESS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - PUPPETEER_BROWSER_WS_ENDPOINT=ws://browserless:3000
      - BROWSERLESS_URL=ws://browserless:3000
COMPOSEEOF
fi

if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" && "$NEED_MAIN_RUNNER_SIDECAR" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_RUNNERS_ENABLED=true
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
      - N8N_NATIVE_PYTHON_RUNNER=true
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    volumes:
      - n8n_data:/home/node/.n8n
COMPOSEEOF

if [[ "$ENABLE_FFMPEG_HELPER" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - n8n_shared:/data/shared
COMPOSEEOF
fi

if [[ "$USE_POSTGRES" == "true" || "$USE_REDIS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
    depends_on:
COMPOSEEOF
    if [[ "$USE_POSTGRES" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      postgres:
        condition: service_healthy
COMPOSEEOF
    fi
    if [[ "$USE_REDIS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      redis:
        condition: service_healthy
COMPOSEEOF
    fi
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:5678/healthz', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
      interval: 20s
      timeout: 10s
      retries: 10
      start_period: 30s
    networks:
      - n8n_net
COMPOSEEOF

if [[ "$ENABLE_WORKER" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  n8n-worker:
    image: ${N8N_IMAGE}
    restart: unless-stopped
    command: worker --concurrency=${WORKER_CONCURRENCY}
    environment:
      - TZ=${GENERIC_TIMEZONE}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
COMPOSEEOF

if [[ "$ENABLE_METRICS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_METRICS=true
COMPOSEEOF
fi

if [[ "$DISABLE_TELEMETRY" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
COMPOSEEOF
fi

if [[ "$ENABLE_EXECUTION_PRUNE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
COMPOSEEOF
fi

if [[ "$ENABLE_COMMUNITY_PACKAGES_TOOL_USAGE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
COMPOSEEOF
fi

if [[ "$ENABLE_S3_BINARY_MODE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_AVAILABLE_BINARY_DATA_MODES=filesystem,s3
      - N8N_DEFAULT_BINARY_DATA_MODE=s3
      - N8N_EXTERNAL_STORAGE_S3_HOST=${N8N_EXTERNAL_STORAGE_S3_HOST}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME=${N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION=${N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY=${N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET=${N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET}
      - N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT=${N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT}
COMPOSEEOF
fi

if [[ "$ENABLE_BROWSERLESS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - PUPPETEER_BROWSER_WS_ENDPOINT=ws://browserless:3000
      - BROWSERLESS_URL=ws://browserless:3000
COMPOSEEOF
fi

if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_RUNNERS_ENABLED=true
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
      - N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
      - N8N_NATIVE_PYTHON_RUNNER=true
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      n8n:
        condition: service_healthy
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$ENABLE_WEBHOOK_PROCESSOR" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  n8n-webhook:
    image: ${N8N_IMAGE}
    restart: unless-stopped
    command: webhook
    environment:
      - TZ=${GENERIC_TIMEZONE}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - N8N_HOST=${N8N_HOST}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - N8N_PORT=5678
      - WEBHOOK_URL=${WEBHOOK_URL}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
COMPOSEEOF

if [[ "$ENABLE_METRICS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_METRICS=true
COMPOSEEOF
fi

if [[ "$DISABLE_TELEMETRY" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
COMPOSEEOF
fi

if [[ "$ENABLE_S3_BINARY_MODE" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - N8N_AVAILABLE_BINARY_DATA_MODES=filesystem,s3
      - N8N_DEFAULT_BINARY_DATA_MODE=s3
      - N8N_EXTERNAL_STORAGE_S3_HOST=${N8N_EXTERNAL_STORAGE_S3_HOST}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME=${N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME}
      - N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION=${N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY=${N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY}
      - N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET=${N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET}
      - N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT=${N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT}
COMPOSEEOF
fi

if [[ "$ENABLE_BROWSERLESS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
      - PUPPETEER_BROWSER_WS_ENDPOINT=ws://browserless:3000
      - BROWSERLESS_URL=ws://browserless:3000
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      n8n:
        condition: service_healthy
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" && "$NEED_MAIN_RUNNER_SIDECAR" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  n8n-task-runners-main:
    image: ${N8N_RUNNERS_IMAGE}
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n:5679
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
    depends_on:
      n8n:
        condition: service_healthy
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" && "$ENABLE_WORKER" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  n8n-task-runners-worker:
    image: ${N8N_RUNNERS_IMAGE}
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n-worker:5679
      - N8N_RUNNERS_AUTH_TOKEN=${N8N_RUNNERS_AUTH_TOKEN}
    depends_on:
      n8n-worker:
        condition: service_started
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$ENABLE_BROWSERLESS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  browserless:
    image: browserless/chrome:latest
    restart: unless-stopped
    shm_size: "1gb"
    environment:
      - CONCURRENT=5
      - TIMEOUT=120000
      - PREBOOT_CHROME=true
      - KEEP_ALIVE=true
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$ENABLE_FFMPEG_HELPER" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  ffmpeg-helper:
    image: lscr.io/linuxserver/ffmpeg:latest
    restart: unless-stopped
    entrypoint: ["/bin/sh", "-c"]
    command: ["sleep infinity"]
    volumes:
      - n8n_shared:/work
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$USE_POSTGRES" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - n8n_net
COMPOSEEOF
fi

if [[ "$USE_REDIS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - n8n_net
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'

volumes:
  n8n_data:
COMPOSEEOF

if [[ "$USE_POSTGRES" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
  postgres_data:
COMPOSEEOF
fi

if [[ "$USE_REDIS" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
  redis_data:
COMPOSEEOF
fi

if [[ "$ENABLE_FFMPEG_HELPER" == "true" ]]; then
cat >> docker-compose.yml <<'COMPOSEEOF'
  n8n_shared:
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'

networks:
  n8n_net:
    driver: bridge
COMPOSEEOF

pok "$(say "Docker Compose file created." "Đã tạo file Docker Compose.")"

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
    MAX_START_ATTEMPTS=${N8N_START_RETRIES:-3}
    SUCCESS_START=false

    for attempt in $(seq 1 "$MAX_START_ATTEMPTS"); do
        pwn "$(say "Starting stack (attempt $attempt/$MAX_START_ATTEMPTS)..." "Đang khởi động stack (lần $attempt/$MAX_START_ATTEMPTS)...")"
        if [[ "$ENABLE_CUSTOM_IMAGE" == "true" ]]; then
            if dc up -d --build; then
                SUCCESS_START=true
                break
            fi
        else
            if dc up -d --pull always; then
                SUCCESS_START=true
                break
            fi
        fi
        sleep 15
    done

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start n8n stack." "Không thể khởi động stack n8n.")"
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
    HEALTH_TIMEOUT=${N8N_HEALTH_TIMEOUT:-420}
    ELAPSED=0
    HEALTH_OK=false

    pwn "$(say "Waiting for n8n health endpoint..." "Đang đợi health endpoint của n8n...")"
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
    EXPECTED_SERVICES=("n8n")

    if [[ "$USE_POSTGRES" == "true" ]]; then
        EXPECTED_SERVICES+=("postgres")
    fi
    if [[ "$USE_REDIS" == "true" ]]; then
        EXPECTED_SERVICES+=("redis")
    fi
    if [[ "$ENABLE_WORKER" == "true" ]]; then
        EXPECTED_SERVICES+=("n8n-worker")
    fi
    if [[ "$ENABLE_WEBHOOK_PROCESSOR" == "true" ]]; then
        EXPECTED_SERVICES+=("n8n-webhook")
    fi
    if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" && "$NEED_MAIN_RUNNER_SIDECAR" == "true" ]]; then
        EXPECTED_SERVICES+=("n8n-task-runners-main")
    fi
    if [[ "$ENABLE_TASK_RUNNERS_EXTERNAL" == "true" && "$ENABLE_WORKER" == "true" ]]; then
        EXPECTED_SERVICES+=("n8n-task-runners-worker")
    fi

    for svc in "${EXPECTED_SERVICES[@]}"; do
        if echo "$RUNNING_SERVICES" | grep -qx "$svc"; then
            pok "$svc: running"
        else
            pwn "$svc: not running"
            ALL_OK=false
        fi
    done
fi

# ========================================
# Step 9: Helper script
# ========================================
echo ""
echo -e "${BOLD}$(step_title 9)${NC}"

cat > n8n.sh <<'HELPEOF'
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

env_val() {
  local key="$1"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2-
}

compose_up() {
  local retries="${N8N_START_RETRIES:-3}"
  local ok="false"

  for attempt in $(seq 1 "$retries"); do
    if [[ "$(env_val ENABLE_CUSTOM_IMAGE)" == "true" ]]; then
      if dc up -d --build; then
        ok="true"
        break
      fi
    else
      if dc up -d --pull always; then
        ok="true"
        break
      fi
    fi
    sleep 10
  done

  [[ "$ok" == "true" ]] || return 1
}

case "${1:-}" in
  start)
    echo "Starting n8n stack..."
    compose_up
    echo "Started: $(env_val N8N_EDITOR_BASE_URL)"
    ;;
  stop)
    echo "Stopping n8n stack..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting n8n stack..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-n8n}"
    ;;
  health)
    PORT="$(env_val N8N_PORT)"
    PORT="${PORT:-5678}"
    if curl -fsS "http://localhost:${PORT}/healthz" >/dev/null 2>&1; then
      echo "Health OK: http://localhost:${PORT}/healthz"
    else
      echo "Health FAILED: http://localhost:${PORT}/healthz"
      exit 1
    fi
    ;;
  open)
    URL="$(env_val N8N_EDITOR_BASE_URL)"
    URL="${URL:-http://localhost:5678}"
    if command -v open >/dev/null 2>&1; then
      open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$URL"
    else
      echo "$URL"
    fi
    ;;
  upgrade)
    echo "Upgrading n8n stack..."
    if [[ "$(env_val ENABLE_CUSTOM_IMAGE)" == "true" ]]; then
      dc build --pull
      dc up -d
    else
      dc pull
      dc up -d
    fi
    echo "Upgrade complete"
    ;;
  env)
    echo "Environment summary (.env):"
    grep -E '^(N8N_EDITOR_BASE_URL|N8N_HOST|N8N_PROTOCOL|N8N_PORT|DB_TYPE|EXECUTIONS_MODE|ENABLE_WORKER|ENABLE_WEBHOOK_PROCESSOR|USE_POSTGRES|USE_REDIS|ENABLE_TASK_RUNNERS_EXTERNAL|ENABLE_FFMPEG|ENABLE_PUPPETEER|ENABLE_BROWSERLESS|ENABLE_FFMPEG_HELPER|ENABLE_S3_BINARY_MODE)=' .env || true
    ;;
  doctor)
    dc config
    dc ps
    ;;
  reset)
    echo "WARNING: This will DELETE all local n8n data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "n8n Helper"
    echo ""
    echo "Usage: ./n8n.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start/upgrade stack"
    echo "  stop         - Stop services"
    echo "  restart      - Restart services"
    echo "  status       - Show service status"
    echo "  logs [svc]   - Follow logs (default: n8n)"
    echo "  health       - Check /healthz endpoint"
    echo "  open         - Open n8n URL in browser"
    echo "  upgrade      - Pull/update containers"
    echo "  env          - Show selected env values"
    echo "  doctor       - Validate compose + status"
    echo "  reset        - Delete all local data"
    ;;
esac
HELPEOF

chmod +x n8n.sh
pok "$(say "Helper script created: ./n8n.sh" "Đã tạo helper script: ./n8n.sh")"

# ========================================
# Step 10: Summary
# ========================================
echo ""
echo -e "${BOLD}$(step_title 10)${NC}"

echo ""
echo "========================================================"
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${GREEN}  $(say "INSTALLATION COMPLETE" "CÀI ĐẶT HOÀN TẤT")${NC}"
else
    echo -e "${YELLOW}  $(say "INSTALL FINISHED WITH WARNINGS" "CÀI ĐẶT XONG (CÓ CẢNH BÁO)")${NC}"
fi
echo ""
echo -e "  $(say "Platform" "Nền tảng"):     ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "App URL" "URL truy cập"):  ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Health URL" "URL health"): ${PURPLE}${LOCAL_HEALTH_URL}${NC}"
echo -e "  $(say "Directory" "Thư mục"):     ${CYAN}${INSTALL_DIR}${NC}"
echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  - cd ${INSTALL_DIR}"
echo "  - ./n8n.sh status"
echo "  - ./n8n.sh logs n8n"
echo "  - ./n8n.sh health"
echo "  - ./n8n.sh restart"
echo "  - ./n8n.sh upgrade"
echo ""
echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  - $(say "Do not share .env (contains secrets)." "Không chia sẻ file .env (chứa secrets).")"
echo "  - $(say "For production with domain, use reverse proxy (Caddy/Nginx/Cloudflare Tunnel)." "Cho production với domain, nên dùng reverse proxy (Caddy/Nginx/Cloudflare Tunnel).")"
if [[ "$ENABLE_QUEUE_MODE" == "true" ]]; then
    echo "  - $(say "Queue mode is enabled. Keep Postgres and Redis healthy." "Queue mode đã bật. Cần đảm bảo Postgres và Redis hoạt động ổn định.")"
fi
if [[ "$ENABLE_BROWSERLESS" == "true" ]]; then
    echo "  - $(say "Browserless service is enabled for Puppeteer jobs (ws://browserless:3000)." "Đã bật Browserless cho tác vụ Puppeteer (ws://browserless:3000).")"
fi
if [[ "$ENABLE_FFMPEG_HELPER" == "true" ]]; then
    echo "  - $(say "FFmpeg helper container is enabled (shared path: /data/shared in n8n)." "Đã bật container FFmpeg helper (đường dẫn chia sẻ: /data/shared trong n8n).")"
fi
echo ""
echo "Support: https://ai.vnrom.net"
echo "Docs:    https://docs.n8n.io"
