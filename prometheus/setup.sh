#!/bin/bash
################################################################
# Prometheus Unified Auto-Install
# Supports: macOS, Raspberry Pi, VPS (amd64/arm64)
# Features: Prometheus server, rule files, optional Linux node-exporter
# Based on official Prometheus and node_exporter container guidance
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
        1) say "[1/9] System check" "[1/9] Kiểm tra hệ thống" ;;
        2) say "[2/9] Access mode" "[2/9] Chế độ truy cập" ;;
        3) say "[3/9] Install directory" "[3/9] Thư mục cài đặt" ;;
        4) say "[4/9] Environment & Prometheus config" "[4/9] Biến môi trường & cấu hình Prometheus" ;;
        5) say "[5/9] Docker Compose files" "[5/9] Tạo file Docker Compose" ;;
        6) say "[6/9] Validation" "[6/9] Kiểm tra cấu hình" ;;
        7) say "[7/9] Start containers" "[7/9] Khởi động containers" ;;
        8) say "[8/9] Verify services" "[8/9] Xác minh services" ;;
        9) say "[9/9] Helper & summary" "[9/9] Script quản lý & tổng kết" ;;
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
    echo "        Prometheus Setup — $PLATFORM_LABEL"
    echo "       Metrics · Monitoring · Rules · Support"
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
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y "$pkg" >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y "$pkg" >/dev/null 2>&1 || true
    elif command -v apk >/dev/null 2>&1; then
        run_privileged apk add --no-cache "$pkg" >/dev/null 2>&1 || true
    fi
}

DOCKER_CMD=(docker)
dc() {
    "${DOCKER_CMD[@]}" compose "$@"
}

dr() {
    "${DOCKER_CMD[@]}" "$@"
}

