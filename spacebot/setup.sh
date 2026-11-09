#!/usr/bin/env bash

# ==============================================================================
# Spacebot Standalone Installer (Gen 4 Standard)
# Supports: macOS (Apple Silicon/Intel), Linux VPS (AMD64/ARM64), Raspberry Pi 4/5
# Author: duynghien (vnROM.net)
# ==============================================================================

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -n "${INSTALL_DIR:-}" && -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m cd \"${INSTALL_DIR}\" && docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'

pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

# ==============================================================================
# Language Selection (EN/VI)
# ==============================================================================
APP_LANG="${APP_LANG:-}"
if [[ -z "$APP_LANG" ]]; then
    echo ""
    echo -e "${BOLD}Select Language / Chọn ngôn ngữ:${NC}"
    echo "  1) English (default)"
    echo "  2) Tiếng Việt"
    read -rp "Choice [1-2] (default: 1): " LANG_CHOICE || true
    case "${LANG_CHOICE:-1}" in
        2|vi|VI) APP_LANG="vi" ;;
        *) APP_LANG="en" ;;
    esac
fi

say() {
    local en="$1"
    local vi="$2"
    if [[ "$APP_LANG" == "vi" ]]; then
        echo "$vi"
    else
        echo "$en"
    fi
}

step_title() {
    local num="$1"
    local en="$2"
    local vi="$3"
    echo -e "\n${BOLD}${CYAN}[$num/6] $(say "$en" "$vi")${NC}"
}

# ==============================================================================
# Platform Detection
# ==============================================================================
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
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux ($ARCH)"
    fi
else
    perr "Unsupported OS: $OS"
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
echo "          Spacebot Standalone Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo -e "  $(say "AI agent for teams, communities & multi-user environments" "AI agent dành cho đội ngũ, cộng đồng và môi trường nhiều người dùng")"
echo ""

# ==============================================================================
# Step 1: Preflight & Dependencies
# ==============================================================================
step_title 1 "Preflight Checks & Dependencies" "Kiểm tra hệ thống & Cài đặt phụ thuộc"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &>/dev/null; then
        perr "$(say "Docker is not installed. Please install OrbStack or Docker Desktop." "Docker chưa được cài đặt. Vui lòng cài OrbStack hoặc Docker Desktop.")"
    fi
    pok "Docker: OK"
    if ! docker compose version &>/dev/null; then
        perr "$(say "Docker Compose plugin is missing." "Thiếu Docker Compose plugin.")"
    fi
    pok "Docker Compose: OK"
else
    # Linux: Auto-install Docker
    if ! command -v docker &>/dev/null; then
        pwn "$(say "Docker not found, installing..." "Không tìm thấy Docker, đang cài đặt...")"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
        pok "Docker: OK"
    else
        pok "Docker: OK"
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"
fi

for tool in curl; do
    if ! command -v "$tool" &>/dev/null; then
        perr "Missing required tool: $tool"
    fi
done

# ==============================================================================
# Step 2: Network Configuration & Port Checks
# ==============================================================================
step_title 2 "Network Configuration & Port Checks" "Cấu hình Mạng & Kiểm tra Cổng"

check_port() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN -Pn &>/dev/null
    elif command -v ss &>/dev/null; then
        ss -ltn "sport = :$port" 2>/dev/null | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -ltn 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

DEFAULT_PORT=19898
PORT="$DEFAULT_PORT"

if check_port "$PORT"; then
    pwn "$(say "Port $PORT is currently occupied!" "Cổng $PORT hiện đang bị chiếm dụng!")"
    read -rp "$(say "Enter alternative port (default: 19899): " "Nhập cổng thay thế (mặc định: 19899): ")" ALT_PORT || true
    PORT="${ALT_PORT:-19899}"
    while check_port "$PORT"; do
        pwn "$(say "Port $PORT is also occupied." "Cổng $PORT cũng đang bị chiếm.")"
        read -rp "$(say "Enter another port: " "Nhập cổng khác: ")" PORT || true
    done
fi
pok "$(say "Using port: $PORT" "Sử dụng cổng: $PORT")"

echo ""
echo -e "${BOLD}$(say "Select Network Access Mode:" "Chọn chế độ truy cập mạng:")${NC}"
echo "  1) Localhost (127.0.0.1:$PORT)"
echo "  2) Local LAN IP (Accessible from local network)"
echo "  3) Public Domain (Reverse Proxy / Cloudflare Tunnel / VPS Domain)"
read -rp "$(say "Choice [1-3] (default: 1): " "Lựa chọn [1-3] (mặc định: 1): ")" NET_MODE_CHOICE || true

case "${NET_MODE_CHOICE:-1}" in
    2)
        LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ipconfig getifaddr en0 2>/dev/null || echo "127.0.0.1")
        APP_URL="http://${LAN_IP}:${PORT}"
        ;;
    3)
        read -rp "$(say "Enter your public domain (e.g. spacebot.example.com): " "Nhập domain công khai (VD: spacebot.example.com): ")" USER_DOMAIN || true
        USER_DOMAIN="${USER_DOMAIN#http://}"
        USER_DOMAIN="${USER_DOMAIN#https://}"
        USER_DOMAIN="${USER_DOMAIN%/}"
        if [[ -z "$USER_DOMAIN" ]]; then
            APP_URL="http://localhost:${PORT}"
        else
            APP_URL="https://${USER_DOMAIN}"
        fi
        ;;
    *)
        APP_URL="http://localhost:${PORT}"
        ;;
