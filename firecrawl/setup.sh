#!/usr/bin/env bash
# ==============================================================================
# FireCrawl Standalone Setup (Gen 4 Standard)
# Supports: macOS (Apple Silicon), Raspberry Pi (ARM64), Linux VPS (amd64/arm64)
# Author: duynghien (vnROM.net)
# ==============================================================================

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if command -v docker &>/dev/null && [ -f docker-compose.yml ]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")"
if command -v getent &>/dev/null; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/firecrawl}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
perr() { echo -e "${RED}  ✗${NC} $1"; }

# Language Selection (EN/VI)
APP_LANG="${APP_LANG:-}"
if [[ -z "$APP_LANG" ]]; then
    echo ""
    echo -e "${BOLD}Select Language / Chọn ngôn ngữ:${NC}"
    echo "  1) Tiếng Việt (mặc định)"
    echo "  2) English"
    read -rp "Choice [1-2] (default: 1): " LANG_CHOICE || true
    case "${LANG_CHOICE:-1}" in
        2|en|EN) APP_LANG="en" ;;
        *) APP_LANG="vi" ;;
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
    echo ""
    echo -e "${CYAN}[$num] $(say "$en" "$vi")${NC}"
}

# Platform Detection
OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    PLATFORM_LABEL="macOS ($ARCH)"
elif [[ "$OS" == "Linux" ]]; then
    if grep -qi 'raspberry\|raspbian' /proc/device-tree/model 2>/dev/null || \
       grep -qi 'raspberry' /etc/os-release 2>/dev/null; then
        PLATFORM="pi"
        PLATFORM_LABEL="Raspberry Pi ($ARCH)"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        PLATFORM="vps-arm64"
        PLATFORM_LABEL="Linux ARM64"
    else
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux AMD64 ($ARCH)"
    fi
else
    perr "Unsupported OS: $OS"
    exit 1
fi

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
echo "          FireCrawl Standalone Setup — Gen 4 Standard"
echo -e "                 Platform: ${PLATFORM_LABEL}${NC}"
echo "================================================================"
echo ""

# Step 1: Preflight & Memory Check
step_title "1/6" "System Preflight & Hardware Check" "Kiểm tra hệ thống & phần cứng"

if [[ "$OS" == "Linux" ]]; then
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    echo -e "  • $(say 'RAM:' 'Bộ nhớ RAM:'): ${TOTAL_MEM_MB}MB | $(say 'Swap:' 'Bộ nhớ Swap:'): ${TOTAL_SWAP_MB}MB"
    
    if [ "$TOTAL_MEM_MB" -lt 4000 ] && [ "$TOTAL_SWAP_MB" -lt 2000 ]; then
        pwn "$(say "Low memory detected (<4GB RAM). Building and running FireCrawl requires adequate swap." \
                   "Phát hiện RAM thấp (<4GB RAM). Quá trình build và chạy FireCrawl cần bộ nhớ Swap đủ lớn.")"
        read -rp "  $(say 'Would you like to allocate 4GB Swap? [Y/n]: ' 'Bạn có muốn tự động tạo 4GB Swap không? [Y/n]: ') " SWAP_CHOICE || true
        case "${SWAP_CHOICE:-y}" in
            y|Y|yes|YES)
                AVAILABLE_DISK_KB=$(df -P / | awk 'NR==2 {print $4}')
                if [ "$AVAILABLE_DISK_KB" -gt 6000000 ]; then
                    echo "  → $(say 'Creating 4GB swapfile...' 'Đang tạo 4GB swapfile...')"
                    sudo fallocate -l 4G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
                    sudo chmod 600 /swapfile
                    sudo mkswap /swapfile
                    if ! sudo swapon /swapfile 2>/dev/null; then
                        pwn "$(say 'swapon restricted on this virtual environment (LXC/OpenVZ). Skipping swap.' \
                                   'swapon bị giới hạn trên môi trường ảo hóa này (LXC/OpenVZ). Bỏ qua tạo swap.')"
                        sudo rm -f /swapfile
                    else
                        grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
                        pok "$(say '4GB Swap successfully enabled.' 'Đã kích hoạt 4GB Swap thành công.')"
                    fi
                else
                    pwn "$(say 'Insufficient disk space for 4GB swap. Skipping.' 'Không đủ dung lượng ổ cứng để tạo 4GB swap. Bỏ qua.')"
                fi
                ;;
            *)
                echo "  $(say 'Skipped swap creation.' 'Bỏ qua tạo swap.')"
                ;;
        esac
    fi
