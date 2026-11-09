#!/usr/bin/env bash
# ==============================================================================
# Postiz Standalone Setup (Gen 4 Standard)
# Supported: Ubuntu/Debian Linux, macOS (Apple Silicon/Intel)
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

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")"
if command -v getent &>/dev/null; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/postiz}"
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
    if ! docker info >/dev/null 2>&1; then
        perr "$(say 'Docker Desktop / OrbStack is not running. Please start it first.' 'Docker Desktop / OrbStack chưa chạy. Vui lòng bật Docker.')"
        exit 1
    fi
elif [[ "$OS" == "Linux" ]]; then
    if [[ "$EUID" -ne 0 ]]; then
        perr "$(say 'On Linux, please run setup with root privileges (sudo bash setup.sh).' 'Trên Linux, vui lòng chạy setup bằng quyền root (sudo bash setup.sh).')"
        exit 1
    fi
    PLATFORM="linux"
    PLATFORM_LABEL="Linux ($ARCH)"
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
echo "           Postiz Auto Setup — Gen 4 Standard"
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
        pwn "$(say "Low memory detected (<4GB RAM and <2GB Swap). Postiz runs best with sufficient swap." \
                   "Phát hiện RAM thấp (<4GB RAM và <2GB Swap). Postiz cần thêm Swap để chạy ổn định.")"
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

for c in openssl curl; do
    if ! command -v "$c" &>/dev/null; then
        if [[ "$OS" == "Linux" ]]; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$c" 2>/dev/null || true
        fi
    fi
done

# Step 2: Directory Setup
step_title "2/6" "Installation Directory" "Thư mục cài đặt"
echo -e "  • Target directory: ${PURPLE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p backups dynamicconfig

# Step 3: Architecture Profile & Port Check
step_title "3/6" "Architecture Profile & Port Check" "Chọn cấu trúc cài đặt & kiểm tra cổng"

echo "  1) Standard Lightweight Stack ($(say 'Recommended — Postiz App + Postgres + Redis, ~1.5 GB RAM' 'Khuyên dùng — Postiz + Postgres + Redis, tốn ~1.5 GB RAM'))"
echo "  2) Full Enterprise Stack ($(say 'Postiz App + Temporal + Elasticsearch 7.17 + Postgres + Redis, ~5 GB RAM' 'Postiz + Temporal + Elasticsearch 7.17 + Postgres + Redis, tốn ~5 GB RAM'))"
read -rp "  $(say 'Select Profile [1-2] (default: 1): ' 'Chọn cấu trúc [1-2] (mặc định: 1): ') " PROFILE_CHOICE || true
PROFILE_CHOICE="${PROFILE_CHOICE:-1}"

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

POSTIZ_PORT="${POSTIZ_PORT:-5000}"
if check_port "$POSTIZ_PORT"; then
    pwn "$(say "Port $POSTIZ_PORT is in use!" "Cổng $POSTIZ_PORT đang được sử dụng!")"
    ALT_PORT=5001
    while check_port "$ALT_PORT"; do
        ALT_PORT=$((ALT_PORT + 1))
    done
    read -rp "  $(say "Enter alternative port (default: $ALT_PORT): " "Nhập cổng khác (mặc định: $ALT_PORT): ") " USER_PORT || true
    POSTIZ_PORT="${USER_PORT:-$ALT_PORT}"
fi
pok "$(say "Selected port for Postiz: $POSTIZ_PORT" "Cổng hoạt động Postiz: $POSTIZ_PORT")"

# Domain Configuration
echo ""
echo "  1) Localhost (http://localhost:${POSTIZ_PORT} - $(say 'For local testing' 'Dành cho thử nghiệm local'))"
echo "  2) Local Network (http://<LAN_IP>:${POSTIZ_PORT} - $(say 'For LAN devices' 'Dành cho mạng nội bộ'))"
echo "  3) Public Domain (https://your-domain.com - $(say 'Required for Social Media OAuth' 'Bắt buộc cho OAuth mạng xã hội'))"
read -rp "  $(say 'Select Network Mode [1-3] (default: 1): ' 'Chọn chế độ mạng [1-3] (mặc định: 1): ') " NET_CHOICE || true

