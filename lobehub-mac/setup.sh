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

# ========================================
# Language Selection / Chọn ngôn ngữ
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
# i18n: All translatable strings
# ========================================
t() {
    local key="$1"
    shift
    local text=""

    case "$key" in
        # Step titles
        step1)
            [[ "$LANG" == "vi" ]] && text="[1/10] Kiểm tra hệ thống Mac" || text="[1/10] Checking Mac system";;
        step2)
            [[ "$LANG" == "vi" ]] && text="[2/10] Khởi tạo thư mục" || text="[2/10] Creating directory";;
        step3)
            [[ "$LANG" == "vi" ]] && text="[3/10] Sinh Secrets (lưu vào .env)" || text="[3/10] Generating Secrets (saving to .env)";;
        step4)
            [[ "$LANG" == "vi" ]] && text="[4/10] Chọn S3 Storage" || text="[4/10] Choose S3 Storage";;
        step5)
            [[ "$LANG" == "vi" ]] && text="[5/10] Lưu cấu hình .env" || text="[5/10] Saving .env config";;
        step6)
            [[ "$LANG" == "vi" ]] && text="[6/10] Tạo file cấu hình" || text="[6/10] Creating config files";;
        step7)
            [[ "$LANG" == "vi" ]] && text="[7/10] Tạo Docker Compose" || text="[7/10] Creating Docker Compose";;
        step8)
            [[ "$LANG" == "vi" ]] && text="[8/10] Khởi động Container ($1)" || text="[8/10] Starting Containers ($1)";;
        step9)
            [[ "$LANG" == "vi" ]] && text="[9/10] Kiểm tra services" || text="[9/10] Verifying services";;
        step10)
            [[ "$LANG" == "vi" ]] && text="[10/10] Hoàn tất" || text="[10/10] Finishing up";;

        # Step 1: System check
        err_macos)
            [[ "$LANG" == "vi" ]] && text="Script chỉ dành cho macOS!" || text="This script is for macOS only!";;
        warn_not_apple_silicon)
            [[ "$LANG" == "vi" ]] && text="Không phải Apple Silicon, hiệu năng sẽ ảnh hưởng" || text="Not Apple Silicon, performance may be affected";;
        ok_apple_silicon)
            [[ "$LANG" == "vi" ]] && text="Kiến trúc: Apple Silicon ARM64 (M1/M2/M3/M4)" || text="Architecture: Apple Silicon ARM64 (M1/M2/M3/M4)";;
        err_docker)
            [[ "$LANG" == "vi" ]] && text="Docker chưa cài đặt!" || text="Docker is not installed!";;
        err_docker_dl)
            [[ "$LANG" == "vi" ]] && text="Tải: https://orbstack.dev hoặc https://docker.com" || text="Download: https://orbstack.dev or https://docker.com";;
        warn_docker_desktop)
            [[ "$LANG" == "vi" ]] && text="Docker Desktop có thể chưa chạy" || text="Docker Desktop may not be running";;
        err_compose)
            [[ "$LANG" == "vi" ]] && text="Docker Compose Plugin chưa cài đặt!" || text="Docker Compose Plugin is not installed!";;
        err_missing)
            [[ "$LANG" == "vi" ]] && text="Thiếu: $1" || text="Missing: $1";;

        # Step 2: Directory
        ok_dir)
            [[ "$LANG" == "vi" ]] && text="Thư mục: $1" || text="Directory: $1";;

        # Step 3: Secrets
        warn_env_found)
            [[ "$LANG" == "vi" ]] && text="Tìm thấy .env cũ, giữ nguyên secrets..." || text="Found existing .env, preserving secrets...";;
        ok_jwks)
            [[ "$LANG" == "vi" ]] && text="Tạo JWKS RSA Key..." || text="Generating JWKS RSA Key...";;

        # Step 4: S3 choice
        s3_option1)
            [[ "$LANG" == "vi" ]] && text="  1) RustFS (mặc định LobeHub, nhẹ, nhanh)" || text="  1) RustFS (LobeHub default, lightweight, fast)";;
        s3_option2)
            [[ "$LANG" == "vi" ]] && text="  2) MinIO  (truyền thống, ổn định)" || text="  2) MinIO  (traditional, stable)";;
        s3_prompt)
            [[ "$LANG" == "vi" ]] && text="Nhập 1 hoặc 2 [1]: " || text="Enter 1 or 2 [1]: ";;
        ok_s3_choice)
            [[ "$LANG" == "vi" ]] && text="Chọn: $1" || text="Selected: $1";;

        # Step 5: Save .env
        env_warning)
            [[ "$LANG" == "vi" ]] && text="# ⚠️  KHÔNG chia sẻ file này! Chứa thông tin nhạy cảm" || text="# ⚠️  DO NOT share this file! Contains sensitive information";;
        ok_env_saved)
            [[ "$LANG" == "vi" ]] && text="Config đã lưu vào .env" || text="Config saved to .env";;

        # Step 6: Config files
        ok_searxng_dl)
            [[ "$LANG" == "vi" ]] && text="Tải searxng-settings.yml từ LobeHub official..." || text="Downloading searxng-settings.yml from LobeHub official...";;
        warn_searxng_fallback)
            [[ "$LANG" == "vi" ]] && text="Không tải được từ GitHub, tạo config mặc định..." || text="Failed to download from GitHub, creating default config...";;

        # Step 8: Start services
        ok_stop_old)
            [[ "$LANG" == "vi" ]] && text="Dừng containers cũ (nếu có)..." || text="Stopping old containers (if any)...";;
        ok_pull)
            [[ "$LANG" == "vi" ]] && text="Tải Docker images (lần đầu sẽ lâu)..." || text="Pulling Docker images (first time may take a while)...";;
        ok_start_infra)
            [[ "$LANG" == "vi" ]] && text="Khởi động PostgreSQL, Redis & SearXNG..." || text="Starting PostgreSQL, Redis & SearXNG...";;
        ok_wait_pg)
            [[ "$LANG" == "vi" ]] && text="Đang chờ PostgreSQL (ParadeDB)..." || text="Waiting for PostgreSQL (ParadeDB)...";;
        ok_pg_ready)
            [[ "$LANG" == "vi" ]] && text="PostgreSQL (ParadeDB): sẵn sàng!" || text="PostgreSQL (ParadeDB): ready!";;
        err_pg)
            [[ "$LANG" == "vi" ]] && text="PostgreSQL không khởi động được!" || text="PostgreSQL failed to start!";;
        ok_wait_redis)
            [[ "$LANG" == "vi" ]] && text="Đang chờ Redis..." || text="Waiting for Redis...";;
        ok_redis_ready)
            [[ "$LANG" == "vi" ]] && text="Redis: sẵn sàng!" || text="Redis: ready!";;
        err_redis)
            [[ "$LANG" == "vi" ]] && text="Redis không khởi động được!" || text="Redis failed to start!";;
        ok_start_rustfs)
            [[ "$LANG" == "vi" ]] && text="Khởi động RustFS..." || text="Starting RustFS...";;
        ok_wait_rustfs)
            [[ "$LANG" == "vi" ]] && text="Đang chờ RustFS..." || text="Waiting for RustFS...";;
        ok_rustfs_ready)
            [[ "$LANG" == "vi" ]] && text="RustFS: sẵn sàng!" || text="RustFS: ready!";;
        err_rustfs)
            [[ "$LANG" == "vi" ]] && text="RustFS không khởi động được!" || text="RustFS failed to start!";;
        ok_start_minio)
            [[ "$LANG" == "vi" ]] && text="Khởi động MinIO..." || text="Starting MinIO...";;
        ok_wait_minio)
            [[ "$LANG" == "vi" ]] && text="Đang chờ MinIO..." || text="Waiting for MinIO...";;
        ok_minio_ready)
            [[ "$LANG" == "vi" ]] && text="MinIO: sẵn sàng!" || text="MinIO: ready!";;
        err_minio)
            [[ "$LANG" == "vi" ]] && text="MinIO không khởi động được!" || text="MinIO failed to start!";;
        ok_init_bucket)
            [[ "$LANG" == "vi" ]] && text="Khởi tạo S3 bucket..." || text="Initializing S3 bucket...";;
        ok_start_lobe)
            [[ "$LANG" == "vi" ]] && text="Khởi động LobeHub..." || text="Starting LobeHub...";;
        ok_wait_lobe)
            [[ "$LANG" == "vi" ]] && text="Đang chờ LobeHub khởi động..." || text="Waiting for LobeHub to start...";;
        ok_lobe_ready)
            [[ "$LANG" == "vi" ]] && text="LobeHub: sẵn sàng!" || text="LobeHub: ready!";;
        warn_lobe_slow)
            [[ "$LANG" == "vi" ]] && text="LobeHub cần thêm thời gian khởi động" || text="LobeHub needs more time to start";;

        # Step 9: Verify
        err_pg_verify)
            [[ "$LANG" == "vi" ]] && text="PostgreSQL: LỖI" || text="PostgreSQL: ERROR";;
        err_redis_verify)
            [[ "$LANG" == "vi" ]] && text="Redis: LỖI" || text="Redis: ERROR";;
        err_rustfs_verify)
            [[ "$LANG" == "vi" ]] && text="RustFS: LỖI" || text="RustFS: ERROR";;
        err_minio_verify)
            [[ "$LANG" == "vi" ]] && text="MinIO: LỖI" || text="MinIO: ERROR";;
        err_searxng_verify)
            [[ "$LANG" == "vi" ]] && text="SearXNG: LỖI (search sẽ không hoạt động)" || text="SearXNG: ERROR (search will not work)";;

        # Step 10: Finish
        finish_ok)
            [[ "$LANG" == "vi" ]] && text="🎉 CÀI ĐẶT HOÀN TẤT!" || text="🎉 INSTALLATION COMPLETE!";;
        finish_warn)
            [[ "$LANG" == "vi" ]] && text="⚠️  CÀI ĐẶT XONG (có service chưa sẵn sàng)" || text="⚠️  INSTALLATION DONE (some services not ready)";;
        features_title)
            [[ "$LANG" == "vi" ]] && text="✨ Tính năng đã bật:" || text="✨ Enabled features:";;
        feat_kb)
            [[ "$LANG" == "vi" ]] && text="  ✓ Knowledge Base (ParadeDB: pgvector + pg_search)" || text="  ✓ Knowledge Base (ParadeDB: pgvector + pg_search)";;
        feat_upload)
            [[ "$LANG" == "vi" ]] && text="  ✓ Upload files & photos (S3 + proxy)" || text="  ✓ Upload files & photos (S3 + proxy)";;
        feat_search)
            [[ "$LANG" == "vi" ]] && text="  ✓ Online Search (SearXNG - self-hosted)" || text="  ✓ Online Search (SearXNG - self-hosted)";;
        feat_artifacts)
            [[ "$LANG" == "vi" ]] && text="  ✓ Artifacts (SVG, HTML, code rendering)" || text="  ✓ Artifacts (SVG, HTML, code rendering)";;
        feat_vision)
            [[ "$LANG" == "vi" ]] && text="  ✓ Image Vision (LLM đọc ảnh upload)" || text="  ✓ Image Vision (LLM reads uploaded images)";;
        feat_memory)
            [[ "$LANG" == "vi" ]] && text="  ✓ Memory & Chat History (server-side DB)" || text="  ✓ Memory & Chat History (server-side DB)";;
        feat_crawl)
            [[ "$LANG" == "vi" ]] && text="  ✓ Web Crawling (naive crawler)" || text="  ✓ Web Crawling (naive crawler)";;
        important_title)
            [[ "$LANG" == "vi" ]] && text="⚠️  QUAN TRỌNG:" || text="⚠️  IMPORTANT:";;
        important_env)
            [[ "$LANG" == "vi" ]] && text="  • File .env chứa secrets - KHÔNG chia sẻ!" || text="  • The .env file contains secrets - DO NOT share!";;
        important_path)
            [[ "$LANG" == "vi" ]] && text="  • Đường dẫn: $1" || text="  • Path: $1";;
        usage_title)
            [[ "$LANG" == "vi" ]] && text="Bắt đầu sử dụng:" || text="Getting started:";;
        usage_1)
            [[ "$LANG" == "vi" ]] && text="  1. Truy cập: http://localhost:3210" || text="  1. Open: http://localhost:3210";;
        usage_2)
            [[ "$LANG" == "vi" ]] && text="  2. Thêm API Key (OpenAI/Claude/Gemini) trong Settings" || text="  2. Add API Key (OpenAI/Claude/Gemini) in Settings";;
        usage_3)
            [[ "$LANG" == "vi" ]] && text="  3. Bật 'Smart Search' để test Online Search" || text="  3. Enable 'Smart Search' to test Online Search";;
        usage_4)
            [[ "$LANG" == "vi" ]] && text="  4. Upload file để test Knowledge Base" || text="  4. Upload a file to test Knowledge Base";;
        manage_title)
            [[ "$LANG" == "vi" ]] && text="Quản lý:" || text="Management:";;
        notes_title)
            [[ "$LANG" == "vi" ]] && text="📝 Ghi chú:" || text="📝 Notes:";;
        note_1)
            [[ "$LANG" == "vi" ]] && text="  • Sử dụng ./lobe.sh để quản lý thay vì docker compose trực tiếp" || text="  • Use ./lobe.sh to manage instead of docker compose directly";;
        note_2)
            [[ "$LANG" == "vi" ]] && text="  • Secrets được lưu trong .env - backup file này nếu cần!" || text="  • Secrets are stored in .env - back up this file if needed!";;
        note_3)
            [[ "$LANG" == "vi" ]] && text="  • Test search: ./lobe.sh search-test 'thời tiết hôm nay'" || text="  • Test search: ./lobe.sh search-test 'weather today'";;
        *)
            text="[MISSING: $key]";;
    esac

    echo "$text"
}

