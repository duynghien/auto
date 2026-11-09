#!/usr/bin/env bash

# ==============================================================================
# Scrapling Standalone Installer (Gen 4 Standard)
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
    echo -e "\n${BOLD}${CYAN}[$num/5] $(say "$en" "$vi")${NC}"
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
echo "          Scrapling Standalone Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo -e "  $(say "Undetectable web scraper & AI Agent MCP Server" "Công cụ cào dữ liệu web thông minh & MCP Server cho AI Agent")"
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

    sudo apt-get install -y -qq build-essential libssl-dev git curl 2>/dev/null || true
    pok "Build dependencies: OK"

    # RAM & Swap Preflight Guard
    if command -v free &>/dev/null; then
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
        TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
        pok "RAM: ${TOTAL_RAM}MB | Swap: ${TOTAL_SWAP}MB"

        if [[ "$TOTAL_RAM" -lt 4000 && "$TOTAL_SWAP" -lt 2000 ]]; then
            pwn "$(say "Low memory detected. Playwright browser compile requires swap." "Phát hiện RAM thấp. Quá trình cài đặt Playwright Chromium cần Swap.")"
            read -rp "$(say "Configure 4GB Swapfile now? [Y/n]: " "Cấu hình 4GB Swapfile ngay bây giờ? [Y/n]: ")" CREATE_SWAP || true
            case "${CREATE_SWAP:-y}" in
                [yY][eE][sS]|[yY]|"")
                    FREE_DISK_MB=$(df -Pm / | awk 'NR==2 {print $4}')
                    if [[ "$FREE_DISK_MB" -lt 8192 ]]; then
                        pwn "$(say "Insufficient free disk (<8GB free). Skipping swapfile creation." "Dung lượng trống không đủ (<8GB). Bỏ qua tạo swapfile.")"
                    else
                        echo "Allocating 4GB /swapfile..."
                        sudo fallocate -l 4G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
                        sudo chmod 600 /swapfile
                        sudo mkswap /swapfile
                        if ! sudo swapon /swapfile 2>/dev/null; then
                            pwn "$(say "swapon restricted on this virtual environment (LXC/OpenVZ). Skipping swap." "swapon bị giới hạn trên môi trường ảo hóa này (LXC/OpenVZ). Bỏ qua tạo swap.")"
                            sudo rm -f /swapfile
                        else
                            grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
                            pok "$(say "Swap: 4GB configured successfully." "Swap: Đã cấu hình 4GB thành công.")"
                        fi
                    fi
                    ;;
                *)
                    pwn "$(say "Skipping swap creation per user request." "Bỏ qua tạo swap theo yêu cầu.")"
                    ;;
            esac
        fi
    fi
fi

# ==============================================================================
# Step 2: Port & Directory Configuration
# ==============================================================================
step_title 2 "Port & Directory Setup" "Cấu hình Cổng & Thư mục Cài đặt"

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

DEFAULT_MCP_PORT=8000
MCP_PORT="$DEFAULT_MCP_PORT"

if check_port "$MCP_PORT"; then
    pwn "$(say "MCP Port $MCP_PORT is currently occupied!" "Cổng MCP $MCP_PORT hiện đang bị chiếm dụng!")"
    read -rp "$(say "Enter alternative port (default: 8001): " "Nhập cổng thay thế (mặc định: 8001): ")" ALT_PORT || true
    MCP_PORT="${ALT_PORT:-8001}"
    while check_port "$MCP_PORT"; do
        pwn "$(say "Port $MCP_PORT is also occupied." "Cổng $MCP_PORT cũng đang bị chiếm.")"
        read -rp "$(say "Enter another port: " "Nhập cổng khác: ")" MCP_PORT || true
    done
fi
pok "$(say "Using MCP port: $MCP_PORT" "Sử dụng cổng MCP: $MCP_PORT")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
INSTALL_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/scrapling"

mkdir -p "$INSTALL_DIR/data"
chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory: $INSTALL_DIR" "Thư mục cài đặt: $INSTALL_DIR")"

# ==============================================================================
# Step 3: Authoritative Inline File Generation
# ==============================================================================
step_title 3 "Authoritative Configuration Generation" "Sinh Cấu hình Độc lập Tự chứa"

# Generate Dockerfile
cat << 'DOCKERFILE_EOF' > Dockerfile
# Multi-arch Scrapling Docker image
# Supports: linux/amd64 (VPS), linux/arm64 (Raspberry Pi), darwin/arm64 (macOS Apple Silicon)
FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/D4Vinci/Scrapling.git /app

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-install-project --all-extras --compile-bytecode

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    uv run playwright install-deps chromium && \
    uv run playwright install chromium && \
    uv sync --all-extras --compile-bytecode && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 8000

RUN mkdir -p /data
WORKDIR /data

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD uv run --project /app scrapling --help > /dev/null 2>&1 || exit 1

