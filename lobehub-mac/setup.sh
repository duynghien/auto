#!/bin/bash
################################################################
# LobeHub v3.0 Auto-Install for macOS Apple Silicon
# Full features: Knowledge Base, Search, Upload, Artifacts, ...
# Based on official lobehub/lobe-chat docker-compose deployment
################################################################

set -euo pipefail

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
    echo "        LobeHub macOS Apple Silicon Setup v3.0"
    echo "   Full: Search · Knowledge Base · Upload · Artifacts"
    echo "================================================================${NC}"
}

# Start
clear
pheader

echo "[1/10] Kiểm tra hệ thống Mac"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    perr "Script chỉ dành cho macOS!"
    exit 1
fi

# Check Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
    pwn "Không phải Apple Silicon, hiệu năng sẽ ảnh hưởng"
else
    pok "Kiến trúc: Apple Silicon ARM64 (M1/M2/M3/M4)"
fi

# Check Docker (OrbStack or Docker Desktop)
if ! command -v docker &> /dev/null; then
    perr "Docker chưa cài đặt!"
    perr "Tải: https://orbstack.dev hoặc https://docker.com"
    exit 1
fi

# Detect Docker environment
if command -v orb &> /dev/null; then
    pok "OrbStack: OK"
elif docker context ls 2>/dev/null | grep -q orbstack; then
    pok "OrbStack (context): OK"
else
    pwn "Docker Desktop có thể chưa chạy"
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    perr "Docker Compose Plugin chưa cài đặt!"
    exit 1
fi
pok "Docker Compose: OK"

# Dependencies
for c in openssl python3 curl; do
    if ! command -v $c &> /dev/null; then
        perr "Thiếu: $c"
        exit 1
    fi
done
pok "Dependencies: OK"

# ========================================
# Step 2: Directory
# ========================================
echo ""
echo "[2/10] Khởi tạo thư mục"

INSTALL_DIR="$HOME/lobehub-mac"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "Thư mục: $INSTALL_DIR"

# ========================================
# Step 3: Generate Secrets & Save to .env
# ========================================
echo ""
echo "[3/10] Sinh Secrets (lưu vào .env)"

# Preserve existing secrets if .env exists
if [ -f .env ]; then
    pwn "Tìm thấy .env cũ, giữ nguyên secrets..."
    source .env 2>/dev/null || true
fi

# Generate secrets if not exist
[ -z "${POSTGRES_PASSWORD:-}" ] && POSTGRES_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')
[ -z "${RUSTFS_ACCESS_KEY:-}" ] && RUSTFS_ACCESS_KEY="admin"
[ -z "${RUSTFS_SECRET_KEY:-}" ] && RUSTFS_SECRET_KEY=$(openssl rand -base64 16 | tr -d '=+/')
[ -z "${AUTH_SECRET:-}" ] && AUTH_SECRET=$(openssl rand -base64 32)
[ -z "${KEY_VAULTS_SECRET:-}" ] && KEY_VAULTS_SECRET=$(openssl rand -base64 32)

# Also set MinIO vars (same as RustFS for compatibility)
S3_ACCESS_KEY="${RUSTFS_ACCESS_KEY}"
S3_SECRET_KEY="${RUSTFS_SECRET_KEY}"

# Generate JWKS
if [ -z "${JWKS_KEY:-}" ]; then
    pok "Tạo JWKS RSA Key..."
    TMP_PEM=$(mktemp)
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$TMP_PEM" 2>/dev/null

    JWKS_KEY=$(python3 << PYEOF
import subprocess, json, base64, secrets, re

def b64u(n):
    l = (n.bit_length() + 7) // 8
    return base64.urlsafe_b64encode(n.to_bytes(l, 'big')).rstrip(b'=').decode()

r = subprocess.run(['openssl', 'rsa', '-in', '$TMP_PEM', '-text', '-noout'], capture_output=True, text=True)
t = r.stdout

def xh(f):
    m = re.search(f + r':\s*\n([\s0-9a-f:]+)', t, re.DOTALL)
    return int(m.group(1).replace(' ', '').replace('\n', '').replace(':', ''), 16) if m else 0

em = re.search(r'publicExponent:\s*(\d+)', t)
e = int(em.group(1)) if em else 65537
n = xh('modulus')
d = xh('privateExponent')
p = xh('prime1')
q = xh('prime2')
dp = xh('exponent1')
dq = xh('exponent2')
qi = xh('coefficient')

kid = secrets.token_hex(8)
jwk = {
    'kty': 'RSA', 'use': 'sig', 'alg': 'RS256', 'kid': kid,
    'n': b64u(n), 'e': b64u(e), 'd': b64u(d),
    'p': b64u(p), 'q': b64u(q), 'dp': b64u(dp), 'dq': b64u(dq), 'qi': b64u(qi)
}
print(json.dumps({'keys': [jwk]}, separators=(',', ':')))
PYEOF
)
    rm -f "$TMP_PEM"
    pok "JWKS Key: OK"
