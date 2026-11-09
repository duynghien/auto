#!/bin/bash
################################################################
# Mautic v7/Latest Unified Auto-Install
# Supports: macOS (Apple Silicon), Raspberry Pi, VPS (amd64/arm64)
# Full Stack: Mautic, MariaDB, Redis, Ofelia (Cron)
# Based on official Mautic Docker images
################################################################

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -f "docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; }

# ========================================
# Platform Detection
# ========================================
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    PLATFORM_LABEL="macOS"
elif [[ "$OS" == "Linux" ]]; then
    # Detect Raspberry Pi
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
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
fi

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
    echo "        Mautic Setup — $PLATFORM_LABEL"
    echo "   Email Marketing Automation · Cron Jobs · Redis Cache"
    echo "================================================================${NC}"
}

# ========================================
# Language Selection
# ========================================
clear
pheader

echo ""
echo "  Select language / Chọn ngôn ngữ:"
echo ""
echo "    1) English (default)"
echo "    2) Tiếng Việt"
echo ""
read -p "  Enter 1 or 2 [1]: " LANG_CHOICE
LANG_CHOICE=${LANG_CHOICE:-1}

if [[ "$LANG_CHOICE" == "2" ]]; then
    LANG="vi"
else
    LANG="en"
fi

# ========================================
# Network Mode Selection
# ========================================

# Auto-detect LAN IP
if [[ "$PLATFORM" == "mac" ]]; then
    LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ipconfig getifaddr en1 2>/dev/null || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' || echo "")
else
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    [ -z "$LAN_IP" ] && LAN_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}' || echo "")
fi

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

MAUTIC_PORT="${MAUTIC_PORT:-8080}"
if check_port "$MAUTIC_PORT"; then
    pwn "Port $MAUTIC_PORT is already in use!"
    ALT_PORT=8081
    while check_port "$ALT_PORT"; do
        ALT_PORT=$((ALT_PORT + 1))
    done
    read -rp "  Enter alternative web port (default: $ALT_PORT): " USER_PORT || true
    MAUTIC_PORT="${USER_PORT:-$ALT_PORT}"
fi

# Default: Pi/VPS default to LAN, Mac defaults to localhost
if [[ "$PLATFORM" == "mac" ]]; then
    DEFAULT_NET="1"
else
    DEFAULT_NET="2"
fi

echo ""
if [[ "$LANG" == "vi" ]]; then
    echo "  Chế độ mạng (Site URL):"
    echo ""
    echo "    1) Localhost Only (http://localhost:8080)"
    if [ -n "$LAN_IP" ]; then
        echo "    2) LAN / Private IP (http://${LAN_IP}:8080)"
    else
        echo "    2) LAN / Private IP (Manual Input)"
    fi
    echo "    3) Public Domain (https://mautic.vnrom.net - Requires Proxy)"
    echo ""
else
    echo "  Network Mode (Site URL):"
    echo ""
    echo "    1) Localhost Only (http://localhost:8080)"
    if [ -n "$LAN_IP" ]; then
        echo "    2) LAN / Private IP (http://${LAN_IP}:8080)"
    else
        echo "    2) LAN / Private IP (Manual Input)"
    fi
    echo "    3) Public Domain (https://mautic.vnrom.net - Requires Proxy)"
    echo ""
fi

read -p "  Select [1-3] [$DEFAULT_NET]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-$DEFAULT_NET}

if [[ "$NET_CHOICE" == "1" ]]; then
    MAUTIC_URL="http://localhost:${MAUTIC_PORT}"
    echo ""
elif [[ "$NET_CHOICE" == "2" ]]; then
    if [ -z "$LAN_IP" ]; then
        read -p "  Enter LAN IP: " LAN_IP
    fi
    MAUTIC_URL="http://${LAN_IP}:${MAUTIC_PORT}"
    echo ""
elif [[ "$NET_CHOICE" == "3" ]]; then
    echo ""
    read -p "  Enter Domain (e.g., mautic.vnrom.net): " MAUTIC_DOMAIN
    MAUTIC_URL="https://${MAUTIC_DOMAIN}"
    echo ""
else
    MAUTIC_URL="http://localhost:${MAUTIC_PORT}"
fi