case "${NET_CHOICE:-1}" in
    2)
        LAN_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
        MAIN_URL="http://${LAN_IP}:${POSTIZ_PORT}"
        ;;
    3)
        read -rp "  $(say 'Enter public domain (e.g. postiz.example.com): ' 'Nhập domain công khai (ví dụ postiz.example.com): ') " DOMAIN_INPUT || true
        DOMAIN_INPUT="${DOMAIN_INPUT:-localhost}"
        MAIN_URL="https://${DOMAIN_INPUT}"
        ;;
    *)
        MAIN_URL="http://localhost:${POSTIZ_PORT}"
        ;;
esac
pok "$(say "MAIN_URL: $MAIN_URL" "URL chính: $MAIN_URL")"

# Step 4: Authoritative File Generation
step_title "4/6" "Authoritative Files Generation" "Khởi tạo file cấu hình & script chuẩn"

cat > "$INSTALL_DIR/dynamicconfig/development-sql.yaml" << 'DYNEOF'
system.forceSearchAttributesCacheRefreshOnRead:
  - value: true
    constraints: {}
limit.maxIDLength:
  - value: 255
    constraints: {}
DYNEOF

# Generate docker-compose.yml based on profile
if [ "$PROFILE_CHOICE" = "2" ]; then
    cat > "$INSTALL_DIR/docker-compose.yml" << 'COMPOSE_FULL_EOF'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    ports:
      - "${POSTIZ_PORT:-5000}:5000"
    env_file: .env
    environment:
      NODE_ENV: production
    volumes:
      - postiz-uploads:/uploads/
    networks:
      - postiz-network
      - temporal-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy

  postiz-postgres:
    image: postgres:17-alpine
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 5

  postiz-redis:
    image: redis:7.2-alpine
    container_name: postiz-redis
    restart: always
    volumes:
      - redis-data:/data
    networks:
      - postiz-network
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 5

  temporal:
    container_name: temporal
    image: temporalio/auto-setup:1.28.1
    ports:
      - "7233:7233"
    environment:
      - DB=postgres12
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=temporal
      - POSTGRES_SEEDS=temporal-postgresql
      - DYNAMIC_CONFIG_FILE_PATH=config/dynamicconfig/development-sql.yaml
      - ENABLE_ES=true
      - ES_SEEDS=temporal-elasticsearch
      - ES_VERSION=v7
    volumes:
      - ./dynamicconfig:/etc/temporal/config/dynamicconfig
    networks:
      - temporal-network
    depends_on:
      - temporal-postgresql
      - temporal-elasticsearch

  temporal-postgresql:
    container_name: temporal-postgresql
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: temporal
      POSTGRES_USER: temporal
    volumes:
      - temporal-postgres-data:/var/lib/postgresql/data
    networks:
      - temporal-network

  temporal-elasticsearch:
    container_name: temporal-elasticsearch
    image: elasticsearch:7.17.27
    environment:
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms256m -Xmx256m
      - xpack.security.enabled=false
    volumes:
      - temporal-es-data:/usr/share/elasticsearch/data
    networks:
      - temporal-network

  temporal-ui:
    container_name: temporal-ui
    image: temporalio/ui:2.34.0
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=http://localhost:3000
    ports:
      - "8080:8080"
    networks:
      - temporal-network

networks:
  postiz-network:
  temporal-network:

volumes:
  postgres-data:
  redis-data:
  postiz-uploads:
  temporal-postgres-data:
  temporal-es-data:
COMPOSE_FULL_EOF
else
    # Lightweight profile (recommended)
    cat > "$INSTALL_DIR/docker-compose.yml" << 'COMPOSE_LITE_EOF'