# ========================================
# Step 1: System Check
# ========================================
echo ""
echo "$(t step1)"

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    perr "$(t err_macos)"
    exit 1
fi

# Check Apple Silicon
if [[ "$(uname -m)" != "arm64" ]]; then
    pwn "$(t warn_not_apple_silicon)"
else
    pok "$(t ok_apple_silicon)"
fi

# Check Docker (OrbStack or Docker Desktop)
if ! command -v docker &> /dev/null; then
    perr "$(t err_docker)"
    perr "$(t err_docker_dl)"
    exit 1
fi

# Detect Docker environment
if command -v orb &> /dev/null; then
    pok "OrbStack: OK"
elif docker context ls 2>/dev/null | grep -q orbstack; then
    pok "OrbStack (context): OK"
else
    pwn "$(t warn_docker_desktop)"
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    perr "$(t err_compose)"
    exit 1
fi
pok "Docker Compose: OK"

# Dependencies
for c in openssl python3 curl; do
    if ! command -v $c &> /dev/null; then
        perr "$(t err_missing "$c")"
        exit 1
    fi
done
pok "Dependencies: OK"

# ========================================
# Step 2: Directory
# ========================================
echo ""
echo "$(t step2)"

INSTALL_DIR="$HOME/lobehub-mac"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(t ok_dir "$INSTALL_DIR")"

