#!/bin/bash
################################################################
# LobeHub v3.0 Auto-Install for Raspberry Pi (4/5)
# Full features: Knowledge Base, Search, Upload, Artifacts, ...
# Based on official lobehub/lobe-chat docker-compose deployment
# Optimized for ARM64 with memory limits
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
    echo "      LobeHub Raspberry Pi Setup v3.0 (ARM64)"
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
# Network Mode Selection
# ========================================

# Auto-detect LAN IP
LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
[ -z "$LAN_IP" ] && LAN_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}' || echo "")

echo ""
if [[ "$LANG" == "vi" ]]; then
    echo "  Chế độ truy cập:"
    echo ""
    echo "    1) Localhost (chỉ truy cập từ máy này)"
    if [ -n "$LAN_IP" ]; then
        echo "    2) LAN / Home Server (truy cập từ các thiết bị khác: $LAN_IP) (mặc định)"
    else
        echo "    2) LAN / Home Server (nhập IP thủ công) (mặc định)"
    fi
else
    echo "  Access mode:"
    echo ""
    echo "    1) Localhost only (access from this machine)"
    if [ -n "$LAN_IP" ]; then
        echo "    2) LAN / Home Server (access from other devices: $LAN_IP) (default)"
    else
        echo "    2) LAN / Home Server (enter IP manually) (default)"
    fi
fi
echo ""
read -p "  Enter 1 or 2 [2]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-2}

if [[ "$NET_CHOICE" == "1" ]]; then
    NETWORK_MODE="localhost"
    LAN_IP="localhost"
    APP_URL="http://localhost:3210"
    S3_PUBLIC_ENDPOINT="http://localhost:9000"
else
    NETWORK_MODE="lan"
    if [ -n "$LAN_IP" ]; then
        if [[ "$LANG" == "vi" ]]; then
            echo ""
            read -p "  Sử dụng IP $LAN_IP? (Enter = OK, hoặc nhập IP khác): " CUSTOM_IP
        else
            echo ""
            read -p "  Use IP $LAN_IP? (Enter = OK, or type a different IP): " CUSTOM_IP
        fi
        [ -n "$CUSTOM_IP" ] && LAN_IP="$CUSTOM_IP"
    else
        if [[ "$LANG" == "vi" ]]; then
            read -p "  Nhập IP LAN của Raspberry Pi: " LAN_IP
        else
            read -p "  Enter the Raspberry Pi's LAN IP address: " LAN_IP
        fi
        if [ -z "$LAN_IP" ]; then
            perr "IP is required for LAN mode!"
            exit 1
        fi
    fi
    APP_URL="http://${LAN_IP}:3210"
    S3_PUBLIC_ENDPOINT="http://${LAN_IP}:9000"
fi

if [[ "$LANG" == "vi" ]]; then
    pok "Chế độ: $( [[ "$NETWORK_MODE" == "lan" ]] && echo "LAN ($LAN_IP)" || echo "Localhost" )"