fi

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &> /dev/null; then
        perr "$(say 'Docker is not installed on macOS.' 'Chưa cài đặt Docker trên macOS.')"
        echo "  OrbStack (recommended): https://orbstack.dev"
        exit 1
    fi
    pok "Docker: OK"
else
    if ! command -v docker &> /dev/null; then
        pwn "$(say 'Docker not found, installing automatically...' 'Docker chưa cài đặt, đang tự động cài...')"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$TARGET_USER" 2>/dev/null || true
        pok "Docker: $(say 'installed' 'đã cài đặt')"
    else
        pok "Docker: OK"
    fi
    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"
fi

for c in openssl curl git; do
    if ! command -v "$c" &>/dev/null; then
        if [[ "$OS" == "Linux" ]]; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$c" 2>/dev/null || true
        fi
    fi
done

# Step 2: Directory Setup
step_title "2/6" "Installation Directory & Source Code" "Thư mục cài đặt & mã nguồn"
echo -e "  • Target directory: ${PURPLE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p data backups

if [ ! -d "firecrawl-source" ]; then
    echo "  → $(say 'Cloning FireCrawl source code repository...' 'Đang clone mã nguồn FireCrawl...')"
    git clone --depth=1 https://github.com/mendableai/firecrawl.git firecrawl-source
    pok "$(say 'FireCrawl source cloned.' 'Đã clone source code FireCrawl.')"
else
    pok "$(say 'FireCrawl source already exists.' 'Mã nguồn FireCrawl đã có sẵn.')"
fi

# Step 3: Port Conflict Check
step_title "3/6" "Port Configuration" "Kiểm tra cổng dịch vụ"

check_port() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -i ":$port" -sTCP:LISTEN -Pn &>/dev/null
    elif command -v ss &>/dev/null; then
        ss -ltn "sport = :$port" | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -ltn 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

PORT_VAL="${PORT:-3002}"
if check_port "$PORT_VAL"; then
    pwn "$(say "Port $PORT_VAL is already in use!" "Cổng $PORT_VAL hiện đang có tiến trình sử dụng!")"
    ALT_PORT=3003
    while check_port "$ALT_PORT"; do
        ALT_PORT=$((ALT_PORT + 1))
    done
    read -rp "  $(say "Enter alternative port (default: $ALT_PORT): " "Nhập cổng khác (mặc định: $ALT_PORT): ") " USER_PORT || true
    PORT_VAL="${USER_PORT:-$ALT_PORT}"
fi
pok "$(say "Selected port for FireCrawl: $PORT_VAL" "Cổng hoạt động FireCrawl: $PORT_VAL")"

# Step 4: Authoritative File Generation
step_title "4/6" "Authoritative Files Generation" "Khởi tạo file cấu hình & script chuẩn"

cat > "$INSTALL_DIR/docker-compose.yml" << 'COMPOSEOF'
name: firecrawl

x-common-service: &common-service
  build: ./firecrawl-source/apps/api
  restart: unless-stopped
  networks:
    - backend
  extra_hosts:
    - "host.docker.internal:host-gateway"
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
      compress: "true"