ensure_shared_network() {
    local network_name="prometheus-shared"
    if [[ "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
        return 0
    fi

    if dr network inspect "$network_name" >/dev/null 2>&1; then
        return 0
    fi

    dr network create "$network_name" >/dev/null
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

promtool_check_config() {
    local image="$1"
    if [[ "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
        return 0
    fi

    dr run --rm \
        -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
        -v "$PWD/rules:/etc/prometheus/rules:ro" \
        --entrypoint /bin/promtool \
        "$image" check config /etc/prometheus/prometheus.yml >/dev/null
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

TEST_MODE="${PROMETHEUS_SETUP_TEST_MODE:-0}"
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

if [[ "${DISK_GB:-0}" -lt 4 ]]; then
    perr "$(say "At least 4GB free disk is required." "Cần tối thiểu 4GB dung lượng trống.")"
fi

if [[ "${TOTAL_MEM_MB:-0}" -lt 1024 ]]; then
    pwn "$(say "Less than 1GB RAM detected. Prometheus may still run, but retention should be kept small." "Phát hiện dưới 1GB RAM. Prometheus vẫn có thể chạy, nhưng nên giữ retention nhỏ.")"
fi

if [[ "$PLATFORM" == "pi" && "${TOTAL_MEM_MB:-0}" -lt 2000 ]]; then
    if ! swapon --show | grep -q '^'; then
        pwn "$(say "No swap detected. Creating 1GB swap for stability..." "Không có swap. Đang tạo swap 1GB để tăng ổn định...")"
        run_privileged fallocate -l 1G /swapfile 2>/dev/null || run_privileged dd if=/dev/zero of=/swapfile bs=1M count=1024
        run_privileged chmod 600 /swapfile
        run_privileged mkswap /swapfile >/dev/null
        run_privileged swapon /swapfile
        if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
            echo '/swapfile none swap sw 0 0' | run_privileged tee -a /etc/fstab >/dev/null
        fi
        pok "$(say "Swap 1GB configured." "Đã cấu hình swap 1GB.")"
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

read -rp "  $(say "HTTP port for Prometheus" "Cổng HTTP cho Prometheus") [9090]: " APP_PORT
APP_PORT=${APP_PORT:-9090}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid port." "Cổng không hợp lệ.")"
fi

if [[ "$TEST_MODE" != "1" ]] && port_in_use "$APP_PORT"; then
    perr "$(say "Port is already in use:" "Cổng đang được sử dụng:") $APP_PORT"
fi

NETWORK_MODE="localhost"
PROM_BIND_IP="127.0.0.1"
APP_URL="http://localhost:${APP_PORT}"
LOCAL_HEALTH_URL="http://localhost:${APP_PORT}/-/healthy"
LOCAL_READY_URL="http://localhost:${APP_PORT}/-/ready"
ACCESS_HOST="localhost:${APP_PORT}"

case "$NET_CHOICE" in
    2)
        NETWORK_MODE="lan"
        PROM_BIND_IP="0.0.0.0"
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
        PROM_BIND_IP="127.0.0.1"
        read -rp "  $(say "Enter public domain or URL (e.g. https://metrics.example.com)" "Nhập domain hoặc URL public (ví dụ: https://metrics.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ACCESS_HOST=$(host_from_url "$APP_URL")
        ;;
    *)
        NETWORK_MODE="localhost"
        PROM_BIND_IP="127.0.0.1"
        ACCESS_HOST="localhost:${APP_PORT}"
        APP_URL="http://localhost:${APP_PORT}"
        ;;
esac

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"

# ========================================
# Step 3: Install directory
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

INSTALL_DIR="$HOME/self-hosted/prometheus"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p rules
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

# ========================================
# Step 4: Environment & Prometheus config
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

PROMETHEUS_IMAGE_OLD=$(read_env_value "PROMETHEUS_IMAGE" ".env")
NODE_EXPORTER_IMAGE_OLD=$(read_env_value "NODE_EXPORTER_IMAGE" ".env")
PROM_RETENTION_TIME_OLD=$(read_env_value "PROMETHEUS_RETENTION_TIME" ".env")
PROM_RETENTION_SIZE_OLD=$(read_env_value "PROMETHEUS_RETENTION_SIZE" ".env")
PROM_SCRAPE_INTERVAL_OLD=$(read_env_value "PROMETHEUS_SCRAPE_INTERVAL" ".env")
PROM_EVAL_INTERVAL_OLD=$(read_env_value "PROMETHEUS_EVALUATION_INTERVAL" ".env")
PROM_TIMEZONE_OLD=$(read_env_value "PROMETHEUS_TIMEZONE" ".env")
PROM_INSTANCE_LABEL_OLD=$(read_env_value "PROMETHEUS_INSTANCE_LABEL" ".env")

PROMETHEUS_IMAGE=${PROMETHEUS_IMAGE_OLD:-prom/prometheus:latest}
NODE_EXPORTER_IMAGE=${NODE_EXPORTER_IMAGE_OLD:-quay.io/prometheus/node-exporter:latest}
PROMETHEUS_RETENTION_TIME=${PROM_RETENTION_TIME_OLD:-15d}
PROMETHEUS_RETENTION_SIZE=${PROM_RETENTION_SIZE_OLD:-4GB}
PROMETHEUS_SCRAPE_INTERVAL=${PROM_SCRAPE_INTERVAL_OLD:-15s}
PROMETHEUS_EVALUATION_INTERVAL=${PROM_EVAL_INTERVAL_OLD:-15s}
PROMETHEUS_TIMEZONE=${PROM_TIMEZONE_OLD:-$(detect_timezone)}
PROMETHEUS_INSTANCE_LABEL=${PROM_INSTANCE_LABEL_OLD:-prometheus-self-hosted}

if [[ "$PLATFORM" == "mac" ]]; then
    PROMETHEUS_ENABLE_NODE_EXPORTER=false
else
    PROMETHEUS_ENABLE_NODE_EXPORTER=true
fi

if [[ "$PLATFORM" == "pi" && "$PROMETHEUS_RETENTION_SIZE" == "4GB" ]]; then
    PROMETHEUS_RETENTION_SIZE="2GB"
fi

cat > .env <<ENVEOF
# =================================================================
# Prometheus Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Access
PROMETHEUS_HTTP_PORT=$APP_PORT
PROMETHEUS_BIND_IP=$PROM_BIND_IP
PROMETHEUS_URL=$APP_URL
PROMETHEUS_EXTERNAL_URL=$APP_URL
PROMETHEUS_TIMEZONE=$PROMETHEUS_TIMEZONE
PROMETHEUS_INSTANCE_LABEL=$PROMETHEUS_INSTANCE_LABEL
PROMETHEUS_ENABLE_NODE_EXPORTER=$PROMETHEUS_ENABLE_NODE_EXPORTER

# Images
PROMETHEUS_IMAGE=$PROMETHEUS_IMAGE
NODE_EXPORTER_IMAGE=$NODE_EXPORTER_IMAGE

# Storage / retention
PROMETHEUS_RETENTION_TIME=$PROMETHEUS_RETENTION_TIME
PROMETHEUS_RETENTION_SIZE=$PROMETHEUS_RETENTION_SIZE
PROMETHEUS_SCRAPE_INTERVAL=$PROMETHEUS_SCRAPE_INTERVAL
PROMETHEUS_EVALUATION_INTERVAL=$PROMETHEUS_EVALUATION_INTERVAL
ENVEOF

pok "$(say "Saved .env with Prometheus defaults." "Đã lưu .env với cấu hình Prometheus mặc định.")"

cat > prometheus.yml <<PROMCFGEOF
# Prometheus config generated by setup.sh

global:
  scrape_interval: $PROMETHEUS_SCRAPE_INTERVAL
  evaluation_interval: $PROMETHEUS_EVALUATION_INTERVAL
  external_labels:
    instance: $PROMETHEUS_INSTANCE_LABEL
    platform: $PLATFORM

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - prometheus:9090
PROMCFGEOF

if [[ "$PROMETHEUS_ENABLE_NODE_EXPORTER" == "true" ]]; then
    cat >> prometheus.yml <<'PROMCFGEOF'
  - job_name: node
    static_configs:
      - targets:
          - host.docker.internal:9100
        labels:
          role: host
PROMCFGEOF
fi

cat > rules/default.yml <<'RULESEOF'
groups:
  - name: prometheus-self-hosted
    rules:
      - alert: PrometheusTargetDown
        expr: up{job="prometheus"} == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: Prometheus target is down
          description: The Prometheus self-scrape target has been down for more than 2 minutes.

      - alert: NodeExporterDown
        expr: up{job="node"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Node exporter is down
          description: The Linux host metrics endpoint has been unreachable for more than 5 minutes.
RULESEOF

pok "$(say "Generated prometheus.yml and rules/default.yml." "Đã tạo prometheus.yml và rules/default.yml.")"

# ========================================
# Step 5: Docker Compose files
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

if [[ "$SKIP_DOCKER_COMMANDS" == "0" ]]; then
    ensure_shared_network || perr "$(say "Could not create shared Docker network." "Không thể tạo shared Docker network.")"
fi

cat > docker-compose.yml <<'COMPOSEEOF'
name: prometheus

services:
  prometheus:
    image: ${PROMETHEUS_IMAGE:-prom/prometheus:latest}
    container_name: prometheus
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=${PROMETHEUS_RETENTION_TIME:-15d}
      - --storage.tsdb.retention.size=${PROMETHEUS_RETENTION_SIZE:-4GB}
      - --web.external-url=${PROMETHEUS_EXTERNAL_URL:-http://localhost:9090}
      - --web.enable-lifecycle
      - --web.console.libraries=/etc/prometheus/console_libraries
      - --web.console.templates=/etc/prometheus/consoles
    ports:
      - "${PROMETHEUS_BIND_IP:-127.0.0.1}:${PROMETHEUS_HTTP_PORT:-9090}:9090"
    environment:
      TZ: ${PROMETHEUS_TIMEZONE:-UTC}
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
COMPOSEEOF

if [[ "$PROMETHEUS_ENABLE_NODE_EXPORTER" == "true" ]]; then
    cat >> docker-compose.yml <<'COMPOSEEOF'
    extra_hosts:
      - "host.docker.internal:host-gateway"
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'
    networks:
      prometheus-network:
        aliases:
          - prometheus-core
COMPOSEEOF

if [[ "$PROMETHEUS_ENABLE_NODE_EXPORTER" == "true" ]]; then
    cat >> docker-compose.yml <<'COMPOSEEOF'

  node-exporter:
    image: ${NODE_EXPORTER_IMAGE:-quay.io/prometheus/node-exporter:latest}
    container_name: prometheus-node-exporter
    restart: unless-stopped
    command:
      - --path.rootfs=/host
      - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)
    network_mode: host
    pid: host
    volumes:
      - /:/host:ro,rslave
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'

volumes:
  prometheus_data:

networks:
  prometheus-network:
    external: true
    name: prometheus-shared
COMPOSEEOF

pok "$(say "Docker Compose file generated." "Đã tạo file Docker Compose.")"

# ========================================
# Step 6: Validation
# ========================================
echo ""
echo -e "${BOLD}$(step_title 6)${NC}"

if [[ "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
    pwn "$(say "Skipping compose validation in TEST MODE (docker unavailable)." "Bỏ qua kiểm tra compose trong TEST MODE (docker chưa sẵn sàng).")"
else
    dc config >/dev/null 2>&1 || perr "$(say "docker compose config failed." "docker compose config lỗi.")"
    pok "$(say "docker compose config: OK" "docker compose config: OK")"

    if promtool_check_config "$PROMETHEUS_IMAGE"; then
        pok "$(say "promtool check config: OK" "promtool check config: OK")"
    else
        perr "$(say "promtool check config failed." "promtool check config lỗi.")"
    fi
fi

# ========================================
# Step 7: Start containers
# ========================================
echo ""
echo -e "${BOLD}$(step_title 7)${NC}"

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping docker compose up." "Test mode: bỏ qua docker compose up.")"
else
    MAX_START_ATTEMPTS=${PROMETHEUS_START_RETRIES:-3}
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

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start Prometheus stack." "Không thể khởi động stack Prometheus.")"
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
    HEALTH_TIMEOUT=${PROMETHEUS_HEALTH_TIMEOUT:-180}
    ELAPSED=0
    HEALTH_OK=false

    pwn "$(say "Waiting for Prometheus health endpoint..." "Đang đợi health endpoint của Prometheus...")"
    while [[ "$ELAPSED" -lt "$HEALTH_TIMEOUT" ]]; do
        if curl -fsS "$LOCAL_HEALTH_URL" >/dev/null 2>&1; then
            HEALTH_OK=true
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done

    if [[ "$HEALTH_OK" == "true" ]]; then
        pok "$(say "Prometheus health is ready:" "Prometheus health đã sẵn sàng:") $LOCAL_HEALTH_URL"
    else
        pwn "$(say "Prometheus health timeout:" "Prometheus health timeout:") $LOCAL_HEALTH_URL"
        ALL_OK=false
    fi

    if curl -fsS "$LOCAL_READY_URL" >/dev/null 2>&1; then
        pok "$(say "Prometheus readiness is ready:" "Prometheus readiness đã sẵn sàng:") $LOCAL_READY_URL"
    else
        pwn "$(say "Prometheus readiness failed:" "Prometheus readiness lỗi:") $LOCAL_READY_URL"
        ALL_OK=false
    fi

    RUNNING_SERVICES=$(dc ps --status running --services 2>/dev/null || true)
    if echo "$RUNNING_SERVICES" | grep -qx 'prometheus'; then
        pok "prometheus: running"
    else
        pwn "prometheus: not running"
        ALL_OK=false
    fi

    if [[ "$PROMETHEUS_ENABLE_NODE_EXPORTER" == "true" ]]; then
        if echo "$RUNNING_SERVICES" | grep -qx 'node-exporter'; then
            pok "node-exporter: running"
        else
            pwn "node-exporter: not running"
            ALL_OK=false
        fi
    else
        pwn "$(say "node-exporter is disabled on this platform by default." "node-exporter mặc định bị tắt trên nền tảng này.")"
    fi
fi

# ========================================
# Step 9: Helper & summary
# ========================================
echo ""
echo -e "${BOLD}$(step_title 9)${NC}"

cat > prometheus.sh <<'HELPEREOF'
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

dr() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker "$@"
  else
    echo "Docker daemon is not accessible."
    exit 1
  fi
}

ensure_shared_network() {
  if dr network inspect prometheus-shared >/dev/null 2>&1; then
    return 0
  fi

  dr network create prometheus-shared >/dev/null
}

prometheus_url() {
  grep '^PROMETHEUS_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:9090"
}

http_port() {
  grep '^PROMETHEUS_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "9090"
}

prometheus_image() {
  grep '^PROMETHEUS_IMAGE=' .env 2>/dev/null | cut -d= -f2- || echo "prom/prometheus:latest"
}

config_check() {
  dr run --rm \
    -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
    -v "$PWD/rules:/etc/prometheus/rules:ro" \
    --entrypoint /bin/promtool \
    "$(prometheus_image)" check config /etc/prometheus/prometheus.yml
}

case "${1:-}" in
  start)
    echo "Starting Prometheus..."
    ensure_shared_network
    dc up -d --pull always
    echo "Started: $(prometheus_url)"
    ;;
  stop)
    echo "Stopping Prometheus..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting Prometheus..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-prometheus}"
    ;;
  health)
    PORT=$(http_port)
    curl -fsS "http://localhost:${PORT}/-/healthy" >/dev/null
    curl -fsS "http://localhost:${PORT}/-/ready" >/dev/null
    echo "Health OK: http://localhost:${PORT}/-/healthy"
    echo "Ready OK:  http://localhost:${PORT}/-/ready"
    ;;
  reload)
    PORT=$(http_port)
    curl -fsS -X POST "http://localhost:${PORT}/-/reload" >/dev/null
    echo "Configuration reloaded"
    ;;
  config-check)
    config_check
    ;;
  upgrade)
    echo "Upgrading Prometheus images..."
    ensure_shared_network
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  reset)
    echo "This will DELETE Prometheus TSDB data volume."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Prometheus Helper"
    echo ""
    echo "Usage: ./prometheus.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start         - Start/upgrade stack"
    echo "  stop          - Stop services"
    echo "  restart       - Restart services"
    echo "  status        - Show service status"
    echo "  logs [svc]    - Follow logs (default: prometheus)"
    echo "  health        - Check /-/healthy and /-/ready"
    echo "  reload        - Reload prometheus.yml without restart"
    echo "  config-check  - Validate prometheus.yml via promtool"
    echo "  upgrade       - Pull latest images and restart"
    echo "  reset         - Delete Prometheus data volume"
    ;;