esac
pok "$(say "Target URL: $APP_URL" "URL đích: $APP_URL")"

# ==============================================================================
# Step 3: Install Directory Setup
# ==============================================================================
step_title 3 "Install Directory Setup" "Thiết lập Thư mục Cài đặt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
INSTALL_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/spacebot"

mkdir -p "$INSTALL_DIR/data"
chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory: $INSTALL_DIR" "Thư mục cài đặt: $INSTALL_DIR")"

# ==============================================================================
# Step 4: Authoritative Inline File Generation
# ==============================================================================
step_title 4 "Authoritative Configuration Generation" "Sinh Cấu hình Độc lập Tự chứa"

# Generate docker-compose.yml
cat << COMPOSE_EOF > docker-compose.yml
services:
  spacebot:
    image: ghcr.io/spacedriveapp/spacebot:latest
    container_name: spacebot
    restart: unless-stopped
    ports:
      - "${PORT}:19898"
    volumes:
      - ./data:/data
    environment:
      - SPACEBOT_DIR=/data
      - ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}
      - OPENAI_API_KEY=\${OPENAI_API_KEY:-}
      - OPENROUTER_API_KEY=\${OPENROUTER_API_KEY:-}
      - DISCORD_BOT_TOKEN=\${DISCORD_BOT_TOKEN:-}
      - SLACK_BOT_TOKEN=\${SLACK_BOT_TOKEN:-}
      - TELEGRAM_BOT_TOKEN=\${TELEGRAM_BOT_TOKEN:-}
COMPOSE_EOF

# Sync sibling file in repo if present
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -d "$SCRIPT_DIR" ]]; then
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
fi
pok "$(say "docker-compose.yml generated." "Đã sinh docker-compose.yml.")"

# Preserve existing .env secrets idempotently
OLD_ANTHROPIC=""
OLD_OPENAI=""
OLD_OPENROUTER=""
OLD_DISCORD=""
OLD_SLACK=""
OLD_TELEGRAM=""

if [ -f .env ]; then
    pok "$(say "Existing .env detected, preserving configured tokens." "Phát hiện file .env cũ, giữ nguyên các token đã cấu hình.")"
    OLD_ANTHROPIC=$(grep -E '^ANTHROPIC_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_OPENAI=$(grep -E '^OPENAI_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_OPENROUTER=$(grep -E '^OPENROUTER_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_DISCORD=$(grep -E '^DISCORD_BOT_TOKEN=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_SLACK=$(grep -E '^SLACK_BOT_TOKEN=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_TELEGRAM=$(grep -E '^TELEGRAM_BOT_TOKEN=' .env 2>/dev/null | cut -d= -f2- || true)
fi

cat << EOF > .env
PORT=${PORT}
ANTHROPIC_API_KEY=${OLD_ANTHROPIC}
OPENAI_API_KEY=${OLD_OPENAI}
OPENROUTER_API_KEY=${OLD_OPENROUTER}
DISCORD_BOT_TOKEN=${OLD_DISCORD}
SLACK_BOT_TOKEN=${OLD_SLACK}
TELEGRAM_BOT_TOKEN=${OLD_TELEGRAM}
EOF

chmod 600 .env
pok "$(say "Environment file saved (.env, chmod 600)." "Đã lưu file môi trường (.env, chmod 600).")"

# ==============================================================================
# Step 5: Helper Script Generation (spacebot.sh)
# ==============================================================================
step_title 5 "Helper CLI Generation" "Tạo Trình Quản Lý CLI (spacebot.sh)"

cat << 'HELPER_EOF' > spacebot.sh
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
CMD="${1:-help}"

get_env_val() {
  local key="$1"
  grep -E "^${key}=" .env 2>/dev/null | head -n 1 | cut -d= -f2- || true
}

case "$CMD" in
  status)
    echo "=== Spacebot Stack Status ==="
    docker compose ps
    PORT=$(get_env_val "PORT")
    echo ""
    echo "Active URL: http://localhost:${PORT:-19898}"
    ;;
  start)
    echo "Starting Spacebot..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping Spacebot..."
    docker compose stop
    ;;
  restart)
    echo "Restarting Spacebot..."
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${1:-spacebot}"
    ;;
  update)
    echo "Updating Spacebot..."
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    tar -czf "backups/spacebot-pre-update-${TIMESTAMP}.tar.gz" .env docker-compose.yml 2>/dev/null || true
    chmod 600 "backups/spacebot-pre-update-${TIMESTAMP}.tar.gz" 2>/dev/null || true
    docker compose pull
    docker compose up -d
    echo "Update complete."
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    ARCHIVE="backups/spacebot-backup-${TIMESTAMP}.tar.gz"
    echo "Creating backup (configs + data)..."
    tar -czf "$ARCHIVE" .env docker-compose.yml data/
    chmod 600 "$ARCHIVE"
    echo "Backup created successfully: $ARCHIVE"
    ;;
  restore)
    BACKUP_FILE="${2:-}"
    if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
      echo "Error: Please specify a valid backup archive."
      echo "Usage: ./spacebot.sh restore backups/<archive>.tar.gz"
      exit 1
    fi
    echo "Verifying archive integrity..."
    if ! gzip -t "$BACKUP_FILE"; then
      echo "Error: Corrupted archive! Restore aborted."
      exit 1
    fi
    mkdir -p -m 700 backups
    SAFETY_SNAP="backups/spacebot-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$SAFETY_SNAP" .env docker-compose.yml data/ 2>/dev/null || true
    chmod 600 "$SAFETY_SNAP" 2>/dev/null || true
    echo "Safety snapshot created: $SAFETY_SNAP"
    docker compose stop
    tar -xzf "$BACKUP_FILE"
    chmod 600 .env 2>/dev/null || true
    docker compose up -d
    echo "Restore completed successfully."
    ;;
  doctor)
    echo "=== Spacebot Health Check ==="
    if docker info &>/dev/null; then
      echo "  [OK] Docker engine is running"
    else
      echo "  [FAIL] Docker engine is unreachable"
    fi
    echo "  Disk Space:"
    df -h . | awk 'NR==2 {print "    Available: " $4 " on " $1}'
    PORT=$(get_env_val "PORT")
    PORT="${PORT:-19898}"
    echo "  Port $PORT binding:"
    if lsof -iTCP:"$PORT" -sTCP:LISTEN -Pn &>/dev/null 2>&1 || ss -ltn "sport = :$PORT" 2>/dev/null | grep -q ":$PORT "; then
      echo "    Port $PORT is active and listening"
    else
      echo "    Port $PORT is not active"
    fi
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env permissions: $PERMS (recommended: 600)"
    fi
    ;;
  uninstall)
    echo "WARNING: This will stop Spacebot and remove container resources."
    read -rp "Type 'yes' to confirm uninstallation: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v 2>/dev/null || true
      echo "Spacebot stack stopped and containers removed."
      echo "Data directory remained preserved at: $(pwd)/data"
    else
      echo "Uninstall aborted."
    fi
    ;;
  *)
    echo "Usage: ./spacebot.sh {status|start|stop|restart|logs|update|backup|restore|doctor|uninstall}"
    ;;