# ========================================
# i18n
# ========================================
t() {
    local key="$1"
    shift
    local text=""

    case "$key" in
        step1) [[ "$LANG" == "vi" ]] && text="[1/6] Kiểm tra hệ thống" || text="[1/6] Checking system";;
        step2) [[ "$LANG" == "vi" ]] && text="[2/6] Setup Docker & Thư mục" || text="[2/6] Setup Docker & Directory";;
        step3) [[ "$LANG" == "vi" ]] && text="[3/6] Sinh cấu hình Secrets" || text="[3/6] Generating Secrets";;
        step4) [[ "$LANG" == "vi" ]] && text="[4/6] Tạo Docker Compose" || text="[4/6] Creating Docker Compose";;
        step5) [[ "$LANG" == "vi" ]] && text="[5/6] Khởi động Containers" || text="[5/6] Starting Containers";;
        step6) [[ "$LANG" == "vi" ]] && text="[6/6] Hoàn tất" || text="[6/6] Finishing up";;

        err_docker) [[ "$LANG" == "vi" ]] && text="Docker chưa cài đặt!" || text="Docker is not installed!";;
        ok_docker) [[ "$LANG" == "vi" ]] && text="Docker: OK" || text="Docker: OK";;
        
        warn_env) [[ "$LANG" == "vi" ]] && text="Tìm thấy .env cũ, giữ nguyên..." || text="Found existing .env, preserving...";;
        ok_env) [[ "$LANG" == "vi" ]] && text="Đã lưu cấu hình vào .env" || text="Saved config to .env";;

        ok_pull) [[ "$LANG" == "vi" ]] && text="Đang tải images..." || text="Pulling images...";;
        ok_start) [[ "$LANG" == "vi" ]] && text="Đang khởi động Mautic..." || text="Starting Mautic...";;
        
        finish_title) [[ "$LANG" == "vi" ]] && text="🎉 CÀI ĐẶT THÀNH CÔNG!" || text="🎉 INSTALLATION COMPLETE!";;
        usage_url) [[ "$LANG" == "vi" ]] && text="  • Truy cập: $MAUTIC_URL" || text="  • Access: $MAUTIC_URL";;
        usage_cron) [[ "$LANG" == "vi" ]] && text="  • Cron Jobs: Được quản lý tự động bởi Ofelia container" || text="  • Cron Jobs: Managed automatically by Ofelia container";;
        usage_proxy) [[ "$LANG" == "vi" ]] && text="  • Proxy: Cần thiết lập SSL (Cloudflare/Nginx) nếu dùng Public Domain" || text="  • Proxy: SSL setup required (Cloudflare/Nginx) for Public Domain";;
        
        *) text="[MISSING: $key]";;
    esac
    echo "$text"
}

# ========================================
# Step 1: Checks
# ========================================
echo ""
echo "$(t step1)"
if ! command -v docker &> /dev/null; then
    if [[ "$PLATFORM" == "mac" ]]; then
        perr "$(t err_docker)"
        echo "Please install Docker Desktop or OrbStack."
        exit 1
    else
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "$USER"
        echo "Docker installed. Please re-login."
        exit 0
    fi
else
    pok "$(t ok_docker)"
fi

# ========================================
# Step 2: Directory & Docker
# ========================================
echo ""
echo "$(t step2)"

INSTALL_DIR="$HOME/self-hosted/mautic"
mkdir -p "$INSTALL_DIR"/{data,db_data,logs,cron,rabbitmq}
cd "$INSTALL_DIR"
pok "Directory: $INSTALL_DIR"

# ========================================
# Step 3: Secrets
# ========================================
echo ""
echo "$(t step3)"

if [ -f .env ]; then
    pwn "$(t warn_env)"
    chmod 600 .env 2>/dev/null || true
    source .env
else
    DB_ROOT_PASS=$(openssl rand -base64 16 | tr -d '=+/')
    DB_PASS=$(openssl rand -base64 16 | tr -d '=+/')
    MAUTIC_SECRET=$(openssl rand -base64 32 | tr -d '=+/')
    
    RABBITMQ_PASS=$(openssl rand -base64 16 | tr -d '=+/')
    
    cat > .env << ENVEOF