esac
HELPEREOF

chmod +x prometheus.sh
pok "$(say "Helper script created: ./prometheus.sh" "Đã tạo helper script: ./prometheus.sh")"

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
echo -e "  $(say "Retention" "Retention"):      ${CYAN}${PROMETHEUS_RETENTION_TIME} / ${PROMETHEUS_RETENTION_SIZE}${NC}"

echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  • ./prometheus.sh status"
echo "  • ./prometheus.sh logs prometheus"
echo "  • ./prometheus.sh health"
echo "  • ./prometheus.sh reload"
echo "  • ./prometheus.sh config-check"
echo "  • ./prometheus.sh upgrade"
echo ""

echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  • $(say "Edit prometheus.yml to add more scrape targets, then run ./prometheus.sh reload." "Sửa prometheus.yml để thêm scrape target, sau đó chạy ./prometheus.sh reload.")"
echo "  • $(say "Do not expose port 9090 directly to the internet without auth/proxy controls." "Không nên mở trực tiếp cổng 9090 ra internet nếu chưa có auth/proxy bảo vệ.")"
if [[ "$NETWORK_MODE" == "domain" ]]; then
    echo "  • $(say "Ensure reverse proxy forwards your domain to http://127.0.0.1:${APP_PORT}" "Đảm bảo reverse proxy trỏ domain vào http://127.0.0.1:${APP_PORT}")"
fi
if [[ "$PROMETHEUS_ENABLE_NODE_EXPORTER" == "false" ]]; then
    echo "  • $(say "node-exporter is disabled by default on macOS because official host-namespace container guidance is Linux-focused." "node-exporter mặc định bị tắt trên macOS vì hướng dẫn container truy cập host namespace chính thức tập trung cho Linux.")"
fi

echo ""
echo "Support: https://ai.vnrom.net"
echo "Docs:    https://prometheus.io/docs/prometheus/latest/"
