#!/bin/bash
################################################################
# LobeHub v2.0+ Auto-Install for Mac (M1/M2/M3/M4)
# Optimized for OrbStack 🚀
# Version 1.0 (by duynghien)
################################################################
set -euo pipefail

# Define Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
TOTAL_STEPS=6

pban() { echo -e "\n${PURPLE}══ $1 ══${NC}"; }
pstp() { echo -e "\n${BLUE}[$1/$TOTAL_STEPS] $2${NC}"; }
pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; }

# Clear screen and show header
clear
echo "================================================================"
echo -e "${PURPLE}"
echo "      _                         _     _             ";
echo "     | |                       | |   (_)            ";
echo "   __| |_   _ _   _ ____   ____| |__  _ _____ ____  ";
echo "  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ ";
echo " ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |";
echo "  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|";
echo "             (____/      (_____|                    ";
echo ""
echo "               LobeHub Mac M4 + OrbStack Setup"
echo "                        https://ai.vnrom.net"
echo -e "${NC}"
echo "================================================================"

########################################
# 1. ENVIRONMENT CHECK
########################################
pstp 1 "Kiểm tra hệ thống Mac"
if [[ "$(uname)" != "Darwin" ]]; then
    perr "Script này chỉ dành cho macOS!"
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    pwn "Hệ thống không phải Apple Silicon (M1/M2/M3/M4), hiệu năng có thể bị ảnh hưởng."
else
    pok "Kiến trúc: Apple Silicon (ARM64)"
fi

# Check OrbStack
if ! command -v orb &> /dev/null && ! docker context ls | grep -q "orbstack"; then
    perr "Không tìm thấy OrbStack. Vui lòng cài đặt tại: https://orbstack.dev"
    exit 1
fi
pok "OrbStack: OK"

# Check dependencies
for c in openssl python3 curl; do
  command -v $c &>/dev/null || { perr "Thiếu công cụ: $c. Vui lòng cài đặt qua Brew."; exit 1; }
done
pok "Dependencies: OK"

########################################
# 2. DIRECTORY & IP
########################################
pstp 2 "Khởi tạo thư mục & IP"
INSTALL_DIR="$HOME/lobehub-mac"
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"
pok "Thư mục cài đặt: $INSTALL_DIR"

# Detect IP (macOS style)
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
pok "IP nội bộ: $IP"

########################################
# 3. SECRETS & JWKS
########################################
pstp 3 "Sinh Secrets & JWKS Key"
if [ -f .env ]; then
  pwn ".env tồn tại, sử dụng lại các bí mật cũ."
  gv() { grep "^$1=" .env 2>/dev/null|cut -d= -f2-; }
  KEY_VAULTS_SECRET=$(gv KEY_VAULTS_SECRET)
  AUTH_SECRET=$(gv AUTH_SECRET)
  POSTGRES_PASSWORD=$(gv POSTGRES_PASSWORD)
  RUSTFS_ACCESS_KEY=$(gv RUSTFS_ACCESS_KEY)
  RUSTFS_SECRET_KEY=$(gv RUSTFS_SECRET_KEY)
  JWKS_KEY=$(gv JWKS_KEY)
fi

[ -z "${KEY_VAULTS_SECRET:-}" ] && KEY_VAULTS_SECRET=$(openssl rand -base64 32)
[ -z "${AUTH_SECRET:-}" ] && AUTH_SECRET=$(openssl rand -base64 32)
[ -z "${POSTGRES_PASSWORD:-}" ] && POSTGRES_PASSWORD=$(openssl rand -base64 16|tr -d '=+/')
[ -z "${RUSTFS_ACCESS_KEY:-}" ] && RUSTFS_ACCESS_KEY="admin"
[ -z "${RUSTFS_SECRET_KEY:-}" ] && RUSTFS_SECRET_KEY=$(openssl rand -base64 16|tr -d '=+/')
SEARXNG_SECRET=$(openssl rand -hex 32)

if [ -z "${JWKS_KEY:-}" ]; then
  pok "Đang tạo JWKS RSA Key..."
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
  pok "JWKS Key: OK"
else
  pok "JWKS Key: Reused"
fi

########################################
# 4. CONFIGURATION FILES
########################################
pstp 4 "Tạo file Docker Compose & Config"

cat > .env <<ENVEOF
# LobeHub v2.0+ Mac Edition — $(date '+%Y-%m-%d %H:%M')
LOBE_PORT=3210
RUSTFS_PORT=9000
APP_URL=http://${IP}:3210

# Auth
AUTH_SECRET=${AUTH_SECRET}
KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET}
JWKS_KEY=${JWKS_KEY}

# PostgreSQL
LOBE_DB_NAME=lobechat
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# RustFS S3
RUSTFS_ACCESS_KEY=${RUSTFS_ACCESS_KEY}
RUSTFS_SECRET_KEY=${RUSTFS_SECRET_KEY}
RUSTFS_LOBE_BUCKET=lobe
S3_ENDPOINT=http://localhost:9000
S3_PUBLIC_DOMAIN=http://${IP}:9000