else
    pok "Mode: $( [[ "$NETWORK_MODE" == "lan" ]] && echo "LAN ($LAN_IP)" || echo "Localhost" )"
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
            [[ "$LANG" == "vi" ]] && text="[1/10] Kiểm tra hệ thống" || text="[1/10] Checking system";;
        step2)
            [[ "$LANG" == "vi" ]] && text="[2/10] Cấu hình Swap & Docker" || text="[2/10] Configuring Swap & Docker";;
        step3)
            [[ "$LANG" == "vi" ]] && text="[3/10] Khởi tạo thư mục & Sinh Secrets" || text="[3/10] Creating directory & Generating Secrets";;
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
        err_arch)
            [[ "$LANG" == "vi" ]] && text="Script yêu cầu ARM64 (aarch64)!" || text="This script requires ARM64 (aarch64)!";;
        err_disk)
            [[ "$LANG" == "vi" ]] && text="Ổ đĩa chỉ còn ${1}GB < 8GB tối thiểu!" || text="Disk only has ${1}GB < 8GB minimum!";;
        err_missing)
            [[ "$LANG" == "vi" ]] && text="Thiếu: $1" || text="Missing: $1";;

        # Step 2: Swap & Docker
        ok_swap)
            [[ "$LANG" == "vi" ]] && text="Swap: $1" || text="Swap: $1";;
        warn_logout)
            [[ "$LANG" == "vi" ]] && text="Cần logout/login lại để dùng docker không sudo" || text="Need to logout/login to use docker without sudo";;

        # Step 3: Secrets
        warn_env_found)
            [[ "$LANG" == "vi" ]] && text="Tìm thấy .env cũ, giữ nguyên secrets..." || text="Found existing .env, preserving secrets...";;
        ok_jwks)
            [[ "$LANG" == "vi" ]] && text="Sinh JWKS RSA Key..." || text="Generating JWKS RSA Key...";;

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
            [[ "$LANG" == "vi" ]] && text="Tải Docker images (lần đầu sẽ lâu trên Pi)..." || text="Pulling Docker images (first time is slow on Pi)...";;
        ok_start_infra)
            [[ "$LANG" == "vi" ]] && text="Khởi động PostgreSQL, Redis & SearXNG..." || text="Starting PostgreSQL, Redis & SearXNG...";;
        ok_wait_pg)
            [[ "$LANG" == "vi" ]] && text="Đang chờ PostgreSQL..." || text="Waiting for PostgreSQL...";;
        ok_pg_ready)
            [[ "$LANG" == "vi" ]] && text="PostgreSQL: sẵn sàng!" || text="PostgreSQL: ready!";;
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
            [[ "$LANG" == "vi" ]] && text="Đang chờ LobeHub (1-3 phút trên Pi)..." || text="Waiting for LobeHub (1-3 min on Pi)...";;
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
            [[ "$LANG" == "vi" ]] && text="  ✓ Knowledge Base (pgvector)" || text="  ✓ Knowledge Base (pgvector)";;
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
        feat_auth)
            [[ "$LANG" == "vi" ]] && text="  ✓ Better Auth (Email/Password)" || text="  ✓ Better Auth (Email/Password)";;
        important_title)
            [[ "$LANG" == "vi" ]] && text="⚠️  QUAN TRỌNG:" || text="⚠️  IMPORTANT:";;
        important_env)
            [[ "$LANG" == "vi" ]] && text="  • File .env chứa secrets - KHÔNG chia sẻ!" || text="  • The .env file contains secrets - DO NOT share!";;
        important_path)
            [[ "$LANG" == "vi" ]] && text="  • Đường dẫn: $1" || text="  • Path: $1";;
        usage_title)
            [[ "$LANG" == "vi" ]] && text="Bắt đầu sử dụng:" || text="Getting started:";;
        usage_1)
            [[ "$LANG" == "vi" ]] && text="  1. Truy cập: $APP_URL" || text="  1. Open: $APP_URL";;
        usage_2)
            [[ "$LANG" == "vi" ]] && text="  2. Tạo tài khoản (email + password)" || text="  2. Create an account (email + password)";;
        usage_3)
            [[ "$LANG" == "vi" ]] && text="  3. Thêm API Key (OpenAI/Claude/Gemini) trong Settings" || text="  3. Add API Key (OpenAI/Claude/Gemini) in Settings";;
        usage_4)
            [[ "$LANG" == "vi" ]] && text="  4. Bật 'Smart Search' để test Online Search" || text="  4. Enable 'Smart Search' to test Online Search";;
        manage_title)
            [[ "$LANG" == "vi" ]] && text="Quản lý:" || text="Management:";;
        notes_title)
            [[ "$LANG" == "vi" ]] && text="📝 Ghi chú:" || text="📝 Notes:";;
        note_1)
            [[ "$LANG" == "vi" ]] && text="  • Sử dụng ./lobe.sh để quản lý thay vì docker compose trực tiếp" || text="  • Use ./lobe.sh to manage instead of docker compose directly";;
        note_2)
            [[ "$LANG" == "vi" ]] && text="  • Secrets được lưu trong .env - backup file này nếu cần!" || text="  • Secrets are stored in .env - back up this file if needed!";;
        note_3)
            [[ "$LANG" == "vi" ]] && text="  • Test search: ./lobe.sh search-test 'weather today'" || text="  • Test search: ./lobe.sh search-test 'weather today'";;
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

# Check ARM64
if [[ "$(uname -m)" != "aarch64" ]]; then
    perr "$(t err_arch)"
    exit 1
fi
pok "Arch: aarch64 (ARM64)"