esac
HELPER_EOF

chmod +x spacebot.sh
chown "$TARGET_USER:$TARGET_GROUP" .env docker-compose.yml spacebot.sh
pok "$(say "Helper CLI ./spacebot.sh created successfully." "Đã tạo trình quản lý ./spacebot.sh thành công.")"

# ==============================================================================
# Step 6: Start & Health Verification
# ==============================================================================
step_title 6 "Start Services & Verification" "Khởi chạy & Kiểm tra Dịch vụ"

docker compose up -d
pok "$(say "Container started, waiting for service to bind port..." "Đang chờ container khởi động...")"
sleep 3

ALL_OK=true
if curl -sf "http://localhost:${PORT}" &>/dev/null; then
    pok "$(say "Spacebot UI: Healthy and reachable!" "Giao diện Spacebot: Hoạt động bình thường!")"
else
    pwn "$(say "Spacebot UI: starting (may need a moment to complete initialization)." "Giao diện Spacebot đang khởi động (có thể cần một chút thời gian để sẵn sàng).")"
fi

echo ""
echo "================================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 $(say "INSTALLATION COMPLETE!" "CÀI ĐẶT THÀNH CÔNG!")${NC}"
else
    echo -e "${YELLOW}  ⚠️  $(say "INSTALLATION DONE (service might still be booting)" "HOÀN TẤT (Dịch vụ đang khởi động)")${NC}"
fi
echo ""
echo -e "  $(say "Platform:" "Nền tảng:")      ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "Spacebot UI:" "Giao diện:")    ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Config Path:" "Đường dẫn file:")   ${CYAN}${INSTALL_DIR}/.env${NC}"
echo ""
echo -e "${YELLOW}⚠️  $(say "IMPORTANT:" "QUAN TRỌNG:")${NC}"
echo "  • $(say "Open the Spacebot UI in your browser to complete onboarding" "Mở giao diện Spacebot trên trình duyệt để hoàn tất thiết lập ban đầu")"
echo "  • $(say "Manage stack with: cd ${INSTALL_DIR} && ./spacebot.sh" "Quản lý bằng lệnh: cd ${INSTALL_DIR} && ./spacebot.sh")"
echo ""
echo -e "${CYAN}$(say "Management Commands:" "Lệnh Quản Lý:"):${NC}"
echo "  • ./spacebot.sh status"
echo "  • ./spacebot.sh logs"
echo "  • ./spacebot.sh restart"
echo "  • ./spacebot.sh backup"
echo "  • ./spacebot.sh doctor"
echo ""
echo "Support: https://ai.vnrom.net"