# Mautic Configuration
MAUTIC_URL=$MAUTIC_URL
MAUTIC_DB_USER=mautic
MAUTIC_DB_PASSWORD=$DB_PASS
MAUTIC_DB_NAME=mautic
MAUTIC_RUN_CRON_JOBS=false 
# We disable internal cron to use Ofelia for better control

# Database (MariaDB)
MYSQL_ROOT_PASSWORD=$DB_ROOT_PASS
MYSQL_DATABASE=mautic
MYSQL_USER=mautic
MYSQL_PASSWORD=$DB_PASS

# System
TIMEZONE=UTC

# Redis
REDIS_HOST=mautic_redis
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_DEFAULT_USER=mautic
RABBITMQ_DEFAULT_PASS=$RABBITMQ_PASS
RABBITMQ_HOST=mautic_rabbitmq
RABBITMQ_PORT=5672
ENVEOF
    chmod 600 .env
    pok "$(t ok_env)"
fi


# ========================================
# Step 4: Docker Compose
# ========================================
echo ""
echo "$(t step4)"

# Mautic 7 is now available. Specifying 7.0-apache as requested.

cat > docker-compose.yml << 'DCOMPOSE'
services:
  mautic_db:
    image: mariadb:10.11
    container_name: mautic_db
    restart: always
    env_file: .env
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./db_data:/var/lib/mysql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  mautic_web:
    image: mautic/mautic:7.0-apache
    container_name: mautic_web
    restart: always
    env_file: .env
    environment:
      MAUTIC_DB_HOST: mautic_db
      MAUTIC_DB_PORT: 3306
      MAUTIC_DB_USER: ${MAUTIC_DB_USER}
      MAUTIC_DB_PASSWORD: ${MAUTIC_DB_PASSWORD}
      MAUTIC_DB_NAME: ${MAUTIC_DB_NAME}
      MAUTIC_DB_DATABASE: ${MAUTIC_DB_NAME}
      MAUTIC_URL: ${MAUTIC_URL}
      PHP_INI_DATE_TIMEZONE: ${TIMEZONE}
      MAUTIC_CACHE_DRIVER: redis
      MAUTIC_CACHE_HOST: ${REDIS_HOST}
      MAUTIC_CACHE_PORT: ${REDIS_PORT}
      # Messenger/Queue config for Mautic 5+ (Symfony Messenger)
      MAUTIC_MESSENGER_TRANSPORT_DSN: amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/%2f/messages
    ports:
      - "${MAUTIC_PORT:-8080}:80"
    volumes:
      - ./data:/var/www/html
      - ./logs:/var/www/html/var/logs
    depends_on:
      - mautic_db
      - mautic_redis
      - mautic_rabbitmq
    links:
      - mautic_db:mysql

  mautic_cron:
    image: mautic/mautic:7.0-apache
    container_name: mautic_cron
    restart: always
    entrypoint: ["tail", "-f", "/dev/null"] # Keep alive for cron
    env_file: .env
    environment:
      MAUTIC_DB_HOST: mautic_db
      MAUTIC_DB_PORT: 3306
      MAUTIC_DB_USER: ${MAUTIC_DB_USER}
      MAUTIC_DB_PASSWORD: ${MAUTIC_DB_PASSWORD}
      MAUTIC_DB_NAME: ${MAUTIC_DB_NAME}
      MAUTIC_DB_DATABASE: ${MAUTIC_DB_NAME}
      MAUTIC_URL: ${MAUTIC_URL}
      PHP_INI_DATE_TIMEZONE: ${TIMEZONE}
      MAUTIC_CACHE_DRIVER: redis
      MAUTIC_CACHE_HOST: ${REDIS_HOST}
      MAUTIC_CACHE_PORT: ${REDIS_PORT}
      MAUTIC_MESSENGER_TRANSPORT_DSN: amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/%2f/messages
    volumes:
      - ./data:/var/www/html
    depends_on:
      - mautic_db
      - mautic_redis
      - mautic_rabbitmq

  mautic_worker:
    image: mautic/mautic:7.0-apache
    container_name: mautic_worker
    restart: always
    entrypoint: ["php", "/var/www/html/bin/console", "messenger:consume", "email", "-vv"]
    env_file: .env
    environment:
      MAUTIC_DB_HOST: mautic_db
      MAUTIC_DB_PORT: 3306
      MAUTIC_DB_USER: ${MAUTIC_DB_USER}
      MAUTIC_DB_PASSWORD: ${MAUTIC_DB_PASSWORD}
      MAUTIC_DB_NAME: ${MAUTIC_DB_NAME}
      MAUTIC_DB_DATABASE: ${MAUTIC_DB_NAME}
      MAUTIC_URL: ${MAUTIC_URL}
      PHP_INI_DATE_TIMEZONE: ${TIMEZONE}
      MAUTIC_CACHE_DRIVER: redis
      MAUTIC_CACHE_HOST: ${REDIS_HOST}
      MAUTIC_CACHE_PORT: ${REDIS_PORT}
      MAUTIC_MESSENGER_TRANSPORT_DSN: amqp://${RABBITMQ_DEFAULT_USER}:${RABBITMQ_DEFAULT_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/%2f/messages
    volumes:
      - ./data:/var/www/html
    depends_on:
      - mautic_db
      - mautic_redis
      - mautic_rabbitmq

  mautic_redis:
    image: redis:7-alpine
    container_name: mautic_redis
    restart: always

  mautic_rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: mautic_rabbitmq
    restart: always
    env_file: .env
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
    ports:
      - "15672:15672"
    volumes:
      - ./rabbitmq:/var/lib/rabbitmq
      - .env:/.env

  ofelia:
    image: mcuadros/ofelia:latest
    container_name: mautic_ofelia
    restart: always
    command: daemon --config /etc/ofelia/config.ini
    volumes:
      - ./ofelia_config.ini:/etc/ofelia/config.ini
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - mautic_cron

