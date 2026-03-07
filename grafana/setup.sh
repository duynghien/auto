#!/bin/bash
################################################################
# Grafana Unified Auto-Install
# Supports: macOS, Raspberry Pi, VPS (amd64/arm64)
# Features: Grafana server, Prometheus datasource provisioning, starter dashboard
# Based on official Grafana Docker and provisioning guidance
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
        3) say "[3/9] Prometheus link" "[3/9] Kết nối Prometheus" ;;
        4) say "[4/9] Directory & secrets" "[4/9] Thư mục & secrets" ;;
        5) say "[5/9] Provisioning files" "[5/9] Tạo file provisioning" ;;
        6) say "[6/9] Docker Compose files" "[6/9] Tạo file Docker Compose" ;;
        7) say "[7/9] Validation" "[7/9] Kiểm tra cấu hình" ;;
        8) say "[8/9] Start & verify" "[8/9] Khởi động & xác minh" ;;
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
    echo "         Grafana Setup — $PLATFORM_LABEL"
    echo "      Dashboards · Prometheus · Branding · Support"
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
    echo "$url" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##; s#:[0-9]+$##'
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

ensure_prometheus_shared_network() {
    if [[ "$SKIP_DOCKER_COMMANDS" == "1" || "$USE_LOCAL_PROMETHEUS" != "true" ]]; then
        return 0
    fi

    if dr network inspect prometheus-shared >/dev/null 2>&1; then
        return 0
    fi

    dr network create prometheus-shared >/dev/null
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

TEST_MODE="${GRAFANA_SETUP_TEST_MODE:-0}"
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

read -rp "  $(say "HTTP port for Grafana" "Cổng HTTP cho Grafana") [3000]: " APP_PORT
APP_PORT=${APP_PORT:-3000}

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 || "$APP_PORT" -gt 65535 ]]; then
    perr "$(say "Invalid port." "Cổng không hợp lệ.")"
fi

if [[ "$TEST_MODE" != "1" ]] && port_in_use "$APP_PORT"; then
    perr "$(say "Port is already in use:" "Cổng đang được sử dụng:") $APP_PORT"
fi

NETWORK_MODE="localhost"
GRAFANA_BIND_IP="127.0.0.1"
APP_URL="http://localhost:${APP_PORT}"
LOCAL_HEALTH_URL="http://localhost:${APP_PORT}/api/health"

case "$NET_CHOICE" in
    2)
        NETWORK_MODE="lan"
        GRAFANA_BIND_IP="0.0.0.0"
        if [[ -n "$LAN_IP" ]]; then
            read -rp "  $(say "Use IP $LAN_IP? (Enter=OK, or type another)" "Dùng IP $LAN_IP? (Enter=OK, hoặc nhập IP khác)"): " CUSTOM_IP
            [[ -n "$CUSTOM_IP" ]] && LAN_IP="$CUSTOM_IP"
        else
            read -rp "  $(say "Enter LAN IP" "Nhập IP LAN"): " LAN_IP
            [[ -z "$LAN_IP" ]] && perr "$(say "LAN IP is required." "Bắt buộc nhập IP LAN.")"
        fi
        APP_URL="http://${LAN_IP}:${APP_PORT}"
        ;;
    3)
        NETWORK_MODE="domain"
        GRAFANA_BIND_IP="127.0.0.1"
        read -rp "  $(say "Enter public domain or URL (e.g. https://grafana.example.com)" "Nhập domain hoặc URL public (ví dụ: https://grafana.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ;;
    *)
        NETWORK_MODE="localhost"
        GRAFANA_BIND_IP="127.0.0.1"
        APP_URL="http://localhost:${APP_PORT}"
        ;;
esac

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "App URL:" "URL truy cập:") $APP_URL"

# ========================================
# Step 3: Prometheus link
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

PROM_INSTALL_DIR="$HOME/self-hosted/prometheus"
PROM_ENV_FILE="$PROM_INSTALL_DIR/.env"
PROM_EXISTS=false
if [[ -f "$PROM_ENV_FILE" ]]; then
    PROM_EXISTS=true
fi

USE_LOCAL_PROMETHEUS=false
PROMETHEUS_DATASOURCE_URL=""
PROMETHEUS_DISPLAY_URL=""
PROMETHEUS_LINK_MODE="external"

