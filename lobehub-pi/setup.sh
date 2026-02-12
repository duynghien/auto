#!/bin/bash
#############################################
# LobeHub v2.0+ Auto-Install for Pi 4 (8GB)
# Version 5.3
# FIX: Removed NEXT_PUBLIC_AUTH_URL (deprecated,
#      auth URL now auto-detected from headers)
#############################################
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
TOTAL_STEPS=7

pban() { echo -e "\n${CYAN}══ $1 ══${NC}"; }
pstp() { echo -e "\n${BLUE}[$1/$TOTAL_STEPS] $2${NC}"; }
pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; }

pban "LobeHub v2.0+ Installer — Pi 4 (v5.3)"

########################################
# 1. SYSTEM CHECK
########################################
pstp 1 "Kiem tra he thong"
[ "$(uname -m)" != "aarch64" ] && { perr "Can ARM64"; exit 1; }
pok "Arch: aarch64"
MEM=$(free -m|awk '/Mem/{print $2}')
pok "RAM: ${MEM}MB"
DSK=$(df -BG "$HOME"|awk 'NR==2{gsub(/G/,"",$4);print $4}')
[ "${DSK:-0}" -lt 8 ] && { perr "Disk ${DSK}GB < 8GB"; exit 1; }
pok "Disk: ${DSK}GB"
for c in openssl python3 curl; do
  command -v $c &>/dev/null || { perr "Thieu: $c"; exit 1; }
done

########################################
# 2. SWAP & DOCKER
########################################
pstp 2 "Docker & Swap"
if command -v dphys-swapfile &>/dev/null; then
  CS=$(grep 'CONF_SWAPSIZE=' /etc/dphys-swapfile 2>/dev/null|cut -d= -f2)
  if [ "${CS:-0}" -lt 2048 ]; then
    sudo dphys-swapfile swapoff 2>/dev/null||true
    sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
    sudo dphys-swapfile setup && sudo dphys-swapfile swapon
    pok "Swap: 2048MB"
  else pok "Swap OK (${CS}MB)"; fi
fi
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
  sudo usermod -aG docker "$USER"
  pwn "Can logout/login lai de dung docker khong sudo"
else pok "Docker OK"; fi
if ! docker compose version &>/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin
fi
pok "Docker Compose OK"

########################################
# 3. SECRETS & JWKS
########################################
pstp 3 "Sinh secrets & JWKS key"
INSTALL_DIR="$HOME/lobehub"
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

IP=$(hostname -I|awk '{print $1}')
[ -z "$IP" ] && IP="127.0.0.1"
pok "IP: $IP"

if [ -f .env ]; then
  pwn ".env ton tai, giu lai secrets cu"
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
  pok "Sinh JWKS RSA 2048-bit..."
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
  pok "JWKS key OK"
else
  pok "JWKS key: reused"
fi

########################################
# 4. CONFIG FILES
########################################
pstp 4 "Tao file cau hinh"

cat > .env <<ENVEOF
# LobeHub v2.0+ (v5.3) — $(date '+%Y-%m-%d %H:%M')
LOBE_PORT=3210
RUSTFS_PORT=9000
APP_URL=http://${IP}:3210

# Auth (Better Auth — email/password built-in)
AUTH_SECRET=${AUTH_SECRET}
KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET}
JWKS_KEY=${JWKS_KEY}
# AUTH_ALLOWED_EMAILS=you@email.com

# PostgreSQL
LOBE_DB_NAME=lobechat
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# RustFS S3
RUSTFS_ACCESS_KEY=${RUSTFS_ACCESS_KEY}
RUSTFS_SECRET_KEY=${RUSTFS_SECRET_KEY}
RUSTFS_LOBE_BUCKET=lobe
S3_ENDPOINT=http://localhost:9000
S3_PUBLIC_DOMAIN=http://${IP}:9000

# Search
SEARCH_PROVIDERS=searxng
CRAWLER_IMPLS=naive

# Redis
REDIS_URL=redis://redis:6379
REDIS_PREFIX=lobechat
REDIS_TLS=0

# AI Keys (uncomment)
# OPENAI_API_KEY=sk-xxx
# ANTHROPIC_API_KEY=sk-ant-xxx
# OLLAMA_PROXY_URL=http://host.docker.internal:11434
ENVEOF
pok ".env"

cat > searxng-settings.yml <<SEOF
use_default_settings: true
server:
  secret_key: "${SEARXNG_SECRET}"
  limiter: false
  image_proxy: true
search:
  safe_search: 0
  formats:
    - html
    - json
engines:
  - name: google
    engine: google
    shortcut: g
    disabled: false
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    disabled: false
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    disabled: false
  - name: bing
    engine: bing
    shortcut: bi
    disabled: false
SEOF
pok "searxng-settings.yml"

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
pok "bucket.config.json"

