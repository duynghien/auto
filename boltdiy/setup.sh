#!/usr/bin/env bash

# ==============================================================================
# Bolt.diy Standalone Installer (Gen 4 Standard)
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
echo "         Bolt.diy Standalone Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo -e "  $(say "Self-hosted AI coding assistant in your browser" "Trợ lý lập trình AI tự lưu trữ trên trình duyệt")"
echo ""

# ==============================================================================
# Step 1: Preflight & Dependencies
# ==============================================================================
step_title 1 "Preflight Checks & Dependencies" "Kiểm tra hệ thống & Cài đặt phụ thuộc"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &>/dev/null; then
        perr "$(say "Docker is not installed. Please install OrbStack (https://orbstack.dev) or Docker Desktop." "Docker chưa được cài đặt. Vui lòng cài OrbStack hoặc Docker Desktop.")"
    fi
    pok "Docker: OK"
    if ! docker compose version &>/dev/null; then
        perr "$(say "Docker Compose plugin is missing." "Thiếu Docker Compose plugin.")"
    fi
    pok "Docker Compose: OK"
else
    # Linux: Auto-install Docker if missing
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

    # Install build tools needed for git clone / submodules
    sudo apt-get install -y -qq build-essential git curl 2>/dev/null || true
    pok "Build dependencies: OK"

    # RAM & Swap Preflight Guard (LXC/OpenVZ compatible)
    if command -v free &>/dev/null; then
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
        TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
        pok "RAM: ${TOTAL_RAM}MB | Swap: ${TOTAL_SWAP}MB"

        if [[ "$TOTAL_RAM" -lt 4000 && "$TOTAL_SWAP" -lt 2000 ]]; then
            pwn "$(say "Low memory detected (<4GB RAM, <2GB Swap). Vite/Remix build requires swap to prevent OOM kills." "Phát hiện RAM thấp (<4GB). Quá trình build Vite/Remix cần Swap để tránh bị OOM kill.")"
            read -rp "$(say "Configure 4GB Swapfile now? [Y/n]: " "Cấu hình 4GB Swapfile ngay bây giờ? [Y/n]: ")" CREATE_SWAP || true
            case "${CREATE_SWAP:-y}" in
                [yY][eE][sS]|[yY]|"")
                    FREE_DISK_MB=$(df -Pm / | awk 'NR==2 {print $4}')
                    if [[ "$FREE_DISK_MB" -lt 8192 ]]; then
                        pwn "$(say "Insufficient free disk (<8GB free). Skipping swapfile creation." "Dung lượng ổ đĩa trống không đủ (<8GB). Bỏ qua tạo swapfile.")"
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

for tool in git curl; do
    if ! command -v "$tool" &>/dev/null; then
        perr "Missing required tool: $tool"
    fi
done

# ==============================================================================
# Step 2: Network Mode & Port Conflict Resolution
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

DEFAULT_PORT=5173
PORT="$DEFAULT_PORT"

if check_port "$PORT"; then
    pwn "$(say "Port $PORT is currently occupied!" "Cổng $PORT hiện đang bị chiếm dụng!")"
    read -rp "$(say "Enter alternative port (default: 5174): " "Nhập cổng thay thế (mặc định: 5174): ")" ALT_PORT || true
    PORT="${ALT_PORT:-5174}"
    while check_port "$PORT"; do
        pwn "$(say "Port $PORT is also occupied." "Cổng $PORT cũng đang bị chiếm.")"
        read -rp "$(say "Enter another port: " "Nhập cổng khác: ")" PORT || true
    done
fi
pok "$(say "Using port: $PORT" "Sử dụng cổng: $PORT")"

echo ""
echo -e "${BOLD}$(say "Select Network Access Mode:" "Chọn chế độ truy cập mạng:")${NC}"
echo "  1) Localhost (127.0.0.1:$PORT)"
echo "  2) Local LAN IP (Accessible from other devices on home/office network)"
echo "  3) Public Domain (Reverse Proxy / Cloudflare Tunnel / VPS Domain)"
read -rp "$(say "Choice [1-3] (default: 1): " "Lựa chọn [1-3] (mặc định: 1): ")" NET_MODE_CHOICE || true