fi

# Generate SearXNG secret
SEARXNG_SECRET=$(openssl rand -hex 32)

pok "Secrets: OK"

# ========================================
# Step 4: Choose S3 Storage
# ========================================
echo ""
echo "[4/10] Chọn S3 Storage"
echo ""
echo "  1) RustFS (mặc định LobeHub, nhẹ, nhanh)"
echo "  2) MinIO  (truyền thống, ổn định)"
echo ""
read -p "Nhập 1 hoặc 2 [1]: " S3_CHOICE

S3_CHOICE=${S3_CHOICE:-1}

if [[ "$S3_CHOICE" == "2" ]]; then
    S3_SERVICE="minio"
    S3_SERVICE_NAME="MinIO"
else
    S3_SERVICE="rustfs"
    S3_SERVICE_NAME="RustFS"
fi

pok "Chọn: $S3_SERVICE_NAME"

# ========================================
# Step 5: Save .env
# ========================================
echo ""
echo "[5/10] Lưu cấu hình .env"

cat > .env << ENVEOF
# =================================================================
# LobeHub v3.0 - Configuration & Secrets
# ⚠️  KHÔNG chia sẻ file này! Chứa thông tin nhạy cảm
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# =================================================================

# ===========================
# ====== Preset config ======
# ===========================
LOBE_PORT=3210
RUSTFS_PORT=9000
APP_URL=http://localhost:3210

# Auth Secrets
AUTH_SECRET=$AUTH_SECRET
KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET
JWKS_KEY=$JWKS_KEY

# Database (PostgreSQL + ParadeDB)
LOBE_DB_NAME=lobechat
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# S3 Storage ($S3_SERVICE_NAME)
RUSTFS_ACCESS_KEY=$RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY=$RUSTFS_SECRET_KEY
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
S3_ENDPOINT=http://localhost:9000
RUSTFS_LOBE_BUCKET=lobe

# S3 Storage choice
S3_SERVICE=$S3_SERVICE
ENVEOF

pok "Config đã lưu vào .env"

# ========================================
# Step 6: Configuration Files
# ========================================
echo ""
echo "[6/10] Tạo file cấu hình"

# Bucket policy - READ ONLY public (compatible with both MinIO and RustFS)
cat > bucket.config.json << 'BUCKETEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::lobe/*"]
    }
  ]
}
BUCKETEOF

pok "bucket.config.json: OK (read-only public)"

# SearXNG Settings - download official config from LobeHub repo
pok "Tải searxng-settings.yml từ LobeHub official..."
SEARXNG_URL="https://raw.githubusercontent.com/lobehub/lobe-chat/HEAD/docker-compose/deploy/searxng-settings.yml"
if curl -sfL "$SEARXNG_URL" -o searxng-settings.yml; then
    pok "searxng-settings.yml: OK (official LobeHub config)"
else
    pwn "Không tải được từ GitHub, tạo config mặc định..."
    # Fallback: generate minimal valid config
    cat > searxng-settings.yml << SEARXNGEOF
use_default_settings: true

general:
  debug: false
  instance_name: 'lobehub-search'

search:
  safe_search: 0
  autocomplete: 'google'
  formats:
    - html
    - json

server:
  port: 8080
  bind_address: '0.0.0.0'
  secret_key: '$SEARXNG_SECRET'
  limiter: false
  image_proxy: false
  method: 'POST'
SEARXNGEOF
    pok "searxng-settings.yml: OK (fallback config)"
fi

# ========================================
# Step 7: Create Docker Compose
# ========================================
echo ""
echo "[7/10] Tạo Docker Compose"

if [[ "$S3_SERVICE" == "rustfs" ]]; then
# ---- RustFS Docker Compose ----
cat > docker-compose.yml << 'DCOMPOSE'
name: lobehub-mac