# Check RAM
MEM=$(free -m | awk '/Mem/{print $2}')
pok "RAM: ${MEM}MB"

# Check Disk
DSK=$(df -BG "$HOME" | awk 'NR==2{gsub(/G/,"",$4);print $4}')
if [ "${DSK:-0}" -lt 8 ]; then
    perr "$(t err_disk "$DSK")"
    exit 1
fi
pok "Disk: ${DSK}GB"

# Dependencies
for c in openssl python3 curl; do
    if ! command -v $c &> /dev/null; then
        perr "$(t err_missing "$c")"
        exit 1
    fi
done
pok "Dependencies: OK"

# ========================================
# Step 2: Swap & Docker
# ========================================
echo ""
echo "$(t step2)"

# Configure swap (Pi-specific)
if command -v dphys-swapfile &>/dev/null; then
    CS=$(grep 'CONF_SWAPSIZE=' /etc/dphys-swapfile 2>/dev/null | cut -d= -f2)
    if [ "${CS:-0}" -lt 2048 ]; then
        sudo dphys-swapfile swapoff 2>/dev/null || true
        sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
        sudo dphys-swapfile setup && sudo dphys-swapfile swapon
        pok "$(t ok_swap "2048MB")"
    else
        pok "$(t ok_swap "${CS}MB (OK)")"
    fi
fi

# Install Docker if needed
if ! command -v docker &>/dev/null; then
    pok "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
    sudo usermod -aG docker "$USER"
    pwn "$(t warn_logout)"
else
    pok "Docker: OK"
fi

# Install Docker Compose plugin if needed
if ! docker compose version &>/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin
fi
pok "Docker Compose: OK"

# ========================================
# Step 3: Directory & Secrets
# ========================================
echo ""
echo "$(t step3)"