if [[ "$PROM_EXISTS" == "true" ]]; then
    DETECTED_PROM_URL=$(read_env_value "PROMETHEUS_URL" "$PROM_ENV_FILE")
    DETECTED_PROM_PORT=$(read_env_value "PROMETHEUS_HTTP_PORT" "$PROM_ENV_FILE")
    echo "  $(say "Detected Prometheus install:" "Đã phát hiện Prometheus:") $PROM_INSTALL_DIR"
    echo "  $(say "Current URL:" "URL hiện tại:") ${DETECTED_PROM_URL:-http://localhost:${DETECTED_PROM_PORT:-9090}}"
    echo ""
    echo "    1) $(say "Auto-link local Prometheus via shared Docker network (default)" "Tự ghép Prometheus local qua shared Docker network (mặc định)")"
    echo "    2) $(say "Use external Prometheus URL" "Dùng Prometheus URL bên ngoài")"
    read -rp "  $(say "Enter 1 or 2" "Nhập 1 hoặc 2") [1]: " PROM_LINK_CHOICE
    PROM_LINK_CHOICE=${PROM_LINK_CHOICE:-1}

    if [[ "$PROM_LINK_CHOICE" == "1" ]]; then
        USE_LOCAL_PROMETHEUS=true
        PROMETHEUS_LINK_MODE="local-network"
        PROMETHEUS_DATASOURCE_URL="http://prometheus-core:9090"
        PROMETHEUS_DISPLAY_URL="${DETECTED_PROM_URL:-http://localhost:${DETECTED_PROM_PORT:-9090}}"
    fi
fi