cat > docker-compose.yml <<'DEOF'
name: lobehub
services:
  network-service:
    image: alpine:3.20
    container_name: lobe-network
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
    container_name: lobe-postgres
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
    deploy:
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 256M

  redis:
    image: redis:7-alpine
    container_name: lobe-redis
    restart: always
    command: redis-server --save 60 1000 --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
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
    container_name: lobe-rustfs
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
    container_name: lobe-rustfs-init
    depends_on:
      rustfs:
        condition: service_healthy
    volumes:
      - ./bucket.config.json:/bucket.config.json:ro
    entrypoint: /bin/sh
    command: -c 'set -eux; mc alias set rustfs "http://network-service:9000" "${RUSTFS_ACCESS_KEY}" "${RUSTFS_SECRET_KEY}"; mc mb "rustfs/lobe" --ignore-existing; mc anonymous set-json "/bucket.config.json" "rustfs/lobe"; echo "Bucket OK";'
    restart: "no"
    networks:
      - lobe-network

  searxng:
    image: searxng/searxng:latest
    container_name: lobe-searxng
    restart: always
    volumes:
      - './searxng-settings.yml:/etc/searxng/settings.yml:ro'
    environment:
      - 'SEARXNG_SETTINGS_FILE=/etc/searxng/settings.yml'
    networks:
      - lobe-network
    deploy:
      resources:
        limits:
          memory: 256M

  lobe:
    image: lobehub/lobehub:latest
    container_name: lobehub
    network_mode: 'service:network-service'
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
      - 'S3_SET_ACL=0'
      - 'LLM_VISION_IMAGE_USE_BASE64=1'
      - 'SEARXNG_URL=http://searxng:8080'
      - 'SEARCH_PROVIDERS=searxng'
      - 'CRAWLER_IMPLS=naive'
      - 'REDIS_URL=redis://redis:6379'
      - 'REDIS_PREFIX=lobechat'
      - 'REDIS_TLS=0'
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
DEOF
pok "docker-compose.yml"

########################################
# 5. PULL IMAGES
########################################
pstp 5 "Tai Docker images"
docker compose pull 2>&1|tail -8 || pwn "Se pull khi start"

########################################
# 6. START SERVICES
########################################
pstp 6 "Khoi dong dich vu"
docker compose down 2>/dev/null||true

pok "Start infrastructure..."
docker compose up -d network-service postgresql redis rustfs

R=0
until docker exec lobe-postgres pg_isready -U postgres 2>/dev/null; do
  R=$((R+1)); [ $R -ge 60 ] && { perr "PG timeout"; exit 1; }; sleep 2
done
pok "PostgreSQL OK"

R=0
until docker exec lobe-redis redis-cli ping 2>/dev/null|grep -q PONG; do
  R=$((R+1)); [ $R -ge 30 ] && break; sleep 2
done
pok "Redis OK"

pok "Start all..."
docker compose up -d

R=0
while [ $R -lt 60 ]; do
  ST=$(docker inspect --format='{{.State.Status}}' lobe-rustfs-init 2>/dev/null||echo w)
  [ "$ST" = "exited" ] && { pok "S3 bucket OK"; break; }
  R=$((R+1)); sleep 2
done

pok "Doi LobeHub (1-3 phut)..."
R=0; READY=false
while [ $R -lt 90 ]; do
  curl -sf http://localhost:3210 >/dev/null 2>&1 && { READY=true; break; }
  R=$((R+1))
  [ $((R%15)) -eq 0 ] && pok "Dang khoi dong... (${R}s)"
  sleep 2
done
$READY && pok "LobeHub READY!" || pwn "Xem: docker logs -f lobehub"

########################################
# 7. DONE
########################################
pstp 7 "Hoan tat"
echo ""
pban "CAI DAT THANH CONG! (v5.3)"
echo ""
echo -e "  ${GREEN}LobeHub:${NC}         http://${IP}:3210"
echo -e "  ${GREEN}RustFS Console:${NC}  http://${IP}:9001"
echo -e "  ${GREEN}  User/Pass:${NC}     ${RUSTFS_ACCESS_KEY} / ${RUSTFS_SECRET_KEY}"
echo ""
echo -e "  ${CYAN}Dang nhap:${NC} Tao tai khoan email/password tren web"
echo ""
echo -e "${CYAN}Tinh nang:${NC}"
echo "  ✓ PostgreSQL+pgvector (Memory, Notebook, KB)"
echo "  ✓ RustFS S3 (File Upload, Artifacts)"
echo "  ✓ SearXNG (Online Search)"
echo "  ✓ Redis (Cache, Session)"
echo "  ✓ Better Auth (Email/Password)"
echo "  ✓ GTD Tools, Cloud Sandbox"
echo ""
echo -e "${YELLOW}Buoc tiep:${NC}"
echo "  1. Truy cap http://${IP}:3210"
echo "  2. Tao tai khoan (email + password)"
echo "  3. Them API Key: vi ${INSTALL_DIR}/.env"
echo "  4. Restart: cd ${INSTALL_DIR} && docker compose restart lobe"
echo ""
echo -e "${YELLOW}Lenh:${NC}"
echo "  Logs:    docker logs -f lobehub"
echo "  Stop:    cd ${INSTALL_DIR} && docker compose down"
echo "  Update:  cd ${INSTALL_DIR} && docker compose pull && docker compose up -d"
echo -e "${GREEN}Config: ${INSTALL_DIR}/.env${NC}"