x-common-env: &common-env
  REDIS_URL: redis://redis:6379
  REDIS_RATE_LIMIT_URL: redis://redis:6379
  PLAYWRIGHT_MICROSERVICE_URL: http://playwright-service:3000/scrape
  POSTGRES_USER: ${POSTGRES_USER:-postgres}
  POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-postgres_pass}"
  POSTGRES_DB: ${POSTGRES_DB:-postgres}
  POSTGRES_HOST: nuq-postgres
  POSTGRES_PORT: 5432
  USE_DB_AUTHENTICATION: ${USE_DB_AUTHENTICATION:-false}
  NUM_WORKERS_PER_QUEUE: ${NUM_WORKERS_PER_QUEUE:-4}
  CRAWL_CONCURRENT_REQUESTS: ${CRAWL_CONCURRENT_REQUESTS:-5}
  MAX_CONCURRENT_JOBS: ${MAX_CONCURRENT_JOBS:-3}
  BROWSER_POOL_SIZE: ${BROWSER_POOL_SIZE:-3}
  OPENAI_API_KEY: ${OPENAI_API_KEY:-}
  OPENAI_BASE_URL: ${OPENAI_BASE_URL:-}
  MODEL_NAME: ${MODEL_NAME:-}
  OLLAMA_BASE_URL: ${OLLAMA_BASE_URL:-}
  BULL_AUTH_KEY: ${BULL_AUTH_KEY:-changeme}
  NUQ_RABBITMQ_URL: amqp://rabbitmq:5672
  WORKER_PORT: ${WORKER_PORT:-3005}
  EXTRACT_WORKER_PORT: ${EXTRACT_WORKER_PORT:-3004}
  LOGGING_LEVEL: ${LOGGING_LEVEL:-INFO}
  PROXY_SERVER: ${PROXY_SERVER:-}
  PROXY_USERNAME: ${PROXY_USERNAME:-}
  PROXY_PASSWORD: ${PROXY_PASSWORD:-}

services:
  playwright-service:
    build: ./firecrawl-source/apps/playwright-service-ts
    restart: unless-stopped
    environment:
      PORT: 3000
      PROXY_SERVER: ${PROXY_SERVER:-}
      PROXY_USERNAME: ${PROXY_USERNAME:-}
      PROXY_PASSWORD: ${PROXY_PASSWORD:-}
      MAX_CONCURRENT_PAGES: ${CRAWL_CONCURRENT_REQUESTS:-5}
    networks:
      - backend
    mem_limit: 2G
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"

  api:
    <<: *common-service
    environment:
      <<: *common-env
      HOST: "0.0.0.0"
      PORT: ${PORT:-3002}
      ENV: local
    depends_on:
      redis:
        condition: service_started
      playwright-service:
        condition: service_started
      rabbitmq:
        condition: service_healthy
      nuq-postgres:
        condition: service_healthy
    ports:
      - "${PORT:-3002}:${PORT:-3002}"
    command: node dist/src/harness.js --start-docker
    mem_limit: 4G

  redis:
    image: redis:alpine
    restart: unless-stopped
    networks:
      - backend
    command: redis-server --bind 0.0.0.0
    volumes:
      - redis_data:/data
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
        compress: "true"

  rabbitmq:
    image: rabbitmq:3-management
    restart: unless-stopped
    networks:
      - backend
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "check_running"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "5m"
        max-file: "2"
        compress: "true"

  nuq-postgres:
    build: ./firecrawl-source/apps/nuq-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres_pass}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
    networks:
      - backend
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "psql -U postgres -d postgres -c 'SELECT 1 FROM nuq.queue_scrape LIMIT 1' > /dev/null 2>&1"]
      interval: 5s
      timeout: 10s
      retries: 30
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"

networks:
  backend:
    driver: bridge

volumes:
  redis_data:
  postgres_data:
COMPOSEOF

cat << 'FC_EOF' > "$INSTALL_DIR/fc.sh"
#!/usr/bin/env bash
# fc.sh - FireCrawl management helper (Gen 4 Standard)
# Usage: ./fc.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PORT=$(grep -E "^PORT=" .env 2>/dev/null | cut -d= -f2 || echo "3002")
CMD="${1:-help}"