case "${NET_MODE_CHOICE:-1}" in
    2)
        LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ipconfig getifaddr en0 2>/dev/null || echo "127.0.0.1")
        APP_URL="http://${LAN_IP}:${PORT}"
        ;;
    3)
        read -rp "$(say "Enter your public domain (e.g. boltdiy.example.com): " "Nhập domain công khai (VD: boltdiy.example.com): ")" USER_DOMAIN || true
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
# Step 3: Install Directory & Source Repository
# ==============================================================================
step_title 3 "Install Directory & Source Setup" "Thiết lập Thư mục & Mã nguồn"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
INSTALL_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/boltdiy"

mkdir -p "$INSTALL_DIR"
chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory: $INSTALL_DIR" "Thư mục cài đặt: $INSTALL_DIR")"

# Clone upstream Bolt.diy source code
if [ ! -d "bolt.diy-source" ]; then
    pwn "$(say "Cloning upstream bolt.diy source code..." "Đang sao chép mã nguồn bolt.diy từ GitHub...")"
    git clone https://github.com/stackblitz-labs/bolt.diy.git bolt.diy-source
    pok "$(say "bolt.diy source: cloned" "Mã nguồn bolt.diy: đã tải về")"
else
    pok "$(say "bolt.diy source: already exists" "Mã nguồn bolt.diy: đã tồn tại")"
    git -C bolt.diy-source pull --ff-only 2>/dev/null || true
fi

# ==============================================================================
# Step 4: Authoritative Inline File Generation
# ==============================================================================
step_title 4 "Authoritative Configuration Generation" "Sinh Cấu hình Độc lập Tự chứa"

# Generate Dockerfile
cat << 'DOCKERFILE_EOF' > Dockerfile
# Dockerfile.boltdiy
# Custom Dockerfile for bolt.diy self-hosted deployment
# Keeps wrangler available at runtime (needed for dockerstart command)

# ---- build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /app

ENV HUSKY=0
ENV CI=true

RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

RUN apt-get update && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

ARG VITE_PUBLIC_APP_URL
ENV VITE_PUBLIC_APP_URL=${VITE_PUBLIC_APP_URL}

# Install all deps (including wrangler)
COPY bolt.diy-source/package.json bolt.diy-source/pnpm-lock.yaml* ./
RUN pnpm fetch

COPY bolt.diy-source/ .
RUN pnpm install --offline --frozen-lockfile

# Build the Remix/Cloudflare Pages app
RUN NODE_OPTIONS=--max-old-space-size=3072 pnpm run build

# ---- production runtime (keeps all deps so wrangler is available) ----
FROM build AS boltdiy-production
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5173
ENV HOST=0.0.0.0

ARG VITE_LOG_LEVEL=debug
ARG DEFAULT_NUM_CTX

ENV WRANGLER_SEND_METRICS=false \
    VITE_LOG_LEVEL=${VITE_LOG_LEVEL} \
    DEFAULT_NUM_CTX=${DEFAULT_NUM_CTX} \
    RUNNING_IN_DOCKER=true

RUN mkdir -p /root/.config/.wrangler && \
    echo '{"enabled":false}' > /root/.config/.wrangler/metrics.json

RUN chmod +x /app/bindings.sh

EXPOSE 5173

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=10 \
    CMD curl -fsS http://localhost:5173/ || exit 1

CMD ["pnpm", "run", "dockerstart"]
DOCKERFILE_EOF