# ========================================
# Step 3: Generate Secrets & Save to .env
# ========================================
echo ""
echo "$(t step3)"

# Preserve existing secrets if .env exists
if [ -f .env ]; then
    pwn "$(t warn_env_found)"
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
    pok "$(t ok_jwks)"
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
echo "$(t step4)"
echo ""
echo "$(t s3_option1)"
echo "$(t s3_option2)"
echo ""
read -p "$(t s3_prompt)" S3_CHOICE

S3_CHOICE=${S3_CHOICE:-1}

if [[ "$S3_CHOICE" == "2" ]]; then
    S3_SERVICE="minio"
    S3_SERVICE_NAME="MinIO"
else
    S3_SERVICE="rustfs"
    S3_SERVICE_NAME="RustFS"
fi

pok "$(t ok_s3_choice "$S3_SERVICE_NAME")"

# ========================================
# Step 5: Save .env
# ========================================
echo ""
echo "$(t step5)"

cat > .env << ENVEOF
# =================================================================
# LobeHub v3.0 - Configuration & Secrets
$(t env_warning)
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

pok "$(t ok_env_saved)"

# ========================================
# Step 6: Configuration Files
# ========================================
echo ""
echo "$(t step6)"

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
pok "$(t ok_searxng_dl)"
SEARXNG_URL="https://raw.githubusercontent.com/lobehub/lobe-chat/HEAD/docker-compose/deploy/searxng-settings.yml"
if curl -sfL "$SEARXNG_URL" -o searxng-settings.yml; then
    pok "searxng-settings.yml: OK (official LobeHub config)"