# AI Keys (Uncomment to use)
# OPENAI_API_KEY=sk-xxx
# ANTHROPIC_API_KEY=sk-ant-xxx
ENVEOF

cat > bucket.config.json <<BEOF
{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"AWS":["*"]},
    "Action":["s3:GetObject"],
    "Resource":["arn:aws:s3:::lobe/*"]
  }]
}
BEOF

cat > docker-compose.yml <<'DEOF'
name: lobehub-mac
services:
  network-service:
    image: alpine:3.20
    container_name: lobe-mac-network
    restart: always
    ports:
      - '${RUSTFS_PORT}:9000'
      - '9001:9001'
      - '${LOBE_PORT}:3210'
    extra_hosts:
      - "host.docker.internal:host-gateway"
    command: tail -f /dev/null
    networks:
      - lobe-network

  postgresql:
    image: pgvector/pgvector:pg16
    container_name: lobe-mac-postgres
    restart: always
    volumes:
      - pg_data:/var/lib/postgresql/data
    environment:
      - 'POSTGRES_DB=${LOBE_DB_NAME}'
      - 'POSTGRES_PASSWORD=${POSTGRES_PASSWORD}'
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres']
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - lobe-network

  redis:
    image: redis:7-alpine
    container_name: lobe-mac-redis
    restart: always
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - lobe-network

  rustfs:
    image: rustfs/rustfs:latest
    container_name: lobe-mac-rustfs
    network_mode: 'service:network-service'
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
    command: ["--access-key","${RUSTFS_ACCESS_KEY}","--secret-key","${RUSTFS_SECRET_KEY}","/data"]

  rustfs-init:
    image: minio/mc:latest
    container_name: lobe-mac-rustfs-init
    depends_on:
      rustfs:
        condition: service_healthy
    volumes:
      - ./bucket.config.json:/bucket.config.json:ro
    entrypoint: /bin/sh
    command: -c 'set -eux; mc alias set rustfs "http://network-service:9000" "${RUSTFS_ACCESS_KEY}" "${RUSTFS_SECRET_KEY}"; mc mb "rustfs/lobe" --ignore-existing; mc anonymous set-json "/bucket.config.json" "rustfs/lobe";'
    restart: "no"
    networks:
      - lobe-network

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobe-mac-app
    network_mode: 'service:network-service'
    restart: always
    depends_on:
      postgresql:
        condition: service_healthy
      rustfs-init:
        condition: service_completed_successfully
      redis:
        condition: service_healthy
    environment:
      - 'AUTH_SECRET=${AUTH_SECRET}'
      - 'KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET}'
      - 'JWKS_KEY=${JWKS_KEY}'
      - 'DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgresql:5432/${LOBE_DB_NAME}'
      - 'S3_ENDPOINT=http://localhost:9000'
      - 'S3_PUBLIC_DOMAIN=${S3_PUBLIC_DOMAIN}'
      - 'S3_BUCKET=${RUSTFS_LOBE_BUCKET}'
      - 'S3_ENABLE_PATH_STYLE=1'
      - 'S3_ACCESS_KEY_ID=${RUSTFS_ACCESS_KEY}'
      - 'S3_SECRET_ACCESS_KEY=${RUSTFS_SECRET_KEY}'
      - 'REDIS_URL=redis://redis:6379'
      - 'REDIS_PREFIX=lobechat'
    env_file:
      - .env

volumes:
  pg_data:
  redis_data:
  rustfs_data:

networks:
  lobe-network:
    driver: bridge
DEOF
pok "Files: OK"

########################################
# 5. START SERVICES
########################################
pstp 5 "Khởi động Container"
docker compose down 2>/dev/null || true
docker compose up -d

pok "Đang chờ hệ thống ổn định..."
# Wait for Lobe to be ready
R=0; READY=false
while [ $R -lt 60 ]; do
  if curl -sf http://localhost:3210 >/dev/null 2>&1; then READY=true; break; fi
  R=$((R+1)); sleep 2
done

########################################
# 6. FINISH
########################################
pstp 6 "Hoàn tất"
if $READY; then
    pok "LobeHub đã sẵn sàng!"
else
    pwn "Hệ thống có thể cần thêm thời gian để khởi động."
fi

echo -e "\n${GREEN}  🎉 CÀI ĐẶT THÀNH CÔNG TRÊN MAC!${NC}"
echo -e "  LobeHub:         ${PURPLE}http://${IP}:3210${NC}"
echo -e "  RustFS Console:  ${PURPLE}http://${IP}:9001${NC}"
echo -e "  Thông tin đăng nhập S3: ${RUSTFS_ACCESS_KEY} / ${RUSTFS_SECRET_KEY}"
echo ""
echo -e "${YELLOW}Ghi chú cho Mac M4:${NC}"
echo "  1. Bạn có thể thêm cấu hình API Key trong file: ${INSTALL_DIR}/.env"
echo "  2. Chạy 'docker compose restart lobe' sau khi sửa file .env"
echo "  3. Toàn bộ dữ liệu được lưu trong OrbStack Volumes."
echo ""
echo -e "Support: ${PURPLE}https://ai.vnrom.net${NC} | By **duynghien**"