services:
  network-service:
    image: alpine
    container_name: lobe-network
    restart: always
    ports:
      - '${LOBE_PORT:-3210}:3210'
      - '${RUSTFS_PORT:-9000}:9000'
      - '9001:9001'
    command: tail -f /dev/null
    networks:
      - lobe-network

  postgresql:
    image: paradedb/paradedb:latest-pg17
    container_name: lobe-mac-postgres
    restart: always
    volumes:
      - ./data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${LOBE_DB_NAME:-lobechat}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - lobe-network

  redis:
    image: redis:7-alpine
    container_name: lobe-mac-redis
    restart: always
    command: redis-server --save 60 1000 --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - lobe-network

  rustfs:
    image: rustfs/rustfs:latest
    container_name: lobe-mac-rustfs
    network_mode: "service:network-service"
    environment:
      - RUSTFS_CONSOLE_ENABLE=true
      - RUSTFS_ACCESS_KEY=${RUSTFS_ACCESS_KEY}
      - RUSTFS_SECRET_KEY=${RUSTFS_SECRET_KEY}
    volumes:
      - rustfs_data:/data
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:9000/health >/dev/null 2>&1 || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 30
    command:
      ["--access-key", "${RUSTFS_ACCESS_KEY}", "--secret-key", "${RUSTFS_SECRET_KEY}", "/data"]

  rustfs-init:
    image: minio/mc:latest
    container_name: lobe-mac-rustfs-init
    depends_on:
      rustfs:
        condition: service_healthy
    volumes:
      - ./bucket.config.json:/bucket.config.json:ro
    entrypoint: /bin/sh
    command: >
      -c '
        set -eux;
        mc alias set rustfs "http://network-service:9000" "${RUSTFS_ACCESS_KEY}" "${RUSTFS_SECRET_KEY}";
        mc mb "rustfs/lobe" --ignore-existing;
        mc anonymous set-json "/bucket.config.json" "rustfs/lobe" || mc anonymous set download "rustfs/lobe";
      '
    restart: "no"
    networks:
      - lobe-network

  searxng:
    image: searxng/searxng
    container_name: lobe-mac-searxng
    restart: always
    volumes:
      - ./searxng-settings.yml:/etc/searxng/settings.yml
    environment:
      - SEARXNG_SETTINGS_FILE=/etc/searxng/settings.yml
    networks:
      - lobe-network

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobe-mac-app
    network_mode: "service:network-service"
    restart: always
    depends_on:
      postgresql:
        condition: service_healthy
      network-service:
        condition: service_started
      rustfs:
        condition: service_healthy
      rustfs-init:
        condition: service_completed_successfully
      redis:
        condition: service_healthy
    environment:
      # Auth
      - AUTH_SECRET=${AUTH_SECRET}
      - KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET}
      # Database
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgresql:5432/${LOBE_DB_NAME:-lobechat}
      # Redis
      - REDIS_URL=redis://redis:6379
      - REDIS_PREFIX=lobechat
      - REDIS_TLS=0
      # S3 Storage (RustFS via internal network)
      - S3_BUCKET=${RUSTFS_LOBE_BUCKET:-lobe}
      - S3_ENABLE_PATH_STYLE=1
      - S3_ACCESS_KEY=${RUSTFS_ACCESS_KEY}
      - S3_ACCESS_KEY_ID=${RUSTFS_ACCESS_KEY}
      - S3_SECRET_ACCESS_KEY=${RUSTFS_SECRET_KEY}
      - S3_SET_ACL=0
      - S3_PROXY=1
      # Image Vision
      - LLM_VISION_IMAGE_USE_BASE64=1
      # Online Search (SearXNG)
      - SEARXNG_URL=http://searxng:8080
      - SEARCH_PROVIDERS=searxng
      - CRAWLER_IMPLS=naive
    env_file:
      - .env

volumes:
  redis_data:
  rustfs_data:

networks:
  lobe-network:
    driver: bridge
DCOMPOSE

else
# ---- MinIO Docker Compose ----
cat > docker-compose.yml << 'DCOMPOSE'
name: lobehub-mac