# Generate docker-compose.yml
cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  boltdiy:
    image: bolt-ai:boltdiy
    build:
      context: .
      dockerfile: Dockerfile
      target: boltdiy-production
    container_name: boltdiy
    restart: unless-stopped
    ports:
      - "${PORT:-5173}:5173"
    environment:
      - NODE_ENV=production
      - RUNNING_IN_DOCKER=true
      - PORT=5173
      - VITE_LOG_LEVEL=${VITE_LOG_LEVEL:-debug}
      - DEFAULT_NUM_CTX=${DEFAULT_NUM_CTX:-32768}
      # AI Providers — add API keys in .env
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - GROQ_API_KEY=${GROQ_API_KEY:-}
      - GOOGLE_GENERATIVE_AI_API_KEY=${GOOGLE_GENERATIVE_AI_API_KEY:-}
      - OPEN_ROUTER_API_KEY=${OPEN_ROUTER_API_KEY:-}
      - XAI_API_KEY=${XAI_API_KEY:-}
      - TOGETHER_API_KEY=${TOGETHER_API_KEY:-}
      - TOGETHER_API_BASE_URL=${TOGETHER_API_BASE_URL:-}
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
      - MISTRAL_API_KEY=${MISTRAL_API_KEY:-}
      - PERPLEXITY_API_KEY=${PERPLEXITY_API_KEY:-}
      - FIREWORKS_API_KEY=${FIREWORKS_API_KEY:-}
      - COHERE_API_KEY=${COHERE_API_KEY:-}
      - HuggingFace_API_KEY=${HuggingFace_API_KEY:-}
      - HYPERBOLIC_API_KEY=${HYPERBOLIC_API_KEY:-}
      - HYPERBOLIC_API_BASE_URL=${HYPERBOLIC_API_BASE_URL:-https://api.hyperbolic.xyz/v1/chat/completions}
      - MOONSHOT_API_KEY=${MOONSHOT_API_KEY:-}
      - ZAI_API_KEY=${ZAI_API_KEY:-}
      - CEREBRAS_API_KEY=${CEREBRAS_API_KEY:-}
      - GITHUB_API_KEY=${GITHUB_API_KEY:-}
      # Ollama (local models)
      - OLLAMA_API_BASE_URL=${OLLAMA_API_BASE_URL:-http://host.docker.internal:11434}
      # OpenAI-compatible providers
      - OPENAI_LIKE_API_BASE_URL=${OPENAI_LIKE_API_BASE_URL:-}
      - OPENAI_LIKE_API_KEY=${OPENAI_LIKE_API_KEY:-}
      # LM Studio
      - LMSTUDIO_API_BASE_URL=${LMSTUDIO_API_BASE_URL:-http://host.docker.internal:1234}
      # AWS Bedrock
      - AWS_BEDROCK_CONFIG=${AWS_BEDROCK_CONFIG:-}
      # Git providers (optional)
      - VITE_GITHUB_ACCESS_TOKEN=${VITE_GITHUB_ACCESS_TOKEN:-}
      - VITE_GITHUB_TOKEN_TYPE=${VITE_GITHUB_TOKEN_TYPE:-classic}
      - VITE_GITLAB_ACCESS_TOKEN=${VITE_GITLAB_ACCESS_TOKEN:-}
      - VITE_GITLAB_URL=${VITE_GITLAB_URL:-https://gitlab.com}
      - VITE_VERCEL_ACCESS_TOKEN=${VITE_VERCEL_ACCESS_TOKEN:-}
      - VITE_NETLIFY_ACCESS_TOKEN=${VITE_NETLIFY_ACCESS_TOKEN:-}
      - VITE_SUPABASE_URL=${VITE_SUPABASE_URL:-}
      - VITE_SUPABASE_ANON_KEY=${VITE_SUPABASE_ANON_KEY:-}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: pnpm run dockerstart
COMPOSE_EOF

# Sync sibling files in repo when executed from cloned repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -d "$SCRIPT_DIR" ]]; then
    cp -f "$INSTALL_DIR/Dockerfile" "$SCRIPT_DIR/Dockerfile" 2>/dev/null || true
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
fi
pok "$(say "Dockerfile and docker-compose.yml generated." "Đã sinh Dockerfile và docker-compose.yml.")"

# Preserve existing .env secrets idempotently
OLD_ANTHROPIC=""
OLD_OPENAI=""
OLD_GEMINI=""
OLD_OLLAMA="http://host.docker.internal:11434"

if [ -f .env ]; then
    pok "$(say "Existing .env detected, preserving configured secrets." "Phát hiện file .env cũ, giữ nguyên cấu hình đã cài.")"
    OLD_ANTHROPIC=$(grep -E '^ANTHROPIC_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_OPENAI=$(grep -E '^OPENAI_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_GEMINI=$(grep -E '^GOOGLE_GENERATIVE_AI_API_KEY=' .env 2>/dev/null | cut -d= -f2- || true)
    OLD_OLLAMA=$(grep -E '^OLLAMA_API_BASE_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://host.docker.internal:11434")
fi

cat << EOF > .env
PORT=${PORT}
NODE_ENV=production
VITE_LOG_LEVEL=debug
DEFAULT_NUM_CTX=32768
OLLAMA_API_BASE_URL=${OLD_OLLAMA}
ANTHROPIC_API_KEY=${OLD_ANTHROPIC}
OPENAI_API_KEY=${OLD_OPENAI}
GOOGLE_GENERATIVE_AI_API_KEY=${OLD_GEMINI}
EOF

chmod 600 .env
pok "$(say "Environment file saved (.env, chmod 600)." "Đã lưu cấu hình môi trường (.env, chmod 600).")"

# ==============================================================================
# Step 5: Helper Script Generation (boltdiy.sh)
# ==============================================================================
step_title 5 "Helper CLI Generation" "Tạo Trình Quản Lý CLI (boltdiy.sh)"

cat << 'HELPER_EOF' > boltdiy.sh
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
    echo "=== Bolt.diy Stack Status ==="
    docker compose ps
    PORT=$(get_env_val "PORT")
    echo ""
    echo "Active URL: http://localhost:${PORT:-5173}"
    ;;
  start)
    echo "Starting Bolt.diy..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping Bolt.diy..."
    docker compose stop
    ;;
  restart)
    echo "Restarting Bolt.diy..."
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${1:-boltdiy}"
    ;;
  update)
    echo "Updating Bolt.diy..."
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    tar -czf "backups/boltdiy-pre-update-${TIMESTAMP}.tar.gz" .env docker-compose.yml Dockerfile 2>/dev/null || true
    chmod 600 "backups/boltdiy-pre-update-${TIMESTAMP}.tar.gz" 2>/dev/null || true
    if [[ -d "bolt.diy-source" ]]; then
      git -C bolt.diy-source pull --ff-only || true
    fi
    docker compose build --pull
    docker compose up -d
    echo "Update complete."
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    ARCHIVE="backups/boltdiy-backup-${TIMESTAMP}.tar.gz"
    tar -czf "$ARCHIVE" .env docker-compose.yml Dockerfile
    chmod 600 "$ARCHIVE"
    echo "Backup created successfully: $ARCHIVE"
    ;;
  restore)
    BACKUP_FILE="${2:-}"
    if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
      echo "Error: Please specify a valid backup archive."
      echo "Usage: ./boltdiy.sh restore backups/<archive>.tar.gz"
      exit 1
    fi
    echo "Verifying archive integrity..."
    if ! gzip -t "$BACKUP_FILE"; then
      echo "Error: Corrupted archive! Restore aborted."
      exit 1
    fi
    mkdir -p -m 700 backups
    SAFETY_SNAP="backups/boltdiy-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$SAFETY_SNAP" .env docker-compose.yml Dockerfile 2>/dev/null || true
    chmod 600 "$SAFETY_SNAP" 2>/dev/null || true
    echo "Safety snapshot created: $SAFETY_SNAP"
    tar -xzf "$BACKUP_FILE"
    chmod 600 .env 2>/dev/null || true
    docker compose up -d
    echo "Restore completed successfully."
    ;;
  doctor)
    echo "=== Bolt.diy Health Check ==="
    if docker info &>/dev/null; then
      echo "  [OK] Docker engine is running"
    else
      echo "  [FAIL] Docker engine is unreachable"
    fi
    echo "  Disk Space:"
    df -h . | awk 'NR==2 {print "    Available: " $4 " on " $1}'
    PORT=$(get_env_val "PORT")
    PORT="${PORT:-5173}"
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
    echo "WARNING: This will stop Bolt.diy and remove container resources."
    read -rp "Type 'yes' to confirm uninstallation: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v --rmi local 2>/dev/null || true
      echo "Bolt.diy stack uninstalled."
      echo "Source files and configurations remain in: $(pwd)"
    else
      echo "Uninstall aborted."
    fi
    ;;
  *)
    echo "Usage: ./boltdiy.sh {status|start|stop|restart|logs|update|backup|restore|doctor|uninstall}"
    ;;