case "$CMD" in
  start)
    echo -e "${GREEN}Starting FireCrawl...${NC}"
    docker compose up -d
    ;;
  stop)
    echo -e "${YELLOW}Stopping FireCrawl...${NC}"
    docker compose stop
    ;;
  restart)
    echo -e "${YELLOW}Restarting FireCrawl...${NC}"
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-api}"
    ;;
  status)
    echo -e "${CYAN}FireCrawl Container Status:${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}Health Diagnostics:${NC}"
    echo -n "  • FireCrawl API: "
    if curl -sf "http://localhost:${PORT}/v1/health" >/dev/null 2>&1; then
      echo -e "${GREEN}Healthy (OK)${NC}"
    else
      echo -e "${RED}Not responding${NC}"
    fi
    echo -n "  • Redis: "
    if docker exec "$(docker compose ps -q redis 2>/dev/null | head -1)" redis-cli ping &>/dev/null; then
      echo -e "${GREEN}Healthy (PONG)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    echo -n "  • PostgreSQL (nuq): "
    if docker exec "$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)" psql -U postgres -d postgres -c 'SELECT 1' &>/dev/null; then
      echo -e "${GREEN}Ready (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    ;;
  test)
    echo -e "${CYAN}Testing FireCrawl scrape...${NC}"
    curl -X POST "http://localhost:${PORT}/v1/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url": "https://example.com", "formats": ["markdown"]}' | head -n 30
    ;;
  update)
    echo -e "${YELLOW}Backing up .env...${NC}"
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Updating FireCrawl source & rebuilding...${NC}"
    if [ -d "firecrawl-source" ]; then
      git -C firecrawl-source pull || true
    fi
    docker compose pull redis rabbitmq 2>/dev/null || true
    docker compose up -d --build
    echo -e "${GREEN}Update complete!${NC}"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/firecrawl_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/firecrawl_cfg_$TIMESTAMP.tar.gz"

    echo -e "${GREEN}Dumping nuq-postgres database...${NC}"
    PG_CONTAINER="$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)"
    if [[ -n "$PG_CONTAINER" ]] && docker exec "$PG_CONTAINER" pg_dump -U postgres postgres | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo -e "  ${GREEN}✓ Database archived to: $DB_ARCHIVE (chmod 600)${NC}"
    else
      echo -e "  ${RED}✗ Database backup failed! Ensure nuq-postgres is running.${NC}"
    fi

    echo -e "${GREEN}Archiving configuration...${NC}"
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo -e "  ${GREEN}✓ Configuration archived to: $CFG_ARCHIVE (chmod 600)${NC}"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo -e "${RED}Usage: ./fc.sh restore <path-to-sql-gz-archive>${NC}"
      exit 1
    fi
    echo -e "${YELLOW}Verifying archive integrity...${NC}"
    gzip -t "$FILE"
    echo -e "${RED}WARNING: Restoring will overwrite existing nuq-postgres database!${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      PG_CONTAINER="$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)"
      gunzip -c "$FILE" | docker exec -i "$PG_CONTAINER" psql -U postgres -d postgres
      echo -e "${GREEN}✓ Database restore completed! Restarting API...${NC}"
      docker compose restart api
    else
      echo "Restore aborted."
    fi
    ;;
  doctor)
    echo -e "${BOLD}=== FireCrawl System Doctor ===${NC}"
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
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo -n "Port ${PORT} status: "
    if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
      echo -e "${GREEN}Listening${NC}"
    else
      echo -e "${YELLOW}Not listening${NC}"
    fi
    echo -n "API /v1/health endpoint: "
    if curl -sf "http://localhost:${PORT}/v1/health" >/dev/null 2>&1; then
      echo -e "${GREEN}Healthy${NC}"
    else
      echo -e "${RED}Not responding${NC}"
    fi
    ;;
  uninstall)
    echo -e "${RED}WARNING: This will completely remove FireCrawl containers, networks, and volumes.${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo -e "${GREEN}✓ FireCrawl containers and volumes removed.${NC}"
    else
      echo "Uninstall canceled."
    fi
    ;;
  help|*)
    echo -e "${BOLD}Usage:${NC} ./fc.sh {start|stop|restart|logs|status|test|update|backup|restore|doctor|uninstall}"
    echo ""
    echo "  start      — Start all containers"
    echo "  stop       — Stop all containers"
    echo "  restart    — Restart all containers"
    echo "  logs [svc] — Follow container logs (default: api)"
    echo "  status     — Show container status + health diagnostics"
    echo "  test       — Run test scrape against example.com"
    echo "  update     — Pull source and rebuild containers"
    echo "  backup     — Dump PostgreSQL and archive configuration"
    echo "  restore    — Restore database from backup archive"
    echo "  doctor     — Run system health diagnostics"
    echo "  uninstall  — Remove containers and data volumes"
    ;;
esac
FC_EOF
chmod +x "$INSTALL_DIR/fc.sh"

# Canonical symlinks
ln -sf fc.sh "$INSTALL_DIR/firecrawl.sh"
sudo ln -sf "$INSTALL_DIR/fc.sh" /usr/local/bin/fc 2>/dev/null || true
sudo ln -sf "$INSTALL_DIR/fc.sh" /usr/local/bin/firecrawl 2>/dev/null || true