services:
  network-service:
    image: alpine
    container_name: lobe-network
    restart: always
    ports:
      - '${LOBE_PORT:-3210}:3210'
      - '${RUSTFS_PORT:-9000}:9000'
      - '9001:9001'
    command: tail -f /dev/null
    networks:
      - lobe-network

  postgresql:
    image: paradedb/paradedb:latest-pg17
    container_name: lobe-mac-postgres
    restart: always
    volumes:
      - ./data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${LOBE_DB_NAME:-lobechat}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - lobe-network

  redis:
    image: redis:7-alpine
    container_name: lobe-mac-redis
    restart: always
    command: redis-server --save 60 1000 --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - lobe-network

  minio:
    image: minio/minio:latest
    container_name: lobe-mac-minio
    network_mode: "service:network-service"
    environment:
      - MINIO_ROOT_USER=${S3_ACCESS_KEY}
      - MINIO_ROOT_PASSWORD=${S3_SECRET_KEY}
      - MINIO_API_CORS_ORIGIN=http://localhost:3210
    volumes:
      - minio_data:/data
    command: server --console-address ":9001" /data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 10s
      timeout: 5s
      retries: 10

  minio-init:
    image: minio/mc:latest
    container_name: lobe-mac-minio-init
    depends_on:
      minio:
        condition: service_healthy
    volumes:
      - ./bucket.config.json:/bucket.config.json:ro
    entrypoint: /bin/sh
    command: >
      -c '
        set -eux;
        mc alias set minio "http://network-service:9000" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}";
        mc mb "minio/lobe" --ignore-existing;
        mc anonymous set-json "/bucket.config.json" "minio/lobe" || mc anonymous set download "minio/lobe";
      '
    restart: "no"
    networks:
      - lobe-network

  searxng:
    image: searxng/searxng
    container_name: lobe-mac-searxng
    restart: always
    volumes:
      - ./searxng-settings.yml:/etc/searxng/settings.yml
    environment:
      - SEARXNG_SETTINGS_FILE=/etc/searxng/settings.yml
    networks:
      - lobe-network

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobe-mac-app
    network_mode: "service:network-service"
    restart: always
    depends_on:
      postgresql:
        condition: service_healthy
      network-service:
        condition: service_started
      minio:
        condition: service_healthy
      minio-init:
        condition: service_completed_successfully
      redis:
        condition: service_healthy
    environment:
      # Auth
      - AUTH_SECRET=${AUTH_SECRET}
      - KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET}
      # Database
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgresql:5432/${LOBE_DB_NAME:-lobechat}
      # Redis
      - REDIS_URL=redis://redis:6379
      - REDIS_PREFIX=lobechat
      - REDIS_TLS=0
      # S3 Storage (MinIO via internal network)
      - S3_BUCKET=lobe
      - S3_ENABLE_PATH_STYLE=1
      - S3_ACCESS_KEY=${S3_ACCESS_KEY}
      - S3_ACCESS_KEY_ID=${S3_ACCESS_KEY}
      - S3_SECRET_ACCESS_KEY=${S3_SECRET_KEY}
      - S3_SET_ACL=0
      - S3_PROXY=1
      # Image Vision
      - LLM_VISION_IMAGE_USE_BASE64=1
      # Online Search (SearXNG)
      - SEARXNG_URL=http://searxng:8080
      - SEARCH_PROVIDERS=searxng
      - CRAWLER_IMPLS=naive
    env_file:
      - .env

volumes:
  redis_data:
  minio_data:

networks:
  lobe-network:
    driver: bridge
DCOMPOSE

fi

pok "Docker Compose: OK ($S3_SERVICE_NAME + SearXNG)"

# ========================================
# Step 8: Start Services
# ========================================
echo ""
echo "[8/10] Khởi động Container ($S3_SERVICE_NAME + SearXNG)"

cd "$INSTALL_DIR"

# Stop any existing containers
pok "Dừng containers cũ (nếu có)..."
docker compose down 2>/dev/null || true

# Pull images
pok "Tải Docker images (lần đầu sẽ lâu)..."
docker compose pull

# Start infrastructure first
pok "Khởi động PostgreSQL, Redis & SearXNG..."
docker compose up -d network-service postgresql redis searxng

# Wait for PostgreSQL
pok "Đang chờ PostgreSQL (ParadeDB)..."
for i in {1..60}; do
    if docker exec lobe-mac-postgres pg_isready -U postgres &>/dev/null; then
        pok "PostgreSQL (ParadeDB): sẵn sàng!"
        break
    fi
    [ $i -eq 60 ] && { perr "PostgreSQL không khởi động được!"; exit 1; }
    sleep 2
done

# Wait for Redis
pok "Đang chờ Redis..."
for i in {1..30}; do
    if docker exec lobe-mac-redis redis-cli ping &>/dev/null; then
        pok "Redis: sẵn sàng!"
        break
    fi
    [ $i -eq 30 ] && { perr "Redis không khởi động được!"; exit 1; }
    sleep 2