if [[ "$USE_LOCAL_PROMETHEUS" != "true" ]]; then
    DEFAULT_PROM_URL="http://host.docker.internal:9090"
    if [[ "$PROM_EXISTS" == "true" ]]; then
        DEFAULT_PROM_URL=$(read_env_value "PROMETHEUS_URL" "$PROM_ENV_FILE")
        [[ -z "$DEFAULT_PROM_URL" ]] && DEFAULT_PROM_URL="http://host.docker.internal:9090"
    fi
    read -rp "  $(say "Prometheus URL for Grafana datasource" "Prometheus URL cho datasource Grafana") [${DEFAULT_PROM_URL}]: " EXTERNAL_PROM_URL
    EXTERNAL_PROM_URL=${EXTERNAL_PROM_URL:-$DEFAULT_PROM_URL}
    if [[ "$EXTERNAL_PROM_URL" =~ ^https?:// ]]; then
        PROMETHEUS_DATASOURCE_URL="${EXTERNAL_PROM_URL%/}"
    else
        PROMETHEUS_DATASOURCE_URL="http://${EXTERNAL_PROM_URL%/}"
    fi
    [[ -z "$PROMETHEUS_DATASOURCE_URL" ]] && perr "$(say "Prometheus URL is required." "Bắt buộc nhập Prometheus URL.")"
    PROMETHEUS_DISPLAY_URL="$PROMETHEUS_DATASOURCE_URL"
fi

pok "$(say "Datasource mode:" "Chế độ datasource:") $PROMETHEUS_LINK_MODE"
pok "$(say "Prometheus target:" "Prometheus target:") $PROMETHEUS_DISPLAY_URL"

# ========================================
# Step 4: Directory & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

INSTALL_DIR="$HOME/self-hosted/grafana"
mkdir -p "$INSTALL_DIR/provisioning/datasources" "$INSTALL_DIR/provisioning/dashboards" "$INSTALL_DIR/dashboards"
cd "$INSTALL_DIR"
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

OLD_GRAFANA_IMAGE=$(read_env_value "GRAFANA_IMAGE" ".env")
OLD_GRAFANA_ADMIN_USER=$(read_env_value "GRAFANA_ADMIN_USER" ".env")
OLD_GRAFANA_ADMIN_PASSWORD=$(read_env_value "GRAFANA_ADMIN_PASSWORD" ".env")
OLD_GRAFANA_TIMEZONE=$(read_env_value "GRAFANA_TIMEZONE" ".env")
OLD_GRAFANA_INSTANCE_NAME=$(read_env_value "GRAFANA_INSTANCE_NAME" ".env")

GRAFANA_IMAGE=${OLD_GRAFANA_IMAGE:-grafana/grafana:latest}
GRAFANA_ADMIN_USER=${OLD_GRAFANA_ADMIN_USER:-admin}
GRAFANA_ADMIN_PASSWORD=${OLD_GRAFANA_ADMIN_PASSWORD:-$(openssl rand -hex 12)}
GRAFANA_TIMEZONE=${OLD_GRAFANA_TIMEZONE:-$(detect_timezone)}
GRAFANA_INSTANCE_NAME=${OLD_GRAFANA_INSTANCE_NAME:-vnROM Monitoring}
GRAFANA_DOMAIN=$(host_from_url "$APP_URL")

cat > .env <<ENVEOF
# =================================================================
# Grafana Self-Hosted Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Platform: $PLATFORM_LABEL
# Mode: $NETWORK_MODE
# =================================================================

# Access
GRAFANA_HTTP_PORT=$APP_PORT
GRAFANA_BIND_IP=$GRAFANA_BIND_IP
GRAFANA_URL=$APP_URL
GRAFANA_DOMAIN=$GRAFANA_DOMAIN
GRAFANA_TIMEZONE=$GRAFANA_TIMEZONE
GRAFANA_INSTANCE_NAME=$GRAFANA_INSTANCE_NAME

# Image
GRAFANA_IMAGE=$GRAFANA_IMAGE

# Security
GRAFANA_ADMIN_USER=$GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# Prometheus integration
GRAFANA_PROMETHEUS_URL=$PROMETHEUS_DATASOURCE_URL
GRAFANA_PROMETHEUS_DISPLAY_URL=$PROMETHEUS_DISPLAY_URL
GRAFANA_USE_LOCAL_PROMETHEUS=$USE_LOCAL_PROMETHEUS
ENVEOF

pok "$(say "Saved .env with Grafana defaults." "Đã lưu .env với cấu hình Grafana mặc định.")"

# ========================================
# Step 5: Provisioning files
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

cat > provisioning/datasources/prometheus.yml <<DATASOURCEEOF
apiVersion: 1
prune: true

datasources:
  - name: Prometheus
    uid: prometheus-main
    type: prometheus
    access: proxy
    url: $PROMETHEUS_DATASOURCE_URL
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      manageAlerts: true
DATASOURCEEOF

cat > provisioning/dashboards/default.yml <<'DASHBOARDEOF'
apiVersion: 1

providers:
  - name: vnrom-monitoring
    orgId: 1
    folder: vnROM Monitoring
    type: file
    disableDeletion: false
    editable: true
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
DASHBOARDEOF

cat > dashboards/prometheus-overview.json <<'JSONEOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 6,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "value_and_name"
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "max(up{job=\"prometheus\"})",
          "refId": "A"
        }
      ],
      "title": "Prometheus Up",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 6,
        "x": 6,
        "y": 0
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "value_and_name"
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "prometheus_tsdb_head_series",
          "refId": "A"
        }
      ],
      "title": "Head Series",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 6,
        "x": 12,
        "y": 0
      },
      "id": 3,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "value_and_name"
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "process_resident_memory_bytes{job=\"prometheus\"}",
          "refId": "A"
        }
      ],
      "title": "Prometheus RSS",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 6,
        "x": 18,
        "y": 0
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "value_and_name"
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "max(up{job=\"node\"})",
          "refId": "A"
        }
      ],
      "title": "Node Exporter Up",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "drawStyle": "line",
            "fillOpacity": 10,
            "lineWidth": 2,
            "showPoints": "never"
          },
          "mappings": [],
          "unit": "ops"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 6
      },
      "id": 5,
      "options": {
        "legend": {
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "rate(prometheus_tsdb_head_samples_appended_total[5m])",
          "legendFormat": "samples/s",
          "refId": "A"
        }
      ],
      "title": "TSDB Samples Appended",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "drawStyle": "line",
            "fillOpacity": 10,
            "lineWidth": 2,
            "showPoints": "never"
          },
          "mappings": [],
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 6
      },
      "id": 6,
      "options": {
        "legend": {
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "12.1.0",
      "targets": [
        {
          "expr": "process_resident_memory_bytes{job=\"prometheus\"}",
          "legendFormat": "RSS",
          "refId": "A"
        }
      ],
      "title": "Prometheus Memory",
      "type": "timeseries"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 41,
  "style": "dark",
  "tags": [
    "vnrom",
    "prometheus"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "browser",
  "title": "Prometheus Overview",
  "uid": "prometheus-overview",
  "version": 1,
  "weekStart": ""
}
JSONEOF

python3 -m json.tool dashboards/prometheus-overview.json >/dev/null
pok "$(say "Provisioning files created." "Đã tạo provisioning files.")"

# ========================================
# Step 6: Docker Compose files
# ========================================
echo ""
echo -e "${BOLD}$(step_title 6)${NC}"

if [[ "$USE_LOCAL_PROMETHEUS" == "true" && "$SKIP_DOCKER_COMMANDS" == "0" ]]; then
    ensure_prometheus_shared_network || perr "$(say "Could not create Prometheus shared network." "Không thể tạo Prometheus shared network.")"
fi

cat > docker-compose.yml <<'COMPOSEEOF'
name: grafana

services:
  grafana:
    image: ${GRAFANA_IMAGE:-grafana/grafana:latest}
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_BIND_IP:-127.0.0.1}:${GRAFANA_HTTP_PORT:-3000}:3000"
    environment:
      TZ: ${GRAFANA_TIMEZONE:-UTC}
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-admin}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_AUTH_ANONYMOUS_ENABLED: "false"
      GF_SERVER_ROOT_URL: ${GRAFANA_URL:-http://localhost:3000}
      GF_SERVER_DOMAIN: ${GRAFANA_DOMAIN:-localhost}
      GF_SERVER_SERVE_FROM_SUB_PATH: "false"
      GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: /var/lib/grafana/dashboards/prometheus-overview.json
      GF_SECURITY_DISABLE_GRAVATAR: "true"
      GF_ANALYTICS_CHECK_FOR_UPDATES: "false"
      GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES: "false"
      GF_ANALYTICS_REPORTING_ENABLED: "false"
      GF_USERS_DEFAULT_THEME: light
    volumes:
      - grafana_data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning:ro
      - ./dashboards:/var/lib/grafana/dashboards:ro
    networks:
      - grafana-network
COMPOSEEOF

if [[ "$USE_LOCAL_PROMETHEUS" == "true" ]]; then
    cat >> docker-compose.yml <<'COMPOSEEOF'
      - prometheus-network
COMPOSEEOF
fi

cat >> docker-compose.yml <<'COMPOSEEOF'

volumes:
  grafana_data:

networks:
  grafana-network:
    driver: bridge
COMPOSEEOF

if [[ "$USE_LOCAL_PROMETHEUS" == "true" ]]; then
    cat >> docker-compose.yml <<'COMPOSEEOF'
  prometheus-network:
    external: true
    name: prometheus-shared
COMPOSEEOF
fi

pok "$(say "Docker Compose file generated." "Đã tạo file Docker Compose.")"

# ========================================
# Step 7: Validation
# ========================================
echo ""
echo -e "${BOLD}$(step_title 7)${NC}"

if [[ "$SKIP_DOCKER_COMMANDS" == "1" ]]; then
    pwn "$(say "Skipping compose validation in TEST MODE (docker unavailable)." "Bỏ qua kiểm tra compose trong TEST MODE (docker chưa sẵn sàng).")"
else
    dc config >/dev/null 2>&1 || perr "$(say "docker compose config failed." "docker compose config lỗi.")"
    pok "$(say "docker compose config: OK" "docker compose config: OK")"
fi

# ========================================
# Step 8: Start & verify
# ========================================
echo ""
echo -e "${BOLD}$(step_title 8)${NC}"

ALL_OK=true

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping docker compose up and runtime health checks." "Test mode: bỏ qua docker compose up và runtime health checks.")"
else
    MAX_START_ATTEMPTS=${GRAFANA_START_RETRIES:-3}
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

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Failed to start Grafana stack." "Không thể khởi động stack Grafana.")"
    pok "$(say "Containers started." "Containers đã khởi động.")"

    HEALTH_TIMEOUT=${GRAFANA_HEALTH_TIMEOUT:-180}
    ELAPSED=0
    HEALTH_OK=false

    pwn "$(say "Waiting for Grafana health endpoint..." "Đang đợi health endpoint của Grafana...")"
    while [[ "$ELAPSED" -lt "$HEALTH_TIMEOUT" ]]; do
        if curl -fsS "$LOCAL_HEALTH_URL" >/dev/null 2>&1; then
            HEALTH_OK=true
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done

    if [[ "$HEALTH_OK" == "true" ]]; then
        pok "$(say "Grafana health is ready:" "Grafana health đã sẵn sàng:") $LOCAL_HEALTH_URL"
    else
        pwn "$(say "Grafana health timeout:" "Grafana health timeout:") $LOCAL_HEALTH_URL"
        ALL_OK=false
    fi

    if curl -fsS -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" "http://localhost:${APP_PORT}/api/datasources/uid/prometheus-main" >/dev/null 2>&1; then
        pok "$(say "Prometheus datasource provisioned." "Prometheus datasource đã được provision.")"
    else
        pwn "$(say "Prometheus datasource is missing or Grafana API is not ready." "Datasource Prometheus chưa có hoặc Grafana API chưa sẵn sàng.")"
        ALL_OK=false
    fi

    if curl -fsS -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" --get "http://localhost:${APP_PORT}/api/datasources/proxy/uid/prometheus-main/api/v1/query" --data-urlencode 'query=up' >/dev/null 2>&1; then
        pok "$(say "Grafana datasource proxy can query Prometheus." "Datasource proxy của Grafana đã query được Prometheus.")"
    else
        pwn "$(say "Grafana datasource exists but proxy query to Prometheus failed." "Datasource Grafana đã có nhưng proxy query sang Prometheus bị lỗi.")"
        ALL_OK=false
    fi

    if curl -fsS -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" "http://localhost:${APP_PORT}/api/dashboards/uid/prometheus-overview" >/dev/null 2>&1; then
        pok "$(say "Starter dashboard imported." "Starter dashboard đã được import.")"
    else
        pwn "$(say "Starter dashboard is missing." "Starter dashboard bị thiếu.")"
        ALL_OK=false
    fi

    RUNNING_SERVICES=$(dc ps --status running --services 2>/dev/null || true)
    if echo "$RUNNING_SERVICES" | grep -qx 'grafana'; then
        pok "grafana: running"
    else
        pwn "grafana: not running"
        ALL_OK=false
    fi
fi

# ========================================
# Step 9: Helper & summary
# ========================================
echo ""
echo -e "${BOLD}$(step_title 9)${NC}"

cat > grafana.sh <<'HELPEREOF'
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

dashboard_uid() {
  echo "prometheus-overview"
}

grafana_url() {
  grep '^GRAFANA_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:3000"
}

http_port() {
  grep '^GRAFANA_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "3000"
}

admin_user() {
  grep '^GRAFANA_ADMIN_USER=' .env 2>/dev/null | cut -d= -f2- || echo "admin"
}

admin_password() {
  grep '^GRAFANA_ADMIN_PASSWORD=' .env 2>/dev/null | cut -d= -f2- || echo "admin"
}

prometheus_display_url() {
  grep '^GRAFANA_PROMETHEUS_DISPLAY_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:9090"
}

use_local_prometheus() {
  grep '^GRAFANA_USE_LOCAL_PROMETHEUS=' .env 2>/dev/null | cut -d= -f2- || echo "false"
}

ensure_prometheus_shared_network() {
  if [[ "$(use_local_prometheus)" != "true" ]]; then
    return 0
  fi

  if docker info >/dev/null 2>&1; then
    docker network inspect prometheus-shared >/dev/null 2>&1 || docker network create prometheus-shared >/dev/null
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker network inspect prometheus-shared >/dev/null 2>&1 || sudo docker network create prometheus-shared >/dev/null
  fi
}

case "${1:-}" in
  start)
    echo "Starting Grafana..."
    ensure_prometheus_shared_network
    dc up -d --pull always
    echo "Started: $(grafana_url)"
    ;;
  stop)
    echo "Stopping Grafana..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting Grafana..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-grafana}"
    ;;
  health)
    PORT=$(http_port)
    curl -fsS "http://localhost:${PORT}/api/health"
    ;;
  datasource)
    PORT=$(http_port)
    curl -fsS -u "$(admin_user):$(admin_password)" "http://localhost:${PORT}/api/datasources/uid/prometheus-main"
    ;;
  dashboard)
    PORT=$(http_port)
    curl -fsS -u "$(admin_user):$(admin_password)" "http://localhost:${PORT}/api/dashboards/uid/$(dashboard_uid)"
    ;;
  credentials)
    echo "Grafana URL: $(grafana_url)"
    echo "Admin user:  $(admin_user)"
    echo "Admin pass:  $(admin_password)"
    echo "Prometheus:  $(prometheus_display_url)"
    ;;
  upgrade)
    echo "Upgrading Grafana images..."
    ensure_prometheus_shared_network
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  reset)
    echo "This will DELETE Grafana data volume."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Grafana Helper"
    echo ""
    echo "Usage: ./grafana.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start/upgrade stack"
    echo "  stop         - Stop services"
    echo "  restart      - Restart services"
    echo "  status       - Show service status"
    echo "  logs [svc]   - Follow logs (default: grafana)"
    echo "  health       - Check /api/health"
    echo "  datasource   - Show provisioned Prometheus datasource"
    echo "  dashboard    - Show starter dashboard metadata"
    echo "  credentials  - Show Grafana login and Prometheus target"
    echo "  upgrade      - Pull latest images and restart"
    echo "  reset        - Delete Grafana data volume"
    ;;
 esac