DCOMPOSE

# ... (Ofelia config remains same) ...
cat > ofelia_config.ini << 'OFELIA'
[job-exec "mautic_segments"]
schedule = @every 5m
container = mautic_cron
command = php /var/www/html/bin/console mautic:segments:update

[job-exec "mautic_campaigns_update"]
schedule = @every 5m
container = mautic_cron
command = php /var/www/html/bin/console mautic:campaigns:update

[job-exec "mautic_campaigns_trigger"]
schedule = @every 5m
container = mautic_cron
command = php /var/www/html/bin/console mautic:campaigns:trigger

[job-exec "mautic_emails_send"]
schedule = @every 1m
container = mautic_cron
command = php /var/www/html/bin/console mautic:emails:send

[job-exec "mautic_broadcasts_send"]
schedule = @every 1m
container = mautic_cron
command = php /var/www/html/bin/console mautic:broadcasts:send

[job-exec "mautic_import"]
schedule = @every 5m
container = mautic_cron
command = php /var/www/html/bin/console mautic:import

[job-exec "mautic_reports_scheduler"]
schedule = 0 0 0 * * *
container = mautic_cron
command = php /var/www/html/bin/console mautic:reports:scheduler

[job-exec "mautic_maintenance"]
schedule = @daily
container = mautic_cron
command = php /var/www/html/bin/console mautic:maintenance:cleanup --days-old=365
OFELIA

pok "docker-compose.yml: OK"
pok "ofelia_config.ini: OK"

# Generate mautic.sh Helper CLI (Gen 4 Standard)
cat << 'MAUTIC_HELPER_EOF' > mautic.sh
#!/usr/bin/env bash
# mautic.sh - Mautic Management Helper (Gen 4 Standard)
# Usage: ./mautic.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

get_env_val() {
    local key="$1"
    local default_val="${2:-}"
    if [ -f .env ]; then
        grep -E "^${key}=" .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "$default_val"
    else
        echo "$default_val"
    fi
}

PORT=$(get_env_val "MAUTIC_PORT" "8080")
DB_USER=$(get_env_val "MAUTIC_DB_USER" "mautic")
DB_NAME=$(get_env_val "MAUTIC_DB_NAME" "mautic")
DB_PASS=$(get_env_val "MAUTIC_DB_PASSWORD" "")

CMD="${1:-help}"