done

# Start S3 Storage
if [[ "$S3_SERVICE" == "rustfs" ]]; then
    pok "Khởi động RustFS..."
    docker compose up -d rustfs
    pok "Đang chờ RustFS..."
    for i in {1..60}; do
        if curl -sf http://localhost:9000/health &>/dev/null; then
            pok "RustFS: sẵn sàng!"
            break
        fi
        [ $i -eq 60 ] && { perr "RustFS không khởi động được!"; exit 1; }
        sleep 2
    done
    # Init bucket
    pok "Khởi tạo S3 bucket..."
    docker compose up rustfs-init
else
    pok "Khởi động MinIO..."
    docker compose up -d minio
    pok "Đang chờ MinIO..."
    for i in {1..60}; do
        if curl -sf http://localhost:9000/minio/health/live &>/dev/null; then
            pok "MinIO: sẵn sàng!"
            break
        fi
        [ $i -eq 60 ] && { perr "MinIO không khởi động được!"; exit 1; }
        sleep 2
    done
    # Init bucket
    pok "Khởi tạo S3 bucket..."
    docker compose up minio-init
fi

# Start LobeHub
pok "Khởi động LobeHub..."
docker compose up -d lobe

# Wait for LobeHub
pok "Đang chờ LobeHub khởi động..."
for i in {1..120}; do
    if curl -sf http://localhost:3210 >/dev/null 2>&1; then
        pok "LobeHub: sẵn sàng!"
        break
    fi
    [ $i -eq 120 ] && pwn "LobeHub cần thêm thời gian khởi động"
    sleep 2
done

# ========================================
# Step 9: Verify Services
# ========================================
echo ""
echo "[9/10] Kiểm tra services"

ALL_OK=true

docker exec lobe-mac-postgres pg_isready -U postgres &>/dev/null && pok "PostgreSQL (ParadeDB): OK" || { perr "PostgreSQL: LỖI"; ALL_OK=false; }
docker exec lobe-mac-redis redis-cli ping &>/dev/null && pok "Redis: OK" || { perr "Redis: LỖI"; ALL_OK=false; }

if [[ "$S3_SERVICE" == "rustfs" ]]; then
    curl -sf http://localhost:9000/health &>/dev/null && pok "RustFS: OK" || { perr "RustFS: LỖI"; ALL_OK=false; }
else
    curl -sf http://localhost:9000/minio/health/live &>/dev/null && pok "MinIO: OK" || { perr "MinIO: LỖI"; ALL_OK=false; }
fi

# Test SearXNG
SEARXNG_OK=false
for i in {1..10}; do
    if docker exec lobe-mac-searxng wget -qO- http://localhost:8080 &>/dev/null; then
        pok "SearXNG: OK"
        SEARXNG_OK=true
        break
    fi
    sleep 2
done
if [ "$SEARXNG_OK" = false ]; then
    perr "SearXNG: LỖI (search sẽ không hoạt động)"
    ALL_OK=false
fi

curl -sf http://localhost:3210 >/dev/null && pok "LobeHub: OK" || { perr "LobeHub: LỖI"; ALL_OK=false; }

# ========================================
# Step 10: Create Helper Script & Finish
# ========================================
echo ""
echo "[10/10] Hoàn tất"

# Create helper script
cat > lobe.sh << 'SCRIPTEOF'
#!/bin/bash
# LobeHub Helper Script v3.0

cd "$(dirname "$0")"