INSTALL_DIR="$HOME/lobehub"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "Directory: $INSTALL_DIR"

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

    JWKS_KEY=$(python3 -c "
import subprocess,json,base64,secrets,re
def b64u(n):
    l=(n.bit_length()+7)//8
    return base64.urlsafe_b64encode(n.to_bytes(l,'big')).rstrip(b'=').decode()
r=subprocess.run(['openssl','rsa','-in','$TMP_PEM','-text','-noout'],capture_output=True,text=True)
t=r.stdout
def xh(f):
    m=re.search(f+r':\s*\n([\s0-9a-f:]+)',t,re.DOTALL)
    if not m: return 0
    return int(m.group(1).replace(' ','').replace('\n','').replace(':',''),16)
em=re.search(r'publicExponent:\s+(\d+)',t)
e=int(em.group(1)) if em else 65537
n=xh('modulus');d=xh('privateExponent');p=xh('prime1')
q=xh('prime2');dp=xh('exponent1');dq=xh('exponent2');qi=xh('coefficient')
kid=secrets.token_hex(8)
jwk={'kty':'RSA','use':'sig','alg':'RS256','kid':kid,
     'n':b64u(n),'e':b64u(e),'d':b64u(d),'p':b64u(p),
     'q':b64u(q),'dp':b64u(dp),'dq':b64u(dq),'qi':b64u(qi)}
print(json.dumps({'keys':[jwk]},separators=(',',':')))
" 2>/dev/null)

    rm -f "$TMP_PEM"
    [ -z "$JWKS_KEY" ] && { perr "JWKS generation failed"; exit 1; }
    pok "JWKS Key: OK"
else
    pok "JWKS Key: reused"
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
# LobeHub v3.0 (Raspberry Pi) - Configuration & Secrets
$(t env_warning)
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Network mode: $NETWORK_MODE ($LAN_IP)
# =================================================================

# ===========================
# ====== Preset config ======
# ===========================
LOBE_PORT=3210
RUSTFS_PORT=9000
APP_URL=$APP_URL

# Auth Secrets
AUTH_SECRET=$AUTH_SECRET
KEY_VAULTS_SECRET=$KEY_VAULTS_SECRET
JWKS_KEY=$JWKS_KEY

# Database (PostgreSQL + pgvector)
LOBE_DB_NAME=lobechat
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# S3 Storage ($S3_SERVICE_NAME)
RUSTFS_ACCESS_KEY=$RUSTFS_ACCESS_KEY
RUSTFS_SECRET_KEY=$RUSTFS_SECRET_KEY
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
S3_ENDPOINT=$S3_PUBLIC_ENDPOINT
RUSTFS_LOBE_BUCKET=lobe

# S3 Storage choice
S3_SERVICE=$S3_SERVICE

# AI Keys (uncomment to enable)
# OPENAI_API_KEY=sk-xxx
# ANTHROPIC_API_KEY=sk-ant-xxx
# OLLAMA_PROXY_URL=http://host.docker.internal:11434
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
# ---- RustFS Docker Compose (Pi optimized) ----
cat > docker-compose.yml << 'DCOMPOSE'
name: lobehub-pi

services:
  network-service:
    image: alpine:3.20
    container_name: lobe-network
    restart: always
    ports:
      - '${LOBE_PORT:-3210}:3210'
      - '${RUSTFS_PORT:-9000}:9000'
      - '9001:9001'
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: tail -f /dev/null
    networks:
      - lobe-network

  postgresql:
    image: pgvector/pgvector:pg16
    container_name: lobe-pi-postgres
    restart: always
    volumes:
      - pg_data:/var/lib/postgresql/data
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
    deploy:
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 256M

  redis:
    image: redis:7-alpine
    container_name: lobe-pi-redis
    restart: always
    command: redis-server --save 60 1000 --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - lobe-network
    deploy:
      resources:
        limits:
          memory: 192M

  rustfs:
    image: rustfs/rustfs:latest
    container_name: lobe-pi-rustfs
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
    container_name: lobe-pi-rustfs-init
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
    image: searxng/searxng:latest
    container_name: lobe-pi-searxng
    restart: always
    volumes:
      - ./searxng-settings.yml:/etc/searxng/settings.yml:ro
    environment:
      - SEARXNG_SETTINGS_FILE=/etc/searxng/settings.yml
    networks:
      - lobe-network
    deploy:
      resources:
        limits:
          memory: 256M

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobe-pi-app
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
    deploy:
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 512M

volumes:
  pg_data:
  redis_data:
  rustfs_data:

networks:
  lobe-network:
    driver: bridge
DCOMPOSE

else
# ---- MinIO Docker Compose (Pi optimized) ----
cat > docker-compose.yml << 'DCOMPOSE'
name: lobehub-pi

services:
  network-service:
    image: alpine:3.20
    container_name: lobe-network
    restart: always
    ports:
      - '${LOBE_PORT:-3210}:3210'
      - '${RUSTFS_PORT:-9000}:9000'
      - '9001:9001'
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: tail -f /dev/null
    networks:
      - lobe-network

  postgresql:
    image: pgvector/pgvector:pg16
    container_name: lobe-pi-postgres
    restart: always
    volumes:
      - pg_data:/var/lib/postgresql/data
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
    deploy:
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 256M

  redis:
    image: redis:7-alpine
    container_name: lobe-pi-redis
    restart: always
    command: redis-server --save 60 1000 --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - lobe-network
    deploy:
      resources:
        limits:
          memory: 192M

  minio:
    image: minio/minio:latest
    container_name: lobe-pi-minio
    network_mode: "service:network-service"
    environment:
      - MINIO_ROOT_USER=${S3_ACCESS_KEY}
      - MINIO_ROOT_PASSWORD=${S3_SECRET_KEY}
      - MINIO_API_CORS_ORIGIN=${APP_URL}
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
    container_name: lobe-pi-minio-init
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
    image: searxng/searxng:latest
    container_name: lobe-pi-searxng
    restart: always
    volumes:
      - ./searxng-settings.yml:/etc/searxng/settings.yml:ro
    environment:
      - SEARXNG_SETTINGS_FILE=/etc/searxng/settings.yml
    networks:
      - lobe-network
    deploy:
      resources:
        limits:
          memory: 256M

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobe-pi-app
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
    deploy:
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 512M

volumes:
  pg_data:
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
docker compose pull 2>&1 | tail -8 || pwn "Will pull on start"

# Start infrastructure first
pok "$(t ok_start_infra)"
docker compose up -d network-service postgresql redis searxng

# Wait for PostgreSQL
pok "$(t ok_wait_pg)"
for i in {1..60}; do
    if docker exec lobe-pi-postgres pg_isready -U postgres &>/dev/null; then
        pok "$(t ok_pg_ready)"
        break
    fi
    [ $i -eq 60 ] && { perr "$(t err_pg)"; exit 1; }
    sleep 2
done

# Wait for Redis
pok "$(t ok_wait_redis)"
for i in {1..30}; do
    if docker exec lobe-pi-redis redis-cli ping &>/dev/null; then
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
    # Progress indicator every 30s
    [ $((i % 15)) -eq 0 ] && pok "Starting... (${i}s)"
    sleep 2
done

# ========================================
# Step 9: Verify Services
# ========================================
echo ""
echo "$(t step9)"

ALL_OK=true

docker exec lobe-pi-postgres pg_isready -U postgres &>/dev/null && pok "PostgreSQL (pgvector): OK" || { perr "$(t err_pg_verify)"; ALL_OK=false; }
docker exec lobe-pi-redis redis-cli ping &>/dev/null && pok "Redis: OK" || { perr "$(t err_redis_verify)"; ALL_OK=false; }

if [[ "$S3_SERVICE" == "rustfs" ]]; then
    curl -sf http://localhost:9000/health &>/dev/null && pok "RustFS: OK" || { perr "$(t err_rustfs_verify)"; ALL_OK=false; }
else
    curl -sf http://localhost:9000/minio/health/live &>/dev/null && pok "MinIO: OK" || { perr "$(t err_minio_verify)"; ALL_OK=false; }
fi

# Test SearXNG
SEARXNG_OK=false
for i in {1..10}; do
    if docker exec lobe-pi-searxng wget -qO- http://localhost:8080 &>/dev/null; then
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
# LobeHub Helper Script v3.0 (Raspberry Pi)

cd "$(dirname "$0")"

case "$1" in
  start)
    echo "🚀 Starting LobeHub..."
    docker compose up -d
    APP=$(grep '^APP_URL=' .env 2>/dev/null | cut -d= -f2- || echo 'http://localhost:3210')
    echo "✅ Started! Access: $APP"
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
    RESULT=$(docker exec lobe-pi-searxng wget -qO- "http://localhost:8080/search?q=${QUERY}&format=json" 2>/dev/null)
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
    echo "Console: http://$(hostname -I | awk '{print $1}'):9001"
    ;;
  *)
    echo "LobeHub Helper v3.0 (Raspberry Pi)"
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
echo -e "  LobeHub:          ${PURPLE}${APP_URL}${NC}"
echo -e "  S3 Console:       ${PURPLE}http://${LAN_IP}:9001${NC}"
echo -e "  S3 User:          $RUSTFS_ACCESS_KEY"
echo -e "  S3 Pass:          $RUSTFS_SECRET_KEY"
if [[ "$NETWORK_MODE" == "lan" ]]; then
    echo ""
    if [[ "$LANG" == "vi" ]]; then
        echo -e "${CYAN}🌐 Truy cập LAN:${NC}"
        echo "  Các thiết bị trong cùng mạng WiFi/LAN có thể truy cập:"
        echo -e "  LobeHub:  ${PURPLE}${APP_URL}${NC}"
        echo -e "  S3:       ${PURPLE}http://${LAN_IP}:9001${NC}"
    else
        echo -e "${CYAN}🌐 LAN Access:${NC}"
        echo "  Devices on the same WiFi/LAN network can access:"
        echo -e "  LobeHub:  ${PURPLE}${APP_URL}${NC}"
        echo -e "  S3:       ${PURPLE}http://${LAN_IP}:9001${NC}"
    fi
fi
echo ""
echo -e "${CYAN}$(t features_title)${NC}"
echo "$(t feat_kb)"
echo "$(t feat_upload)"
echo "$(t feat_search)"
echo "$(t feat_artifacts)"
echo "$(t feat_vision)"
echo "$(t feat_memory)"
echo "$(t feat_crawl)"
echo "$(t feat_auth)"
echo ""
echo -e "${YELLOW}$(t important_title)${NC}"
echo "$(t important_env)"
echo "$(t important_path "$INSTALL_DIR/.env")"
if [[ "$NETWORK_MODE" == "lan" ]]; then
    if [[ "$LANG" == "vi" ]]; then
        echo "  • Nếu IP LAN thay đổi, sửa APP_URL trong .env và restart"
    else
        echo "  • If your LAN IP changes, update APP_URL in .env and restart"
    fi
fi
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