else
    pwn "$(t warn_searxng_fallback)"
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
echo "$(t step7)"

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
echo "$(t step8 "$S3_SERVICE_NAME + SearXNG")"

cd "$INSTALL_DIR"

# Stop any existing containers
pok "$(t ok_stop_old)"
docker compose down 2>/dev/null || true

# Pull images
pok "$(t ok_pull)"
docker compose pull

# Start infrastructure first
pok "$(t ok_start_infra)"
docker compose up -d network-service postgresql redis searxng

# Wait for PostgreSQL
pok "$(t ok_wait_pg)"
for i in {1..60}; do
    if docker exec lobe-mac-postgres pg_isready -U postgres &>/dev/null; then
        pok "$(t ok_pg_ready)"
        break
    fi
    [ $i -eq 60 ] && { perr "$(t err_pg)"; exit 1; }
    sleep 2
done

# Wait for Redis
pok "$(t ok_wait_redis)"
for i in {1..30}; do
    if docker exec lobe-mac-redis redis-cli ping &>/dev/null; then
        pok "$(t ok_redis_ready)"
        break
    fi
    [ $i -eq 30 ] && { perr "$(t err_redis)"; exit 1; }
    sleep 2
done

# Start S3 Storage
if [[ "$S3_SERVICE" == "rustfs" ]]; then
    pok "$(t ok_start_rustfs)"
    docker compose up -d rustfs
    pok "$(t ok_wait_rustfs)"
    for i in {1..60}; do
        if curl -sf http://localhost:9000/health &>/dev/null; then
            pok "$(t ok_rustfs_ready)"
            break
        fi
        [ $i -eq 60 ] && { perr "$(t err_rustfs)"; exit 1; }
        sleep 2
    done
    # Init bucket
    pok "$(t ok_init_bucket)"
    docker compose up rustfs-init