case "$1" in
  start)
    echo "🚀 Starting LobeHub..."
    docker compose up -d
    echo "✅ Started! Access: http://localhost:3210"
    ;;
  stop)
    echo "🛑 Stopping LobeHub..."
    docker compose stop
    echo "✅ Stopped!"
    ;;
  restart)
    echo "🔄 Restarting LobeHub..."
    docker compose restart
    echo "✅ Restarted!"
    ;;
  logs)
    docker compose logs -f "${2:-lobe}"
    ;;
  status)
    docker compose ps
    ;;
  upgrade)
    echo "⬆️  Upgrading LobeHub..."
    docker compose pull
    docker compose up -d
    echo "✅ Upgraded!"
    ;;
  search-test)
    echo "🔍 Testing SearXNG..."
    QUERY="${2:-test}"
    RESULT=$(docker exec lobe-mac-searxng wget -qO- "http://localhost:8080/search?q=${QUERY}&format=json" 2>/dev/null)
    if echo "$RESULT" | grep -q '"results"'; then
      echo "✅ SearXNG OK! Search working."
      echo "$RESULT" | python3 -m json.tool 2>/dev/null | head -20
    else
      echo "❌ SearXNG not responding. Check logs: ./lobe.sh logs searxng"
    fi
    ;;
  reset)
    echo "⚠️  Xóa TẤT CẢ data (database, uploads, secrets)..."
    read -p "Nhập 'yes' để xác nhận: " confirm
    if [[ "$confirm" == "yes" ]]; then
      docker compose down -v
      rm -rf ./data
      echo "✅ Đã xóa tất cả!"
    else
      echo "❌ Hủy bỏ."
    fi
    ;;
  secrets)
    echo "📁 Secrets file: $(pwd)/.env"
    cat .env
    ;;
  s3-login)
    echo "S3 Storage Credentials:"
    grep -E "^(RUSTFS_|S3_)(ACCESS_KEY|SECRET_KEY)=" .env | head -4 | sed 's/=/: /'
    echo ""
    echo "Console: http://localhost:9001"
    ;;
  *)
    echo "LobeHub Helper v3.0"
    echo ""
    echo "Usage: ./lobe.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start all services"
    echo "  stop         - Stop all services"
    echo "  restart      - Restart all services"
    echo "  upgrade      - Pull latest images & restart"
    echo "  logs [svc]   - View logs (default: lobe)"
    echo "  status       - Show service status"
    echo "  search-test  - Test SearXNG search"
    echo "  secrets      - Show secrets file"
    echo "  s3-login     - Show S3 storage credentials"
    echo "  reset        - ⚠️  Stop and DELETE all data"
    echo ""
    echo "Services: lobe, postgresql, redis, searxng, ${S3_SERVICE:-rustfs}"
    ;;
esac
SCRIPTEOF

chmod +x lobe.sh
pok "Helper script: lobe.sh created!"

echo ""
echo "========================================================"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}  🎉 CÀI ĐẶT HOÀN TẤT!${NC}"
else
    echo -e "${YELLOW}  ⚠️  CÀI ĐẶT XONG (có service chưa sẵn sàng)${NC}"
fi
echo ""
echo -e "  LobeHub:          ${PURPLE}http://localhost:3210${NC}"
echo -e "  S3 Console:       ${PURPLE}http://localhost:9001${NC}"
echo -e "  S3 User:          $RUSTFS_ACCESS_KEY"
echo -e "  S3 Pass:          $RUSTFS_SECRET_KEY"
echo ""
echo -e "${CYAN}✨ Tính năng đã bật:${NC}"
echo "  ✓ Knowledge Base (ParadeDB: pgvector + pg_search)"
echo "  ✓ Upload files & photos (S3 + proxy)"
echo "  ✓ Online Search (SearXNG - self-hosted)"
echo "  ✓ Artifacts (SVG, HTML, code rendering)"
echo "  ✓ Image Vision (LLM đọc ảnh upload)"
echo "  ✓ Memory & Chat History (server-side DB)"
echo "  ✓ Web Crawling (naive crawler)"
echo ""
echo -e "${YELLOW}⚠️  QUAN TRỌNG:${NC}"
echo "  • File .env chứa secrets - KHÔNG chia sẻ!"
echo "  • Đường dẫn: $INSTALL_DIR/.env"
echo ""
echo -e "${CYAN}Bắt đầu sử dụng:${NC}"
echo "  1. Truy cập: http://localhost:3210"
echo "  2. Thêm API Key (OpenAI/Claude/Gemini) trong Settings"
echo "  3. Bật 'Smart Search' để test Online Search"
echo "  4. Upload file để test Knowledge Base"
echo ""
echo -e "${CYAN}Quản lý:${NC}"
echo "  • Xem logs:      ./lobe.sh logs"
echo "  • Restart:        ./lobe.sh restart"
echo "  • Upgrade:        ./lobe.sh upgrade"
echo "  • Stop:           ./lobe.sh stop"
echo "  • Start:          ./lobe.sh start"
echo "  • Test search:    ./lobe.sh search-test"
echo "  • Full reset:     ./lobe.sh reset"
echo ""
echo "Support: https://ai.vnrom.net"
echo ""
echo "📝 Ghi chú:"
echo "  • Sử dụng ./lobe.sh để quản lý thay vì docker compose trực tiếp"
echo "  • Secrets được lưu trong .env - backup file này nếu cần!"
echo "  • Test search: ./lobe.sh search-test 'thời tiết hôm nay'"