esac
HELPER_EOF

chmod +x boltdiy.sh
chown "$TARGET_USER:$TARGET_GROUP" .env docker-compose.yml Dockerfile boltdiy.sh
pok "$(say "Helper CLI ./boltdiy.sh created successfully." "Đã tạo trình quản lý ./boltdiy.sh thành công.")"

# ==============================================================================
# Step 6: Build, Start & Health Verification
# ==============================================================================
step_title 6 "Build & Start Services" "Build & Khởi chạy Dịch vụ"

pwn "$(say "Building Bolt.diy image (this may take several minutes)..." "Đang build image Bolt.diy (quá trình này có thể mất vài phút)...")"
docker compose up -d --build

echo ""
pok "$(say "Waiting for Bolt.diy container to initialize..." "Đang chờ container khởi động...")"
sleep 5

ALL_OK=true
if curl -sf "http://localhost:${PORT}" &>/dev/null; then
    pok "$(say "Bolt.diy UI: Healthy and reachable!" "Giao diện Bolt.diy: Hoạt động bình thường!")"
else
    pwn "$(say "Bolt.diy container is starting (it may take 15-30s to finish initial compile)." "Bolt.diy đang khởi động (có thể mất 15-30 giây để hoàn tất biên dịch ban đầu).")"
fi