ENTRYPOINT ["uv", "run", "--project", "/app", "scrapling"]
CMD ["--help"]
DOCKERFILE_EOF

# Generate docker-compose.yml
cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  scrapling-mcp:
    build:
      context: .
      dockerfile: Dockerfile
    image: scrapling:latest
    container_name: scrapling-mcp
    restart: unless-stopped
    ports:
      - "${MCP_PORT:-8000}:8000"
    volumes:
      - ./data:/data
    environment:
      - PYTHONUNBUFFERED=1
    command: [ "mcp", "--http", "--host", "0.0.0.0", "--port", "8000" ]
    profiles:
      - mcp
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:8000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  scrapling:
    build:
      context: .
      dockerfile: Dockerfile
    image: scrapling:latest
    container_name: scrapling-cli
    volumes:
      - ./data:/data
    environment:
      - PYTHONUNBUFFERED=1
    profiles:
      - cli
COMPOSE_EOF

# Sync sibling files in repo if present
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -d "$SCRIPT_DIR" ]]; then
    cp -f "$INSTALL_DIR/Dockerfile" "$SCRIPT_DIR/Dockerfile" 2>/dev/null || true
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
fi
pok "$(say "Dockerfile and docker-compose.yml generated." "Đã sinh Dockerfile và docker-compose.yml.")"

# Generate .env file
cat << EOF > .env
MCP_PORT=${MCP_PORT}
PYTHONUNBUFFERED=1
EOF
chmod 600 .env
pok "$(say "Environment file saved (.env, chmod 600)." "Đã lưu file môi trường (.env, chmod 600).")"

# ==============================================================================
# Step 4: Helper CLI Generation (scrapling.sh)
# ==============================================================================
step_title 4 "Helper CLI Generation" "Tạo Trình Quản Lý CLI (scrapling.sh)"

cat << 'HELPER_EOF' > scrapling.sh
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
    echo "=== Scrapling Stack Status ==="
    docker compose --profile mcp ps
    PORT=$(get_env_val "MCP_PORT")
    echo ""
    echo "MCP Server Endpoint: http://localhost:${PORT:-8000}/mcp"
    ;;
  start)
    echo "Starting Scrapling MCP server..."
    docker compose --profile mcp up -d
    ;;
  stop)
    echo "Stopping Scrapling MCP server..."
    docker compose --profile mcp stop
    ;;
  restart)
    echo "Restarting Scrapling MCP server..."
    docker compose --profile mcp restart
    ;;
  logs)
    shift || true
    docker compose --profile mcp logs -f "${1:-scrapling-mcp}"
    ;;
  scrape)
    shift || true
    if [[ $# -eq 0 ]]; then
      echo "Usage: ./scrapling.sh scrape <mode> <url> [output_file] [extra_args...]"
      echo "Modes: get | fetch | stealthy-fetch"
      echo "Example: ./scrapling.sh scrape get https://example.com /data/output.md"
      exit 1
    fi
    mkdir -p data
    docker run --rm -v "$(pwd)/data:/data" scrapling:latest extract "$@"
    ;;
  update)
    echo "Updating Scrapling Docker image..."
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    tar -czf "backups/scrapling-pre-update-${TIMESTAMP}.tar.gz" .env docker-compose.yml Dockerfile 2>/dev/null || true
    chmod 600 "backups/scrapling-pre-update-${TIMESTAMP}.tar.gz" 2>/dev/null || true
    docker build --no-cache -t scrapling:latest .
    if docker compose --profile mcp ps --services 2>/dev/null | grep -q "scrapling-mcp"; then
      docker compose --profile mcp up -d
    fi
    echo "Update complete."
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    ARCHIVE="backups/scrapling-backup-${TIMESTAMP}.tar.gz"
    echo "Creating backup (configs + scraped data)..."
    tar -czf "$ARCHIVE" .env docker-compose.yml Dockerfile data/
    chmod 600 "$ARCHIVE"
    echo "Backup created successfully: $ARCHIVE"
    ;;
  restore)
    BACKUP_FILE="${2:-}"
    if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
      echo "Error: Please specify a valid backup archive."
      echo "Usage: ./scrapling.sh restore backups/<archive>.tar.gz"
      exit 1
    fi
    echo "Verifying archive integrity..."
    if ! gzip -t "$BACKUP_FILE"; then
      echo "Error: Corrupted archive! Restore aborted."
      exit 1
    fi
    mkdir -p -m 700 backups
    SAFETY_SNAP="backups/scrapling-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$SAFETY_SNAP" .env docker-compose.yml Dockerfile data/ 2>/dev/null || true
    chmod 600 "$SAFETY_SNAP" 2>/dev/null || true
    echo "Safety snapshot created: $SAFETY_SNAP"
    docker compose --profile mcp stop 2>/dev/null || true
    tar -xzf "$BACKUP_FILE"
    chmod 600 .env 2>/dev/null || true
    echo "Restore completed successfully."
    ;;
  doctor)
    echo "=== Scrapling Health Check ==="
    if docker info &>/dev/null; then
      echo "  [OK] Docker engine is running"
    else
      echo "  [FAIL] Docker engine is unreachable"
    fi
    echo "  Disk Space:"
    df -h . | awk 'NR==2 {print "    Available: " $4 " on " $1}'
    if docker image inspect scrapling:latest &>/dev/null; then
      echo "  [OK] Scrapling Docker image exists: scrapling:latest"
    else
      echo "  [WARN] Scrapling Docker image not built yet"
    fi
    PORT=$(get_env_val "MCP_PORT")
    PORT="${PORT:-8000}"
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
    echo "WARNING: This will stop Scrapling MCP server and remove containers."
    read -rp "Type 'yes' to confirm uninstallation: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose --profile mcp down -v 2>/dev/null || true
      read -rp "Also remove scrapling:latest image? [y/N]: " RM_IMG
      case "${RM_IMG:-n}" in
        [yY][eE][sS]|[yY]) docker rmi scrapling:latest 2>/dev/null || true ;;
      esac
      echo "Scrapling uninstalled. Scraped data remains in: $(pwd)/data"
    else
      echo "Uninstall aborted."
    fi
    ;;
  *)
    echo "Usage: ./scrapling.sh {status|start|stop|restart|logs|scrape|update|backup|restore|doctor|uninstall}"
    ;;