else
    pok "$(t ok_start_minio)"
    docker compose up -d minio
    pok "$(t ok_wait_minio)"
    for i in {1..60}; do
        if curl -sf http://localhost:9000/minio/health/live &>/dev/null; then
            pok "$(t ok_minio_ready)"
            break
        fi
        [ $i -eq 60 ] && { perr "$(t err_minio)"; exit 1; }
        sleep 2
    done
    # Init bucket
    pok "$(t ok_init_bucket)"
    docker compose up minio-init
fi

# Start LobeHub
pok "$(t ok_start_lobe)"
docker compose up -d lobe

# Wait for LobeHub
pok "$(t ok_wait_lobe)"
for i in {1..120}; do
    if curl -sf http://localhost:3210 >/dev/null 2>&1; then
        pok "$(t ok_lobe_ready)"
        break
    fi
    [ $i -eq 120 ] && pwn "$(t warn_lobe_slow)"
    sleep 2
done

# ========================================
# Step 9: Verify Services
# ========================================
echo ""
echo "$(t step9)"

ALL_OK=true

docker exec lobe-mac-postgres pg_isready -U postgres &>/dev/null && pok "PostgreSQL (ParadeDB): OK" || { perr "$(t err_pg_verify)"; ALL_OK=false; }
docker exec lobe-mac-redis redis-cli ping &>/dev/null && pok "Redis: OK" || { perr "$(t err_redis_verify)"; ALL_OK=false; }