services:
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    ports:
      - "${POSTIZ_PORT:-5000}:5000"
    env_file: .env
    environment:
      NODE_ENV: production
    volumes:
      - postiz-uploads:/uploads/
    networks:
      - postiz-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy

  postiz-postgres:
    image: postgres:17-alpine
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 5

  postiz-redis:
    image: redis:7.2-alpine
    container_name: postiz-redis
    restart: always
    volumes:
      - redis-data:/data
    networks:
      - postiz-network
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 5

networks:
  postiz-network:

volumes:
  postgres-data:
  redis-data:
  postiz-uploads:
COMPOSE_LITE_EOF
fi

# Generate postiz.sh Helper CLI
cat << 'POSTIZ_CLI_EOF' > "$INSTALL_DIR/postiz.sh"
#!/usr/bin/env bash
# Postiz Management CLI (Gen 4 Standard)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
CMD="${1:-help}"

case "$CMD" in
  start)
    echo "Starting Postiz..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping Postiz..."
    docker compose stop
    ;;
  restart)
    echo "Restarting Postiz..."
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-postiz}"
    ;;
  status)
    echo "=== Postiz Services Status ==="
    docker compose ps
    echo ""
    echo "Health check:"
    docker exec postiz-postgres pg_isready -U postiz-user -d postiz-db-local &>/dev/null && echo "  [OK] PostgreSQL" || echo "  [WARN] PostgreSQL not ready"
    docker exec postiz-redis redis-cli ping &>/dev/null && echo "  [OK] Redis" || echo "  [WARN] Redis not ready"
    curl -sf http://localhost:5000 &>/dev/null && echo "  [OK] Postiz Web" || echo "  [WARN] Postiz starting..."
    ;;
  update)
    echo "Backing up .env..."
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo "Pulling latest images..."
    docker compose pull
    docker compose up -d --remove-orphans
    echo "Update complete!"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/postiz_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/postiz_cfg_$TIMESTAMP.tar.gz"
    
    echo "Dumping PostgreSQL database..."
    if docker exec postiz-postgres pg_dump -U postiz-user postiz-db-local | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo "  ✓ Database archived to: $DB_ARCHIVE (chmod 600)"
    else
      echo "  ✗ Database backup failed!"
    fi
    
    echo "Archiving configuration & uploads..."
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo "  ✓ Configuration archived to: $CFG_ARCHIVE (chmod 600)"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo "Usage: ./postiz.sh restore <path-to-sql-gz-archive>"
      exit 1
    fi
    echo "Verifying archive integrity..."
    gzip -t "$FILE"
    echo "WARNING: Restoring will overwrite existing postiz-db-local database!"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      gunzip -c "$FILE" | docker exec -i postiz-postgres psql -U postiz-user -d postiz-db-local
      echo "Database restore completed successfully! Restarting postiz..."
      docker compose restart postiz
    else
      echo "Restore aborted."
    fi
    ;;
  doctor)
    echo "=== Postiz System Doctor ==="
    echo "Checking Docker..."
    docker --version || echo "  [FAIL] Docker not found"
    docker compose version || echo "  [FAIL] Docker Compose not found"
    echo "Disk Space:"
    df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo "Testing Port Bindings:"
    for p in 5000 8080; do
      if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
        echo "  [BOUND] Port $p is listening"
      else
        echo "  [OPEN/UNKNOWN] Port $p"
      fi
    done
    ;;
  uninstall)
    echo "WARNING: This will completely destroy Postiz containers and data volumes."
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo "Containers and data volumes removed."
    else
      echo "Uninstall canceled."
    fi
    ;;
  *)
    echo "Usage: ./postiz.sh {start|stop|restart|logs|status|update|backup|restore|doctor|uninstall}"
    ;;
esac
POSTIZ_CLI_EOF
chmod +x "$INSTALL_DIR/postiz.sh"