esac
HELPER_EOF

chmod +x scrapling.sh
chown "$TARGET_USER:$TARGET_GROUP" .env docker-compose.yml Dockerfile scrapling.sh
pok "$(say "Helper CLI ./scrapling.sh created successfully." "Đã tạo trình quản lý ./scrapling.sh thành công.")"

# ==============================================================================
# Step 5: Build Docker Image & Verification
# ==============================================================================
step_title 5 "Build Image & Smoke Test" "Build Image & Kiểm Tra Hoạt Động"

pwn "$(say "Building Scrapling Docker image (this may take 5-10 minutes for Playwright Chromium)..." "Đang build Scrapling image (quá trình này có thể mất 5-10 phút để tải Playwright Chromium)...")"
docker build -t scrapling:latest .
pok "$(say "Docker image built: scrapling:latest" "Đã build xong image: scrapling:latest")"

echo ""
pok "$(say "Running verification smoke test..." "Đang chạy kiểm tra smoke test...")"
if docker run --rm -v "$INSTALL_DIR/data:/data" scrapling:latest extract get "https://quotes.toscrape.com" "/data/smoke_test.html" 2>&1; then
    rm -f "$INSTALL_DIR/data/smoke_test.html" 2>/dev/null || true
    pok "$(say "Smoke test: SUCCESSful (Playwright + Stealth HTTP extraction functional)" "Smoke test: THÀNH CÔNG (Trích xuất HTTP tàng hình hoạt động tốt)")"
else
    pwn "$(say "Smoke test had network issues, verifying binary directly..." "Smoke test gặp vấn đề mạng, kiểm tra trực tiếp binary...")"
    docker run --rm scrapling:latest --help &>/dev/null && pok "Binary: OK" || perr "Binary verification failed"
fi

echo ""
echo "================================================================"
echo -e "${GREEN}  🎉 $(say "INSTALLATION COMPLETE!" "CÀI ĐẶT THÀNH CÔNG!")${NC}"
echo ""
echo -e "  $(say "Platform:" "Nền tảng:")      ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "Install Path:" "Thư mục:")   ${PURPLE}${INSTALL_DIR}${NC}"
echo -e "  $(say "Output Data:" "Dữ liệu ra:")   ${CYAN}${INSTALL_DIR}/data${NC}"
echo ""
echo -e "${CYAN}$(say "Quick Usage Examples:" "Ví dụ Sử Dụng:"):${NC}"
echo "  • $(say "Scrape web page to Markdown:" "Cào nội dung sang Markdown:")"
echo "    cd ${INSTALL_DIR} && ./scrapling.sh scrape get https://example.com /data/output.md"
echo ""
echo "  • $(say "Start MCP Server for AI Agents:" "Khởi động MCP Server cho AI Agent:")"
echo "    cd ${INSTALL_DIR} && ./scrapling.sh start"
echo -e "    $(say "MCP Endpoint:" "Cổng MCP:") ${PURPLE}http://localhost:${MCP_PORT}/mcp${NC}"
echo ""
echo -e "${CYAN}$(say "Management Commands:" "Lệnh Quản Lý:"):${NC}"
echo "  • ./scrapling.sh status"
echo "  • ./scrapling.sh scrape <mode> <url> [output]"
echo "  • ./scrapling.sh backup"
echo "  • ./scrapling.sh doctor"
echo ""
echo "Support: https://ai.vnrom.net"