# Synchronize back to repo if run from within repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -f "$SCRIPT_DIR/fc.sh" ]]; then
    cp -f "$INSTALL_DIR/fc.sh" "$SCRIPT_DIR/fc.sh" 2>/dev/null || true
    ln -sf fc.sh "$SCRIPT_DIR/firecrawl.sh" 2>/dev/null || true
fi
pok "$(say 'Authoritative configuration and helper CLI created.' 'Đã khởi tạo cấu hình và trình quản lý fc.sh.')"

# Step 5: Environment Setup (.env)
step_title "5/6" "Configuring Environment (.env)" "Thiết lập biến môi trường"

if [ ! -f .env ]; then
    BULL_AUTH_KEY=$(openssl rand -hex 16)
    POSTGRES_PASSWORD=$(openssl rand -hex 12)

    cat > .env << EOF
# ===== FireCrawl Self-hosted Configuration =====
PORT=${PORT_VAL}
HOST=0.0.0.0

# Disable DB authentication (no Supabase needed)
USE_DB_AUTHENTICATION=false

# Queue admin panel password
BULL_AUTH_KEY=${BULL_AUTH_KEY}

# PostgreSQL — uses default 'postgres' user/db (required by nuq.sql init scripts)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=postgres

# AI features (optional)
OPENAI_API_KEY=

# Performance tuning
NUM_WORKERS_PER_QUEUE=4
CRAWL_CONCURRENT_REQUESTS=5
MAX_CONCURRENT_JOBS=3
BROWSER_POOL_SIZE=3
LOGGING_LEVEL=INFO
EOF
    chmod 600 .env
    pok "$(say '.env initialized (chmod 600).' 'Đã tạo file .env bảo mật (chmod 600).')"
else
    chmod 600 .env
    pok "$(say 'Preserved existing .env (chmod 600).' 'Giữ nguyên file .env hiện có (chmod 600).')"
fi

# Step 6: Deploy & Service
step_title "6/6" "Deployment & Health Verification" "Triển khai & Kiểm tra dịch vụ"

if [[ -n "${TARGET_USER:-}" && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR" 2>/dev/null || true
fi

echo "  → $(say 'Building and launching FireCrawl containers...' 'Đang build và khởi động các container FireCrawl...')"
docker compose up -d --build

echo "  → $(say 'Waiting for FireCrawl API readiness...' 'Đang đợi FireCrawl API sẵn sàng...')"
for i in $(seq 1 40); do
    if curl -sf "http://localhost:${PORT_VAL}/v1/health" >/dev/null 2>&1; then
        pok "$(say 'FireCrawl API is healthy!' 'FireCrawl API đã sẵn sàng!')"
        break
    fi
    sleep 3
done

# Safe host-files-only ownership adjustment post-startup
find "$INSTALL_DIR" -maxdepth 1 -type f -exec chown "$TARGET_USER:$TARGET_GROUP" {} + 2>/dev/null || true

echo ""
echo "================================================================"
echo -e "${GREEN}${BOLD}  🎉 $(say 'FIRECRAWL SETUP COMPLETED SUCCESSFULLY!' 'CÀI ĐẶT FIRECRAWL HOÀN TẤT THÀNH CÔNG!')${NC}"
echo "================================================================"
echo -e "  • API Endpoint:    ${PURPLE}http://localhost:${PORT_VAL}${NC}"
echo -e "  • Health Check:    ${PURPLE}http://localhost:${PORT_VAL}/v1/health${NC}"
echo -e "  • Queue Admin:     ${PURPLE}http://localhost:${PORT_VAL}/admin/queues${NC}"
echo -e "  • Config file:     ${PURPLE}$INSTALL_DIR/.env${NC} (chmod 600)"
echo -e "  • Helper CLI:      ${PURPLE}fc${NC} (or firecrawl / ./fc.sh)"
echo "================================================================"
echo "$(say 'Quick management commands:' 'Các lệnh quản lý nhanh:'):"
echo "  • fc status"
echo "  • fc test"
echo "  • fc logs"
echo "  • fc backup"
echo "  • fc doctor"