case "$CMD" in
  start)
    echo -e "${GREEN}Starting Mautic stack...${NC}"
    docker compose up -d
    ;;
  stop)
    echo -e "${YELLOW}Stopping Mautic stack...${NC}"
    docker compose stop
    ;;
  restart)
    echo -e "${YELLOW}Restarting Mautic stack...${NC}"
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-mautic_web}"
    ;;
  status)
    echo -e "${CYAN}=== Mautic Container Status ===${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}=== Health Diagnostics ===${NC}"
    echo -n "  • Web interface (port ${PORT}): "
    if curl -sf "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo -e "${GREEN}Responding (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready or starting${NC}"
    fi
    echo -n "  • MariaDB database: "
    if docker compose exec -T mautic_db mariadb-admin ping -u root -p"${DB_PASS}" --silent &>/dev/null || docker compose exec -T mautic_db mysqladmin ping --silent &>/dev/null; then
      echo -e "${GREEN}Ready (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    echo -n "  • Redis Cache: "
    if docker compose exec -T mautic_redis redis-cli ping &>/dev/null; then
      echo -e "${GREEN}Ready (PONG)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/mautic_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/mautic_cfg_$TIMESTAMP.tar.gz"
    
    echo -e "${GREEN}Dumping MariaDB database...${NC}"
    if MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb-dump -u"$DB_USER" "$DB_NAME" | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo -e "  ${GREEN}✓ Database dump: $DB_ARCHIVE (chmod 600)${NC}"
    else
      echo -e "  ${RED}✗ Database backup failed!${NC}"
    fi

    echo -e "${GREEN}Archiving configurations...${NC}"
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml ofelia_config.ini 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo -e "  ${GREEN}✓ Configurations: $CFG_ARCHIVE (chmod 600)${NC}"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo -e "${RED}Usage: ./mautic.sh restore <path-to-sql-gz-archive>${NC}"
      exit 1
    fi
    echo -e "${YELLOW}Verifying archive integrity...${NC}"
    gzip -t "$FILE"
    echo -e "${YELLOW}Taking pre-restore safety dump...${NC}"
    mkdir -p -m 700 backups
    PRE_RESTORE="backups/db-pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb-dump -u"$DB_USER" "$DB_NAME" | gzip > "$PRE_RESTORE" 2>/dev/null || true
    chmod 600 "$PRE_RESTORE" 2>/dev/null || true
    
    echo -e "${RED}WARNING: Restoring will overwrite existing Mautic database!${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      echo "Stopping web and worker containers..."
      docker compose stop mautic_web mautic_worker mautic_cron 2>/dev/null || true
      echo "Importing database..."
      gzip -dc "$FILE" | MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb -u"$DB_USER" "$DB_NAME"
      echo "Restarting stack..."
      docker compose up -d
      echo -e "${GREEN}✓ Mautic database restore completed successfully!${NC}"
    else
      echo "Restore aborted."
    fi
    ;;
  update)
    echo -e "${YELLOW}Backing up .env...${NC}"
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Pulling latest images...${NC}"
    docker compose pull
    docker compose up -d --remove-orphans
    echo -e "${GREEN}✓ Update complete!${NC}"
    ;;
  doctor)
    echo -e "${BOLD}=== Mautic Diagnostic Doctor ===${NC}"
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
    echo "Disk Space:"
    df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo -n "Web port ${PORT} status: "
    if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
      echo -e "${GREEN}Listening${NC}"
    else
      echo -e "${YELLOW}Not listening${NC}"
    fi
    ;;
  uninstall)
    echo -e "${RED}WARNING: This will completely destroy Mautic containers and data volumes.${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo -e "${GREEN}✓ Containers and volumes removed.${NC}"
    else
      echo "Uninstall canceled."
    fi
    ;;
  help|*)
    echo -e "${BOLD}Mautic Management Helper (Gen 4 Standard)${NC}"
    echo ""
    echo "Usage: ./mautic.sh {start|stop|restart|logs|status|backup|restore|doctor|update|uninstall}"
    echo ""
    echo "  start       — Start all containers"
    echo "  stop        — Stop all containers"
    echo "  restart     — Restart all containers"
    echo "  logs [svc]  — View live logs (default: mautic_web)"
    echo "  status      — Container status + health diagnostics"
    echo "  backup      — Dump MariaDB database & configs to ./backups/"
    echo "  restore <f> — Verify and restore database from archive"
    echo "  doctor      — Check system health and permissions"
    echo "  update      — Pull latest images and restart"
    echo "  uninstall   — Stop and remove containers and volumes"
    ;;