if [[ "$S3_SERVICE" == "rustfs" ]]; then
    curl -sf http://localhost:9000/health &>/dev/null && pok "RustFS: OK" || { perr "$(t err_rustfs_verify)"; ALL_OK=false; }
else
    curl -sf http://localhost:9000/minio/health/live &>/dev/null && pok "MinIO: OK" || { perr "$(t err_minio_verify)"; ALL_OK=false; }
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
    perr "$(t err_searxng_verify)"
    ALL_OK=false
fi

curl -sf http://localhost:3210 >/dev/null && pok "LobeHub: OK" || { perr "LobeHub: ERROR"; ALL_OK=false; }

# ========================================
# Step 10: Create Helper Script & Finish
# ========================================
echo ""
echo "$(t step10)"

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
    echo "⚠️  This will DELETE ALL data (database, uploads, secrets)..."
    read -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" == "yes" ]]; then
      docker compose down -v
      rm -rf ./data
      echo "✅ All data deleted!"
    else
      echo "❌ Cancelled."
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
    echo -e "${GREEN}  $(t finish_ok)${NC}"
else
    echo -e "${YELLOW}  $(t finish_warn)${NC}"
fi
echo ""
echo -e "  LobeHub:          ${PURPLE}http://localhost:3210${NC}"
echo -e "  S3 Console:       ${PURPLE}http://localhost:9001${NC}"
echo -e "  S3 User:          $RUSTFS_ACCESS_KEY"
echo -e "  S3 Pass:          $RUSTFS_SECRET_KEY"
echo ""
echo -e "${CYAN}$(t features_title)${NC}"
echo "$(t feat_kb)"
echo "$(t feat_upload)"
echo "$(t feat_search)"
echo "$(t feat_artifacts)"
echo "$(t feat_vision)"
echo "$(t feat_memory)"
echo "$(t feat_crawl)"
echo ""
echo -e "${YELLOW}$(t important_title)${NC}"
echo "$(t important_env)"
echo "$(t important_path "$INSTALL_DIR/.env")"
echo ""
echo -e "${CYAN}$(t usage_title)${NC}"
echo "$(t usage_1)"
echo "$(t usage_2)"
echo "$(t usage_3)"
echo "$(t usage_4)"
echo ""
echo -e "${CYAN}$(t manage_title)${NC}"
echo "  • Logs:           ./lobe.sh logs"
echo "  • Restart:        ./lobe.sh restart"
echo "  • Upgrade:        ./lobe.sh upgrade"
echo "  • Stop:           ./lobe.sh stop"
echo "  • Start:          ./lobe.sh start"
echo "  • Test search:    ./lobe.sh search-test"
echo "  • Full reset:     ./lobe.sh reset"
echo ""
echo "Support: https://vnrom.net"
echo ""
echo "$(t notes_title)"
echo "$(t note_1)"
echo "$(t note_2)"
echo "$(t note_3)"