HELPEREOF

chmod +x grafana.sh
pok "$(say "Helper script created: ./grafana.sh" "Đã tạo helper script: ./grafana.sh")"

echo ""
echo "========================================================"
if [[ "$ALL_OK" == "true" ]]; then
    echo -e "${GREEN}  $(say "INSTALLATION COMPLETE" "CÀI ĐẶT HOÀN TẤT")${NC}"
else
    echo -e "${YELLOW}  $(say "INSTALL FINISHED WITH WARNINGS" "CÀI ĐẶT XONG (CÓ CẢNH BÁO)")${NC}"
fi
echo ""
echo -e "  $(say "Platform" "Nền tảng"):        ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "Grafana URL" "URL Grafana"):     ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Prometheus" "Prometheus"):      ${CYAN}${PROMETHEUS_DISPLAY_URL}${NC}"
echo -e "  $(say "Directory" "Thư mục"):        ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  $(say "Admin user" "Admin user"):     ${CYAN}${GRAFANA_ADMIN_USER}${NC}"
echo -e "  $(say "Admin password" "Admin password"): ${CYAN}${GRAFANA_ADMIN_PASSWORD}${NC}"

echo ""
echo -e "${CYAN}$(say "Management" "Quản lý"):${NC}"
echo "  • ./grafana.sh status"
echo "  • ./grafana.sh health"
echo "  • ./grafana.sh datasource"
echo "  • ./grafana.sh dashboard"
echo "  • ./grafana.sh credentials"
echo ""

echo -e "${YELLOW}$(say "Important" "Quan trọng"):${NC}"
echo "  • $(say "Do not share .env (contains admin credentials)." "Không chia sẻ file .env (chứa admin credentials).")"
echo "  • $(say "Grafana uses the default home dashboard from ./dashboards/prometheus-overview.json." "Grafana dùng home dashboard mặc định từ ./dashboards/prometheus-overview.json.")"
if [[ "$NETWORK_MODE" == "domain" ]]; then
    echo "  • $(say "Ensure reverse proxy forwards your domain to http://127.0.0.1:${APP_PORT}" "Đảm bảo reverse proxy trỏ domain vào http://127.0.0.1:${APP_PORT}")"
fi
if [[ "$USE_LOCAL_PROMETHEUS" == "true" ]]; then
    echo "  • $(say "This stack expects Prometheus on the shared Docker network 'prometheus-shared'." "Stack này kỳ vọng Prometheus trên shared Docker network 'prometheus-shared'.")"
fi

echo ""
echo "Support: https://ai.vnrom.net"
echo "Docs:    https://grafana.com/docs/grafana/latest/"