echo ""
echo "================================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 $(say "INSTALLATION COMPLETE!" "CÀI ĐẶT THÀNH CÔNG!")${NC}"
else
    echo -e "${YELLOW}  ⚠️  $(say "INSTALLATION DONE (Service still starting)" "HOÀN TẤT (Dịch vụ đang khởi động)")${NC}"
fi
echo ""
echo -e "  $(say "Platform:" "Nền tảng:")      ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "Bolt.diy URL:" "Địa chỉ truy cập:")  ${PURPLE}${APP_URL}${NC}"
echo -e "  $(say "Config Path:" "Đường dẫn file:")   ${CYAN}${INSTALL_DIR}/.env${NC}"
echo ""
echo -e "${YELLOW}⚠️  $(say "IMPORTANT:" "QUAN TRỌNG:")${NC}"
echo "  • $(say "Add your AI provider API keys in .env to begin using bolt.diy" "Thêm API key nhà cung cấp AI vào file .env để bắt đầu sử dụng")"
echo "  • $(say "Manage stack with: cd ${INSTALL_DIR} && ./boltdiy.sh" "Quản lý bằng lệnh: cd ${INSTALL_DIR} && ./boltdiy.sh")"
echo ""
echo -e "${CYAN}$(say "Management Commands:" "Lệnh Quản Lý:"):${NC}"
echo "  • ./boltdiy.sh status"
echo "  • ./boltdiy.sh logs"
echo "  • ./boltdiy.sh restart"
echo "  • ./boltdiy.sh doctor"
echo ""
echo "Support: https://ai.vnrom.net"