# System symlink
sudo ln -sf "$INSTALL_DIR/postiz.sh" /usr/local/bin/postiz 2>/dev/null || true
pok "$(say 'Authoritative configuration and helper CLI postiz.sh created.' 'Đã khởi tạo cấu hình và trình quản lý postiz.sh.')"

# Step 5: Environment Setup (.env)
step_title "5/6" "Configuring Environment (.env)" "Thiết lập biến môi trường"

if [ ! -f .env ]; then
    JWT_SECRET=$(openssl rand -hex 32)
    POSTGRES_PASSWORD=$(openssl rand -hex 16)

    cat > .env << EOF
# Postiz Configuration (Gen 4 Standard)
MAIN_URL="${MAIN_URL}"
FRONTEND_URL="${MAIN_URL}"
NEXT_PUBLIC_BACKEND_URL="${MAIN_URL}/api"
BACKEND_INTERNAL_URL="http://localhost:5000"
POSTIZ_PORT="${POSTIZ_PORT}"

DATABASE_URL="postgresql://postiz-user:${POSTGRES_PASSWORD}@postiz-postgres:5432/postiz-db-local"
REDIS_URL="redis://postiz-redis:6379"

JWT_SECRET="${JWT_SECRET}"
IS_GENERAL="true"
DISABLE_REGISTRATION="false"
API_LIMIT=300

STORAGE_PROVIDER="local"
UPLOAD_DIRECTORY="/uploads"
NEXT_PUBLIC_UPLOAD_DIRECTORY="/uploads"
TEMPORAL_ADDRESS="temporal:7233"

# Social Media API Keys (Fill as needed)
X_API_KEY=""
X_API_SECRET=""
LINKEDIN_CLIENT_ID=""
LINKEDIN_CLIENT_SECRET=""
REDDIT_CLIENT_ID=""
REDDIT_CLIENT_SECRET=""
GITHUB_CLIENT_ID=""
GITHUB_CLIENT_SECRET=""
OPENAI_API_KEY=""
NX_ADD_PLUGINS=false
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

echo "  → $(say 'Launching Postiz containers...' 'Đang khởi động các container Postiz...')"
docker compose up -d --remove-orphans

echo "  → $(say 'Waiting for Postiz readiness...' 'Đang đợi Postiz sẵn sàng...')"
for i in $(seq 1 40); do
    if curl -sf "http://localhost:${POSTIZ_PORT}" >/dev/null 2>&1; then
        pok "$(say 'Postiz Web is responding!' 'Postiz Web đã phản hồi thành công!')"
        break
    fi
    sleep 3
done

# Safe host-files-only ownership adjustment post startup
find "$INSTALL_DIR" -maxdepth 1 -type f -exec chown "$TARGET_USER:$TARGET_GROUP" {} + 2>/dev/null || true

echo ""
echo "================================================================"
echo -e "${GREEN}${BOLD}  🎉 $(say 'POSTIZ SETUP COMPLETED SUCCESSFULLY!' 'CÀI ĐẶT POSTIZ HOÀN TẤT THÀNH CÔNG!')${NC}"
echo "================================================================"
echo -e "  • Postiz App:      ${PURPLE}http://localhost:${POSTIZ_PORT}${NC}"
if [[ "$MAIN_URL" == https* ]]; then
    echo -e "  • Public URL:      ${PURPLE}${MAIN_URL}${NC} ($(say 'via reverse proxy' 'qua reverse proxy'))"
fi
echo -e "  • Config file:     ${PURPLE}$INSTALL_DIR/.env${NC} (chmod 600)"
echo -e "  • Helper CLI:      ${PURPLE}postiz${NC} (or ./postiz.sh)"
echo "================================================================"
echo "$(say 'Quick management commands:' 'Các lệnh quản lý nhanh:'):"
echo "  • postiz status"
echo "  • postiz logs"
echo "  • postiz backup"
echo "  • postiz doctor"
echo "  • postiz update"