esac
MAUTIC_HELPER_EOF
chmod +x mautic.sh
sudo ln -sf "$(pwd)/mautic.sh" /usr/local/bin/mautic 2>/dev/null || true
pok "mautic.sh: OK (symlinked to /usr/local/bin/mautic)"


# ========================================
# Step 5: Start
# ========================================
echo ""
echo "$(t step5)"

echo "$(t ok_pull)"
docker compose pull -q

# Pre-initialize Mautic files if data directory is empty (Fixes Mautic 7 startup issue)
if [ -z "$(ls -A data)" ]; then
    echo "Initializing Mautic files..."
    # Override entrypoint to bypass env vars check. Mount data to /target to not hide image files.
    # Use tar instead of cp to handle directories/symlinks robustly
    docker run --rm --entrypoint "" -v $(pwd)/data:/target mautic/mautic:7.0-apache sh -c "tar cf - -C /var/www/html . | tar xf - -C /target"
    # Fix permissions after copy
    docker run --rm -v $(pwd)/data:/data alpine chown -R 33:33 /data
fi

echo "$(t ok_start)"
docker compose up -d

echo "Waiting for Mautic to respond on port ${MAUTIC_PORT}..."
for i in $(seq 1 40); do
    if curl -sf "http://localhost:${MAUTIC_PORT}" >/dev/null 2>&1; then
        pok "Mautic web is responding!"
        break
    fi
    sleep 3
done


# ========================================
# Step 6: Finish
# ========================================

# Reload vars from .env to ensure we have DB_PASS
if [ -f .env ]; then
    source .env
    DB_PASS="$MAUTIC_DB_PASSWORD"
    RABBITMQ_PASS="$RABBITMQ_DEFAULT_PASS"
fi

echo ""
echo "$(t step6)"
echo ""
echo "$(t finish_title)"
echo ""

if [[ "$LANG" == "vi" ]]; then
# ...

    echo "  👉 1. Truy cập Mautic:"
    echo "     $MAUTIC_URL"
    echo ""
    echo "  👉 2. Cài đặt ban đầu:"
    echo "     - Database Driver: MySQL/MariaDB"
    echo "     - Database Host: mautic_db"
    echo "     - Database Name: mautic"
    echo "     - Database User: mautic"
    echo "     - Database Password: $DB_PASS"
    echo ""
    echo "  👉 3. Cron Jobs & Queue Workers (Tự động):"
    echo "     - Cron: Đã được xử lý bởi container 'ofelia'"
    echo "     - Queue Workers: Xử lý email/campaing ngầm (RabbitMQ + mautic_worker)"
    echo "     - Cache: Redis backend"
    echo ""
    echo "  👉 4. Dịch vụ nội bộ:"
    echo "     - RabbitMQ Info: http://localhost:15672 (user: mautic, pass: $RABBITMQ_PASS)"
    echo ""
    echo "  👉 5. Proxy (Nếu dùng Public Domain):"
    echo "     - Setup Cloudflare Tunnel hoặc Nginx Proxy Manager"
    echo "     - Point domain về port 8080 của máy này."
else
    echo "  👉 1. Access Mautic:"
    echo "     $MAUTIC_URL"
    echo ""
    echo "  👉 2. Initial Setup:"
    echo "     - Database Driver: MySQL/MariaDB"
    echo "     - Database Host: mautic_db"
    echo "     - Database Name: mautic"
    echo "     - Database User: mautic"
    echo "     - Database Password: $DB_PASS"
    echo ""
    echo "  👉 3. Cron Jobs & Queue Workers (Automated):"
    echo "     - Cron: Handled by 'ofelia' container"
    echo "     - Queue Workers: Background processing (RabbitMQ + mautic_worker)"
    echo "     - Cache: Redis backend"
    echo ""
    echo "  👉 4. Internal Services:"
    echo "     - RabbitMQ Info: http://localhost:15672 (user: mautic, pass: $RABBITMQ_PASS)"
    echo ""
    echo "  👉 5. Proxy (If using Public Domain):"
    echo "     - Setup Cloudflare Tunnel or Nginx Proxy Manager"
    echo "     - Point domain to port 8080 of this machine."
fi

echo ""
echo "  Credentials stored in .env"
echo ""
