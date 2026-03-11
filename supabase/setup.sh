#!/bin/bash
################################################################
# Supabase Unified Auto-Install
# Supports: macOS (Apple Silicon/Intel), Raspberry Pi, VPS (amd64/arm64)
# Based on official supabase/supabase Docker self-hosting stack
################################################################

set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Helpers
pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

say() {
    local en="$1"
    local vi="$2"
    if [[ "${APP_LANG:-en}" == "vi" ]]; then
        echo "$vi"
    else
        echo "$en"
    fi
}

step_title() {
    case "$1" in
        1) say "[1/9] System check" "[1/9] Kiểm tra hệ thống" ;;
        2) say "[2/9] Access mode & ports" "[2/9] Chế độ truy cập & cổng" ;;
        3) say "[3/9] Directory & source" "[3/9] Thư mục & source" ;;
        4) say "[4/9] Environment & secrets" "[4/9] Biến môi trường & secrets" ;;
        5) say "[5/9] Compose files & helper" "[5/9] File Compose & helper" ;;
        6) say "[6/9] Compose validation" "[6/9] Kiểm tra Compose" ;;
        7) say "[7/9] Start containers" "[7/9] Khởi động containers" ;;
        8) say "[8/9] Verify services" "[8/9] Xác minh services" ;;
        9) say "[9/9] Summary" "[9/9] Tổng kết" ;;
        *) echo "[x]" ;;
    esac
}

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
    echo "          Supabase Setup — $PLATFORM_LABEL"
    echo "      Database · Auth · Storage · Realtime · Edge"
    echo -e "================================================================${NC}"
}

normalize_url() {
    local raw="$1"
    local normalized="${raw%/}"

    if [[ -z "$normalized" ]]; then
        echo ""
        return
    fi

    if [[ ! "$normalized" =~ ^https?:// ]]; then
        normalized="https://$normalized"
    fi

    echo "$normalized"
}

host_from_url() {
    local url="$1"
    echo "$url" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##'
}

read_env_value() {
    local key="$1"
    local file="$2"
    local line=""

    [[ -f "$file" ]] || return 0
    line=$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)
    [[ -n "$line" ]] && echo "${line#*=}"
}

upsert_env() {
    local file="$1"
    local key="$2"
    local value="$3"

    python3 - "$file" "$key" "$value" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
pattern = re.compile(rf'^{re.escape(key)}=')

lines = path.read_text(encoding='utf-8').splitlines()
for idx, line in enumerate(lines):
    if pattern.match(line):
        lines[idx] = f"{key}={value}"
        break
else:
    lines.append(f"{key}={value}")

path.write_text("\n".join(lines) + "\n", encoding='utf-8')
PY
}

port_in_use() {
    local port="$1"

    if command -v lsof >/dev/null 2>&1; then
        lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -tln 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    else
        return 1
    fi
}

next_free_port() {
    local start="$1"
    python3 - "$start" <<'PY'
import socket
import sys

start = int(sys.argv[1])
for port in range(start, 65536):
    with socket.socket() as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind(("127.0.0.1", port))
        except OSError:
            continue
        print(port)
        raise SystemExit(0)
raise SystemExit(1)
PY
}

default_port() {
    local existing="$1"
    local preferred="$2"

    if [[ -n "$existing" ]]; then
        echo "$existing"
        return
    fi

    if port_in_use "$preferred"; then
        next_free_port "$preferred"
    else
        echo "$preferred"
    fi
}

detect_lan_ip() {
    if [[ "$PLATFORM" == "mac" ]]; then
        local ip
        ip=$(ipconfig getifaddr en0 2>/dev/null || true)
        [[ -z "$ip" ]] && ip=$(ipconfig getifaddr en1 2>/dev/null || true)
        [[ -z "$ip" ]] && ip=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}' || true)
        echo "$ip"
    else
        local ip
        ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
        [[ -z "$ip" ]] && ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || true)
        echo "$ip"
    fi
}

run_privileged() {
    if [[ -n "$SUDO" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

DOCKER_CMD=(docker)
dc() {
    "${DOCKER_CMD[@]}" compose -f docker-compose.yml -f docker-compose.s3.yml -f docker-compose.override.yml "$@"
}

refresh_docker_cmd() {
    DOCKER_CMD=(docker)
    if "${DOCKER_CMD[@]}" info >/dev/null 2>&1; then
        return 0
    fi

    if [[ "$PLATFORM" != "mac" ]] && run_privileged docker info >/dev/null 2>&1; then
        DOCKER_CMD=(sudo docker)
        return 0
    fi

    return 1
}

sync_supabase_source_snapshot() {
    local ref="${SUPABASE_SOURCE_REF:-master}"
    local base_url="https://raw.githubusercontent.com/supabase/supabase/${ref}/docker"
    local files=(
        ".env.example"
        "docker-compose.yml"
        "docker-compose.s3.yml"
        "docker-compose.caddy.yml"
        "docker-compose.nginx.yml"
        "volumes/api/kong.yml"
        "volumes/db/_supabase.sql"
        "volumes/db/jwt.sql"
        "volumes/db/logs.sql"
        "volumes/db/pooler.sql"
        "volumes/db/realtime.sql"
        "volumes/db/roles.sql"
        "volumes/db/webhooks.sql"
        "volumes/db/init/data.sql"
        "volumes/functions/hello/index.ts"
        "volumes/functions/main/index.ts"
        "volumes/logs/vector.yml"
        "volumes/pooler/pooler.exs"
        "volumes/proxy/caddy/Caddyfile"
        "volumes/proxy/nginx/supabase-nginx.conf.tpl"
        "volumes/snippets/.gitkeep"
    )

    rm -rf supabase-upstream
    mkdir -p supabase-upstream

    local file=""
    for file in "${files[@]}"; do
        mkdir -p "supabase-upstream/$(dirname "$file")"
        curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 300 \
            "${base_url}/${file}" \
            -o "supabase-upstream/${file}"
    done
}

sanitize_compose_file() {
    local file="$1"
    python3 - "$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
content = path.read_text(encoding='utf-8')
content = content.replace(':Z', '')
content = content.replace(':z', '')
content = content.replace(',z', '')
content = content.replace(',Z', '')
path.write_text(content, encoding='utf-8')
PY
}

patch_port_bindings() {
    local file="$1"
    python3 - "$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
content = path.read_text(encoding='utf-8')
content = content.replace('${KONG_HTTP_PORT}:8000/tcp', '${SUPABASE_HTTP_PORT}:8000/tcp')
content = content.replace('${KONG_HTTPS_PORT}:8443/tcp', '${SUPABASE_HTTPS_PORT}:8443/tcp')
content = content.replace('${POSTGRES_PORT}:5432', '${SUPABASE_DB_PORT}:5432')
content = content.replace('${POOLER_PROXY_PORT_TRANSACTION}:6543', '${SUPABASE_DB_POOLER_PORT}:6543')
path.write_text(content, encoding='utf-8')
PY
}

patch_storage_images() {
    local file="$1"
    python3 - "$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
content = path.read_text(encoding='utf-8')
content = content.replace('image: cgr.dev/chainguard/minio-client:latest-dev', 'image: minio/mc:latest')
content = content.replace('image: cgr.dev/chainguard/minio', 'image: minio/minio:latest')
path.write_text(content, encoding='utf-8')
PY
}

rand_alnum() {
    local length="$1"
    python3 - "$length" <<'PY'
import secrets
import string
import sys

length = int(sys.argv[1])
alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(length)), end="")
PY
}

generate_jwt() {
    local role="$1"
    local secret="$2"
    local expiry="$3"

    python3 - "$role" "$secret" "$expiry" <<'PY'
import base64
import hashlib
import hmac
import json
import sys
import time

role = sys.argv[1]
secret = sys.argv[2]
expiry = int(sys.argv[3])

header = {"alg": "HS256", "typ": "JWT"}
payload = {
    "role": role,
    "iss": "supabase-self-hosted",
    "iat": int(time.time()),
    "exp": expiry,
}

def b64url(data):
    return base64.urlsafe_b64encode(json.dumps(data, separators=(",", ":")).encode()).decode().rstrip("=")

signing_input = f"{b64url(header)}.{b64url(payload)}"
signature = base64.urlsafe_b64encode(
    hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
).decode().rstrip("=")

print(f"{signing_input}.{signature}")
PY
}

wait_for_stack_health() {
    local timeout="${SUPABASE_HEALTH_TIMEOUT:-900}"
    local elapsed=0

    echo -n "  Waiting"
    while [[ "$elapsed" -lt "$timeout" ]]; do
        if ./supa.sh health >/dev/null 2>&1; then
            echo ""
            return 0
        fi
        echo -n "."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    echo ""
    return 1
}

pull_supabase_images() {
    local services=(
        studio
        kong
        auth
        rest
        realtime
        storage
        imgproxy
        meta
        functions
        analytics
        db
        vector
        supavisor
        minio
        minio-createbucket
    )
    local retries="${SUPABASE_PULL_RETRIES_PER_SERVICE:-4}"
    local parallel_limit="${SUPABASE_PULL_PARALLEL_LIMIT:-1}"
    local service=""
    local attempt=""
    local pulled=false

    for service in "${services[@]}"; do
        pulled=false
        for attempt in $(seq 1 "$retries"); do
            echo "  $(say "Pulling" "Đang kéo") ${service} (${attempt}/${retries})"
            if COMPOSE_PARALLEL_LIMIT="$parallel_limit" dc pull "$service"; then
                pulled=true
                break
            fi
            pwn "$(say "Pull failed, retrying..." "Kéo image lỗi, đang thử lại...")"
            sleep 3
        done

        [[ "$pulled" == "true" ]] || return 1
    done
}

create_helper_script() {
    cat > supa.sh <<'SCRIPTEOF'
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

pok()  { echo -e "${GREEN}  ✓${NC} $1"; }
pwn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

read_env_value() {
    local key="$1"
    local file="$2"
    local line=""

    [[ -f "$file" ]] || return 0
    line=$(grep -m1 "^${key}=" "$file" 2>/dev/null || true)
    [[ -n "$line" ]] && echo "${line#*=}"
}

DOCKER_CMD=(docker)
refresh_docker_cmd() {
    DOCKER_CMD=(docker)
    if "${DOCKER_CMD[@]}" info >/dev/null 2>&1; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        DOCKER_CMD=(sudo docker)
        return 0
    fi

    return 1
}

dc() {
    "${DOCKER_CMD[@]}" compose -f docker-compose.yml -f docker-compose.s3.yml -f docker-compose.override.yml "$@"
}

service_status() {
    local service="$1"
    local cid
    cid=$(dc ps -q "$service" 2>/dev/null | head -1)
    [[ -n "$cid" ]] || return 1

    "${DOCKER_CMD[@]}" inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid"
}

check_service() {
    local service="$1"
    local status=""

    status=$(service_status "$service" 2>/dev/null || true)
    case "$status" in
        healthy|running)
            pok "$service: $status"
            ;;
        *)
            perr "$service: ${status:-missing}"
            ;;
    esac
}

check_http_code() {
    local label="$1"
    local url="$2"
    local expected="$3"
    shift 3
    local -a extra_args=("$@")
    local -a curl_cmd=(curl -ksS -o /dev/null -w '%{http_code}')
    local code=""

    if [[ ${#extra_args[@]} -gt 0 ]]; then
        curl_cmd+=("${extra_args[@]}")
    fi
    curl_cmd+=("$url")

    code=$("${curl_cmd[@]}" || true)
    if [[ ",$expected," == *",$code,"* ]]; then
        pok "$label: HTTP $code"
    else
        perr "$label: HTTP $code (expected $expected)"
    fi
}

check_http_body() {
    local label="$1"
    local url="$2"
    local needle="$3"
    shift 3
    local -a extra_args=("$@")
    local -a curl_cmd=(curl -ksS)
    local body=""

    if [[ ${#extra_args[@]} -gt 0 ]]; then
        curl_cmd+=("${extra_args[@]}")
    fi
    curl_cmd+=("$url")

    body=$("${curl_cmd[@]}" || true)
    if printf '%s' "$body" | grep -q "$needle"; then
        pok "$label"
    else
        perr "$label"
    fi
}

refresh_docker_cmd || perr "Docker daemon is not accessible."

HTTP_PORT=$(read_env_value "SUPABASE_HTTP_PORT" ".env")
DASHBOARD_USERNAME=$(read_env_value "DASHBOARD_USERNAME" ".env")
DASHBOARD_PASSWORD=$(read_env_value "DASHBOARD_PASSWORD" ".env")
ANON_KEY=$(read_env_value "ANON_KEY" ".env")

case "${1:-status}" in
  start)
    dc up -d
    ;;
  stop)
    dc stop
    ;;
  restart)
    dc up -d --force-recreate
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-kong}"
    ;;
  health)
    [[ -n "$HTTP_PORT" ]] || perr "SUPABASE_HTTP_PORT is missing in .env"
    [[ -n "$DASHBOARD_USERNAME" ]] || perr "DASHBOARD_USERNAME is missing in .env"
    [[ -n "$DASHBOARD_PASSWORD" ]] || perr "DASHBOARD_PASSWORD is missing in .env"
    [[ -n "$ANON_KEY" ]] || perr "ANON_KEY is missing in .env"

    check_service kong
    check_service studio
    check_service auth
    check_service rest
    check_service realtime
    check_service storage
    check_service functions
    check_service db
    check_service supavisor
    check_service analytics
    check_service minio

    check_http_code "Dashboard" "http://localhost:${HTTP_PORT}/" "200,301,302,307,308" -u "${DASHBOARD_USERNAME}:${DASHBOARD_PASSWORD}"
    check_http_code "Auth settings" "http://localhost:${HTTP_PORT}/auth/v1/settings" "200" -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}"
    check_http_code "Storage status" "http://localhost:${HTTP_PORT}/storage/v1/status" "200"
    check_http_code "REST gateway" "http://localhost:${HTTP_PORT}/rest/v1/" "200,404" -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}"
    check_http_body "Edge Functions hello" "http://localhost:${HTTP_PORT}/functions/v1/hello" "Hello from Edge Functions" -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}"
    ;;
  upgrade)
    dc pull
    dc up -d
    ;;
  env)
    cat .env
    ;;
  keys)
    echo "Dashboard user : $(read_env_value "DASHBOARD_USERNAME" ".env")"
    echo "Dashboard pass : $(read_env_value "DASHBOARD_PASSWORD" ".env")"
    echo "Anon key       : $(read_env_value "ANON_KEY" ".env")"
    echo "Service role   : $(read_env_value "SERVICE_ROLE_KEY" ".env")"
    ;;
  reset)
    echo "This will remove Supabase containers and volumes."
    read -rp "Type 'yes' to continue: " confirm
    [[ "$confirm" == "yes" ]] || exit 1
    dc down -v --remove-orphans
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs [service]|health|upgrade|env|keys|reset}"
    exit 1
    ;;
esac
SCRIPTEOF

    chmod +x supa.sh
}

# ========================================
# Platform detection
# ========================================
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    if [[ "$ARCH" == "arm64" ]]; then
        PLATFORM_LABEL="macOS (Apple Silicon)"
    else
        PLATFORM_LABEL="macOS (Intel)"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if grep -qi 'raspberry\|raspbian' /proc/device-tree/model 2>/dev/null || \
       grep -qi 'raspberry' /etc/os-release 2>/dev/null; then
        if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
            perr "Raspberry Pi must run a 64-bit OS (ARM64) for this stack."
        fi
        PLATFORM="pi"
        PLATFORM_LABEL="Raspberry Pi (ARM64)"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        PLATFORM="vps-arm64"
        PLATFORM_LABEL="Linux VPS (ARM64)"
    elif [[ "$ARCH" == "x86_64" ]]; then
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux VPS (AMD64)"
    else
        perr "Unsupported Linux architecture: $ARCH"
    fi
else
    perr "Unsupported OS: $OS"
fi

SUDO=""
if [[ "$PLATFORM" != "mac" && $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        perr "sudo is required on Linux when not running as root."
    fi
fi

# ========================================
# Language selection
# ========================================
clear 2>/dev/null || true
pheader

echo ""
echo "  Select language / Chọn ngôn ngữ:"
echo ""
echo "    1) English (default)"
echo "    2) Tiếng Việt"
echo ""
read -rp "  Enter 1 or 2 [1]: " LANG_CHOICE
LANG_CHOICE=${LANG_CHOICE:-1}

if [[ "$LANG_CHOICE" == "2" ]]; then
    APP_LANG="vi"
else
    APP_LANG="en"
fi

TEST_MODE="${SUPABASE_SETUP_TEST_MODE:-0}"
if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "TEST MODE enabled: skip docker compose up and health verification." "TEST MODE đã bật: bỏ qua docker compose up và kiểm tra health.")"
fi

INSTALL_DIR="$HOME/self-hosted/supabase"

# ========================================
# Step 1: System check
# ========================================
echo ""
echo -e "${BOLD}$(step_title 1)${NC}"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        perr "$(say "Docker is not installed. Install OrbStack or Docker Desktop first." "Docker chưa được cài. Hãy cài OrbStack hoặc Docker Desktop trước.")"
    fi

    if ! docker info >/dev/null 2>&1; then
        pwn "$(say "Docker daemon is not running. Trying to start Docker..." "Docker daemon chưa chạy. Đang thử khởi động Docker...")"
        open -a OrbStack 2>/dev/null || open -a Docker 2>/dev/null || true
        echo -n "  Waiting"
        for _ in {1..30}; do
            if docker info >/dev/null 2>&1; then
                break
            fi
            echo -n "."
            sleep 2
        done
        echo ""
        docker info >/dev/null 2>&1 || perr "$(say "Docker daemon is still not available." "Docker daemon vẫn chưa sẵn sàng.")"
    fi

    docker compose version >/dev/null 2>&1 || perr "$(say "Docker Compose plugin not found." "Không tìm thấy Docker Compose plugin.")"
else
    if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get update -qq >/dev/null 2>&1 || true
        run_privileged apt-get install -y -qq curl ca-certificates >/dev/null 2>&1 || true
    fi

    if ! command -v docker >/dev/null 2>&1; then
        pwn "$(say "Docker not found, installing..." "Không tìm thấy Docker, đang cài...")"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        run_privileged sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
        if [[ -n "$SUDO" ]]; then
            run_privileged usermod -aG docker "$USER" 2>/dev/null || true
            pwn "$(say "If needed, logout/login to use docker without sudo." "Nếu cần, hãy logout/login để dùng docker không cần sudo.")"
        fi
    fi

    if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get update -qq >/dev/null 2>&1 || true
        run_privileged apt-get install -y -qq curl openssl python3 ca-certificates tar >/dev/null 2>&1 || true
    fi
fi

for cmd in curl openssl python3 tar; do
    command -v "$cmd" >/dev/null 2>&1 || perr "$(say "Missing required command:" "Thiếu command bắt buộc:") $cmd"
done

refresh_docker_cmd || perr "$(say "Docker daemon is not accessible." "Không thể truy cập Docker daemon.")"
"${DOCKER_CMD[@]}" compose version >/dev/null 2>&1 || perr "$(say "Docker Compose command is not ready." "Docker Compose chưa sẵn sàng.")"

if [[ "$PLATFORM" == "mac" ]]; then
    TOTAL_MEM_MB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
else
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
fi
DISK_GB=$(df -k "$HOME" | awk 'NR==2{print int($4/1024/1024)}')

pok "$(say "Platform:" "Nền tảng:") $PLATFORM_LABEL"
pok "RAM: ${TOTAL_MEM_MB}MB"
pok "$(say "Free disk:" "Dung lượng trống:") ${DISK_GB}GB"

if [[ "${DISK_GB:-0}" -lt 15 ]]; then
    perr "$(say "At least 15GB free disk is recommended for Supabase." "Khuyến nghị tối thiểu 15GB dung lượng trống cho Supabase.")"
fi

if [[ "$TOTAL_MEM_MB" -lt 8000 ]]; then
    pwn "$(say "Supabase full stack works best with 8GB+ RAM." "Supabase full stack chạy ổn định nhất với RAM 8GB+.")"

    if [[ "$PLATFORM" != "mac" ]]; then
        if ! swapon --show | grep -q '/swapfile'; then
            SWAP_GB=4
            [[ "$PLATFORM" == "pi" ]] && SWAP_GB=8
            pwn "$(say "Creating swap to improve stability..." "Đang tạo swap để tăng ổn định...")"
            run_privileged fallocate -l "${SWAP_GB}G" /swapfile 2>/dev/null || \
                run_privileged dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_GB * 1024))
            run_privileged chmod 600 /swapfile
            run_privileged mkswap /swapfile >/dev/null
            run_privileged swapon /swapfile
            if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
                echo '/swapfile none swap sw 0 0' | run_privileged tee -a /etc/fstab >/dev/null
            fi
            pok "$(say "Swap configured." "Đã cấu hình swap.")"
        else
            pok "$(say "Swap already exists." "Swap đã tồn tại.")"
        fi
    fi
fi

# ========================================
# Step 2: Access mode & ports
# ========================================
echo ""
echo -e "${BOLD}$(step_title 2)${NC}"

LAN_IP=$(detect_lan_ip)
if [[ "$PLATFORM" == "mac" ]]; then
    DEFAULT_NET="1"
else
    DEFAULT_NET="2"
fi

echo ""
if [[ "$APP_LANG" == "vi" ]]; then
    echo "  Chọn chế độ truy cập:"
    echo ""
    [[ "$DEFAULT_NET" == "1" ]] && echo "    1) Localhost (mặc định)" || echo "    1) Localhost"
    if [[ -n "$LAN_IP" ]]; then
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server ($LAN_IP) (mặc định)" || echo "    2) LAN / Home Server ($LAN_IP)"
    else
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server (nhập IP thủ công) (mặc định)" || echo "    2) LAN / Home Server (nhập IP thủ công)"
    fi
    echo "    3) Domain (đi qua reverse proxy)"
else
    echo "  Choose access mode:"
    echo ""
    [[ "$DEFAULT_NET" == "1" ]] && echo "    1) Localhost (default)" || echo "    1) Localhost"
    if [[ -n "$LAN_IP" ]]; then
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server ($LAN_IP) (default)" || echo "    2) LAN / Home Server ($LAN_IP)"
    else
        [[ "$DEFAULT_NET" == "2" ]] && echo "    2) LAN / Home Server (manual IP) (default)" || echo "    2) LAN / Home Server (manual IP)"
    fi
    echo "    3) Domain (behind reverse proxy)"
fi

read -rp "  $(say "Enter 1, 2 or 3" "Nhập 1, 2 hoặc 3") [${DEFAULT_NET}]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-$DEFAULT_NET}

EXISTING_INSTALL_ENV="${INSTALL_DIR}/.env"
DEFAULT_HTTP_PORT=$(default_port "$(read_env_value "SUPABASE_HTTP_PORT" "$EXISTING_INSTALL_ENV")" 8000)
DEFAULT_HTTPS_PORT=$(default_port "$(read_env_value "SUPABASE_HTTPS_PORT" "$EXISTING_INSTALL_ENV")" 8443)
DEFAULT_DB_PORT=$(default_port "$(read_env_value "SUPABASE_DB_PORT" "$EXISTING_INSTALL_ENV")" 5432)
DEFAULT_POOLER_PORT=$(default_port "$(read_env_value "SUPABASE_DB_POOLER_PORT" "$EXISTING_INSTALL_ENV")" 6543)

read -rp "  $(say "Supabase HTTP port" "Cổng HTTP của Supabase") [${DEFAULT_HTTP_PORT}]: " SUPABASE_HTTP_PORT
SUPABASE_HTTP_PORT=${SUPABASE_HTTP_PORT:-$DEFAULT_HTTP_PORT}
read -rp "  $(say "Supabase HTTPS port" "Cổng HTTPS của Supabase") [${DEFAULT_HTTPS_PORT}]: " SUPABASE_HTTPS_PORT
SUPABASE_HTTPS_PORT=${SUPABASE_HTTPS_PORT:-$DEFAULT_HTTPS_PORT}
read -rp "  $(say "Database session port" "Cổng database session") [${DEFAULT_DB_PORT}]: " SUPABASE_DB_PORT
SUPABASE_DB_PORT=${SUPABASE_DB_PORT:-$DEFAULT_DB_PORT}
read -rp "  $(say "Database transaction pooler port" "Cổng pooler transaction") [${DEFAULT_POOLER_PORT}]: " SUPABASE_DB_POOLER_PORT
SUPABASE_DB_POOLER_PORT=${SUPABASE_DB_POOLER_PORT:-$DEFAULT_POOLER_PORT}

for port in "$SUPABASE_HTTP_PORT" "$SUPABASE_HTTPS_PORT" "$SUPABASE_DB_PORT" "$SUPABASE_DB_POOLER_PORT"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        perr "$(say "Invalid port." "Cổng không hợp lệ.") $port"
    fi
done

NETWORK_MODE="localhost"
APP_URL="http://localhost:${SUPABASE_HTTP_PORT}"
ACCESS_HOST="localhost"

case "$NET_CHOICE" in
    2)
        NETWORK_MODE="lan"
        if [[ -n "$LAN_IP" ]]; then
            read -rp "  $(say "Use IP $LAN_IP? (Enter=OK, or type another)" "Dùng IP $LAN_IP? (Enter=OK, hoặc nhập IP khác)"): " CUSTOM_IP
            [[ -n "$CUSTOM_IP" ]] && LAN_IP="$CUSTOM_IP"
        else
            read -rp "  $(say "Enter LAN IP" "Nhập IP LAN"): " LAN_IP
            [[ -z "$LAN_IP" ]] && perr "$(say "LAN IP is required." "Bắt buộc nhập IP LAN.")"
        fi
        ACCESS_HOST="$LAN_IP"
        APP_URL="http://${ACCESS_HOST}:${SUPABASE_HTTP_PORT}"
        ;;
    3)
        NETWORK_MODE="domain"
        read -rp "  $(say "Enter public domain or URL (e.g. https://db.example.com)" "Nhập domain hoặc URL public (ví dụ: https://db.example.com)"): " DOMAIN_INPUT
        APP_URL=$(normalize_url "$DOMAIN_INPUT")
        [[ -z "$APP_URL" ]] && perr "$(say "Domain/URL is required." "Bắt buộc nhập domain/URL.")"
        ACCESS_HOST=$(host_from_url "$APP_URL")
        ;;
    *)
        NETWORK_MODE="localhost"
        ACCESS_HOST="localhost"
        APP_URL="http://localhost:${SUPABASE_HTTP_PORT}"
        ;;
esac

if [[ "$NETWORK_MODE" == "localhost" ]]; then
    SITE_URL="$APP_URL"
    ADDITIONAL_REDIRECT_URLS="http://localhost:${SUPABASE_HTTP_PORT},http://127.0.0.1:${SUPABASE_HTTP_PORT}"
elif [[ "$NETWORK_MODE" == "lan" ]]; then
    SITE_URL="$APP_URL"
    ADDITIONAL_REDIRECT_URLS="$APP_URL,http://localhost:${SUPABASE_HTTP_PORT},http://127.0.0.1:${SUPABASE_HTTP_PORT}"
else
    SITE_URL="$APP_URL"
    ADDITIONAL_REDIRECT_URLS="$APP_URL"
fi

pok "$(say "Mode:" "Chế độ:") $NETWORK_MODE"
pok "$(say "Public URL:" "URL truy cập:") $APP_URL"
pok "$(say "HTTP port:" "Cổng HTTP:") $SUPABASE_HTTP_PORT"
pok "$(say "DB session port:" "Cổng DB session:") $SUPABASE_DB_PORT"
pok "$(say "DB transaction port:" "Cổng DB transaction:") $SUPABASE_DB_POOLER_PORT"

# ========================================
# Step 3: Directory & source
# ========================================
echo ""
echo -e "${BOLD}$(step_title 3)${NC}"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory:" "Thư mục cài đặt:") $INSTALL_DIR"

if [[ ! -d supabase-upstream ]]; then
    pwn "$(say "Downloading official Supabase Docker snapshot..." "Đang tải snapshot Docker chính thức của Supabase...")"
else
    pwn "$(say "Refreshing official Supabase Docker snapshot..." "Đang làm mới snapshot Docker chính thức của Supabase...")"
fi
sync_supabase_source_snapshot || perr "$(say "Could not download official Supabase docker snapshot." "Không thể tải snapshot Docker chính thức của Supabase.")"
pok "$(say "Official Supabase docker files are ready." "Các file Docker chính thức của Supabase đã sẵn sàng.")"

# ========================================
# Step 4: Environment & secrets
# ========================================
echo ""
echo -e "${BOLD}$(step_title 4)${NC}"

PREVIOUS_ENV=""
if [[ -f .env ]]; then
    PREVIOUS_ENV=$(mktemp)
    cp .env "$PREVIOUS_ENV"
    cp .env ".env.backup.$(date +%Y%m%d-%H%M%S)"
    pok "$(say "Existing .env backed up." "Đã backup .env hiện tại.")"
fi

cp -f supabase-upstream/.env.example .env

OLD_POSTGRES_PASSWORD=$(read_env_value "POSTGRES_PASSWORD" "$PREVIOUS_ENV")
OLD_JWT_SECRET=$(read_env_value "JWT_SECRET" "$PREVIOUS_ENV")
OLD_DASHBOARD_USERNAME=$(read_env_value "DASHBOARD_USERNAME" "$PREVIOUS_ENV")
OLD_DASHBOARD_PASSWORD=$(read_env_value "DASHBOARD_PASSWORD" "$PREVIOUS_ENV")
OLD_SECRET_KEY_BASE=$(read_env_value "SECRET_KEY_BASE" "$PREVIOUS_ENV")
OLD_VAULT_ENC_KEY=$(read_env_value "VAULT_ENC_KEY" "$PREVIOUS_ENV")
OLD_PG_META_CRYPTO_KEY=$(read_env_value "PG_META_CRYPTO_KEY" "$PREVIOUS_ENV")
OLD_LOGFLARE_PUBLIC_ACCESS_TOKEN=$(read_env_value "LOGFLARE_PUBLIC_ACCESS_TOKEN" "$PREVIOUS_ENV")
OLD_LOGFLARE_PRIVATE_ACCESS_TOKEN=$(read_env_value "LOGFLARE_PRIVATE_ACCESS_TOKEN" "$PREVIOUS_ENV")
OLD_S3_PROTOCOL_ACCESS_KEY_ID=$(read_env_value "S3_PROTOCOL_ACCESS_KEY_ID" "$PREVIOUS_ENV")
OLD_S3_PROTOCOL_ACCESS_KEY_SECRET=$(read_env_value "S3_PROTOCOL_ACCESS_KEY_SECRET" "$PREVIOUS_ENV")
OLD_MINIO_ROOT_USER=$(read_env_value "MINIO_ROOT_USER" "$PREVIOUS_ENV")
OLD_MINIO_ROOT_PASSWORD=$(read_env_value "MINIO_ROOT_PASSWORD" "$PREVIOUS_ENV")
OLD_POOLER_TENANT_ID=$(read_env_value "POOLER_TENANT_ID" "$PREVIOUS_ENV")
OLD_OPENAI_API_KEY=$(read_env_value "OPENAI_API_KEY" "$PREVIOUS_ENV")
OLD_SMTP_ADMIN_EMAIL=$(read_env_value "SMTP_ADMIN_EMAIL" "$PREVIOUS_ENV")
OLD_SMTP_HOST=$(read_env_value "SMTP_HOST" "$PREVIOUS_ENV")
OLD_SMTP_PORT=$(read_env_value "SMTP_PORT" "$PREVIOUS_ENV")
OLD_SMTP_USER=$(read_env_value "SMTP_USER" "$PREVIOUS_ENV")
OLD_SMTP_PASS=$(read_env_value "SMTP_PASS" "$PREVIOUS_ENV")
OLD_SMTP_SENDER_NAME=$(read_env_value "SMTP_SENDER_NAME" "$PREVIOUS_ENV")
OLD_ENABLE_EMAIL_SIGNUP=$(read_env_value "ENABLE_EMAIL_SIGNUP" "$PREVIOUS_ENV")
OLD_ENABLE_EMAIL_AUTOCONFIRM=$(read_env_value "ENABLE_EMAIL_AUTOCONFIRM" "$PREVIOUS_ENV")
OLD_ENABLE_PHONE_SIGNUP=$(read_env_value "ENABLE_PHONE_SIGNUP" "$PREVIOUS_ENV")
OLD_ENABLE_PHONE_AUTOCONFIRM=$(read_env_value "ENABLE_PHONE_AUTOCONFIRM" "$PREVIOUS_ENV")
OLD_ENABLE_ANONYMOUS_USERS=$(read_env_value "ENABLE_ANONYMOUS_USERS" "$PREVIOUS_ENV")
OLD_DISABLE_SIGNUP=$(read_env_value "DISABLE_SIGNUP" "$PREVIOUS_ENV")
OLD_JWT_EXPIRY=$(read_env_value "JWT_EXPIRY" "$PREVIOUS_ENV")
OLD_FUNCTIONS_VERIFY_JWT=$(read_env_value "FUNCTIONS_VERIFY_JWT" "$PREVIOUS_ENV")
OLD_GOOGLE_ENABLED=$(read_env_value "GOOGLE_ENABLED" "$PREVIOUS_ENV")
OLD_GOOGLE_CLIENT_ID=$(read_env_value "GOOGLE_CLIENT_ID" "$PREVIOUS_ENV")
OLD_GOOGLE_SECRET=$(read_env_value "GOOGLE_SECRET" "$PREVIOUS_ENV")
OLD_GITHUB_ENABLED=$(read_env_value "GITHUB_ENABLED" "$PREVIOUS_ENV")
OLD_GITHUB_CLIENT_ID=$(read_env_value "GITHUB_CLIENT_ID" "$PREVIOUS_ENV")
OLD_GITHUB_SECRET=$(read_env_value "GITHUB_SECRET" "$PREVIOUS_ENV")
OLD_AZURE_ENABLED=$(read_env_value "AZURE_ENABLED" "$PREVIOUS_ENV")
OLD_AZURE_CLIENT_ID=$(read_env_value "AZURE_CLIENT_ID" "$PREVIOUS_ENV")
OLD_AZURE_SECRET=$(read_env_value "AZURE_SECRET" "$PREVIOUS_ENV")

POSTGRES_PASSWORD=${OLD_POSTGRES_PASSWORD:-$(rand_alnum 32)}
JWT_SECRET=${OLD_JWT_SECRET:-$(rand_alnum 48)}
DASHBOARD_USERNAME=${OLD_DASHBOARD_USERNAME:-supabase}
DASHBOARD_PASSWORD=${OLD_DASHBOARD_PASSWORD:-$(rand_alnum 24)}
SECRET_KEY_BASE=${OLD_SECRET_KEY_BASE:-$(rand_alnum 64)}
VAULT_ENC_KEY=${OLD_VAULT_ENC_KEY:-$(rand_alnum 32)}
PG_META_CRYPTO_KEY=${OLD_PG_META_CRYPTO_KEY:-$(rand_alnum 48)}
LOGFLARE_PUBLIC_ACCESS_TOKEN=${OLD_LOGFLARE_PUBLIC_ACCESS_TOKEN:-$(rand_alnum 40)}
LOGFLARE_PRIVATE_ACCESS_TOKEN=${OLD_LOGFLARE_PRIVATE_ACCESS_TOKEN:-$(rand_alnum 40)}
S3_PROTOCOL_ACCESS_KEY_ID=${OLD_S3_PROTOCOL_ACCESS_KEY_ID:-$(openssl rand -hex 16)}
S3_PROTOCOL_ACCESS_KEY_SECRET=${OLD_S3_PROTOCOL_ACCESS_KEY_SECRET:-$(openssl rand -hex 32)}
MINIO_ROOT_USER=${OLD_MINIO_ROOT_USER:-supa-storage}
MINIO_ROOT_PASSWORD=${OLD_MINIO_ROOT_PASSWORD:-$(rand_alnum 24)}
POOLER_TENANT_ID=${OLD_POOLER_TENANT_ID:-$(openssl rand -hex 6)}
STORAGE_TENANT_ID=${POOLER_TENANT_ID}
OPENAI_API_KEY=${OLD_OPENAI_API_KEY:-}
SMTP_ADMIN_EMAIL=${OLD_SMTP_ADMIN_EMAIL:-admin@example.com}
SMTP_HOST=${OLD_SMTP_HOST:-supabase-mail}
SMTP_PORT=${OLD_SMTP_PORT:-2500}
SMTP_USER=${OLD_SMTP_USER:-fake_mail_user}
SMTP_PASS=${OLD_SMTP_PASS:-fake_mail_password}
SMTP_SENDER_NAME=${OLD_SMTP_SENDER_NAME:-supabase}
ENABLE_EMAIL_SIGNUP=${OLD_ENABLE_EMAIL_SIGNUP:-true}
ENABLE_EMAIL_AUTOCONFIRM=${OLD_ENABLE_EMAIL_AUTOCONFIRM:-true}
ENABLE_PHONE_SIGNUP=${OLD_ENABLE_PHONE_SIGNUP:-true}
ENABLE_PHONE_AUTOCONFIRM=${OLD_ENABLE_PHONE_AUTOCONFIRM:-true}
ENABLE_ANONYMOUS_USERS=${OLD_ENABLE_ANONYMOUS_USERS:-false}
DISABLE_SIGNUP=${OLD_DISABLE_SIGNUP:-false}
JWT_EXPIRY=${OLD_JWT_EXPIRY:-3600}
FUNCTIONS_VERIFY_JWT=${OLD_FUNCTIONS_VERIFY_JWT:-false}
GOOGLE_ENABLED=${OLD_GOOGLE_ENABLED:-false}
GOOGLE_CLIENT_ID=${OLD_GOOGLE_CLIENT_ID:-}
GOOGLE_SECRET=${OLD_GOOGLE_SECRET:-}
GITHUB_ENABLED=${OLD_GITHUB_ENABLED:-false}
GITHUB_CLIENT_ID=${OLD_GITHUB_CLIENT_ID:-}
GITHUB_SECRET=${OLD_GITHUB_SECRET:-}
AZURE_ENABLED=${OLD_AZURE_ENABLED:-false}
AZURE_CLIENT_ID=${OLD_AZURE_CLIENT_ID:-}
AZURE_SECRET=${OLD_AZURE_SECRET:-}

JWT_LONG_EXPIRY=$(( $(date +%s) + 315360000 ))
ANON_KEY=$(generate_jwt "anon" "$JWT_SECRET" "$JWT_LONG_EXPIRY")
SERVICE_ROLE_KEY=$(generate_jwt "service_role" "$JWT_SECRET" "$JWT_LONG_EXPIRY")

upsert_env .env POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
upsert_env .env JWT_SECRET "$JWT_SECRET"
upsert_env .env ANON_KEY "$ANON_KEY"
upsert_env .env SERVICE_ROLE_KEY "$SERVICE_ROLE_KEY"
upsert_env .env DASHBOARD_USERNAME "$DASHBOARD_USERNAME"
upsert_env .env DASHBOARD_PASSWORD "$DASHBOARD_PASSWORD"
upsert_env .env SECRET_KEY_BASE "$SECRET_KEY_BASE"
upsert_env .env VAULT_ENC_KEY "$VAULT_ENC_KEY"
upsert_env .env PG_META_CRYPTO_KEY "$PG_META_CRYPTO_KEY"
upsert_env .env LOGFLARE_PUBLIC_ACCESS_TOKEN "$LOGFLARE_PUBLIC_ACCESS_TOKEN"
upsert_env .env LOGFLARE_PRIVATE_ACCESS_TOKEN "$LOGFLARE_PRIVATE_ACCESS_TOKEN"
upsert_env .env S3_PROTOCOL_ACCESS_KEY_ID "$S3_PROTOCOL_ACCESS_KEY_ID"
upsert_env .env S3_PROTOCOL_ACCESS_KEY_SECRET "$S3_PROTOCOL_ACCESS_KEY_SECRET"
upsert_env .env MINIO_ROOT_USER "$MINIO_ROOT_USER"
upsert_env .env MINIO_ROOT_PASSWORD "$MINIO_ROOT_PASSWORD"
upsert_env .env POOLER_TENANT_ID "$POOLER_TENANT_ID"
upsert_env .env STORAGE_TENANT_ID "$STORAGE_TENANT_ID"
upsert_env .env SUPABASE_PUBLIC_URL "$APP_URL"
upsert_env .env API_EXTERNAL_URL "$APP_URL"
upsert_env .env SITE_URL "$SITE_URL"
upsert_env .env ADDITIONAL_REDIRECT_URLS "$ADDITIONAL_REDIRECT_URLS"
upsert_env .env POSTGRES_HOST "db"
upsert_env .env POSTGRES_DB "postgres"
upsert_env .env POSTGRES_PORT "5432"
upsert_env .env POOLER_PROXY_PORT_TRANSACTION "6543"
upsert_env .env KONG_HTTP_PORT "8000"
upsert_env .env KONG_HTTPS_PORT "8443"
upsert_env .env STUDIO_DEFAULT_ORGANIZATION "vnROM Self-Hosted"
upsert_env .env STUDIO_DEFAULT_PROJECT "Supabase"
upsert_env .env OPENAI_API_KEY "$OPENAI_API_KEY"
upsert_env .env ENABLE_EMAIL_SIGNUP "$ENABLE_EMAIL_SIGNUP"
upsert_env .env ENABLE_EMAIL_AUTOCONFIRM "$ENABLE_EMAIL_AUTOCONFIRM"
upsert_env .env ENABLE_PHONE_SIGNUP "$ENABLE_PHONE_SIGNUP"
upsert_env .env ENABLE_PHONE_AUTOCONFIRM "$ENABLE_PHONE_AUTOCONFIRM"
upsert_env .env ENABLE_ANONYMOUS_USERS "$ENABLE_ANONYMOUS_USERS"
upsert_env .env DISABLE_SIGNUP "$DISABLE_SIGNUP"
upsert_env .env JWT_EXPIRY "$JWT_EXPIRY"
upsert_env .env SMTP_ADMIN_EMAIL "$SMTP_ADMIN_EMAIL"
upsert_env .env SMTP_HOST "$SMTP_HOST"
upsert_env .env SMTP_PORT "$SMTP_PORT"
upsert_env .env SMTP_USER "$SMTP_USER"
upsert_env .env SMTP_PASS "$SMTP_PASS"
upsert_env .env SMTP_SENDER_NAME "$SMTP_SENDER_NAME"
upsert_env .env GOOGLE_ENABLED "$GOOGLE_ENABLED"
upsert_env .env GOOGLE_CLIENT_ID "$GOOGLE_CLIENT_ID"
upsert_env .env GOOGLE_SECRET "$GOOGLE_SECRET"
upsert_env .env GITHUB_ENABLED "$GITHUB_ENABLED"
upsert_env .env GITHUB_CLIENT_ID "$GITHUB_CLIENT_ID"
upsert_env .env GITHUB_SECRET "$GITHUB_SECRET"
upsert_env .env AZURE_ENABLED "$AZURE_ENABLED"
upsert_env .env AZURE_CLIENT_ID "$AZURE_CLIENT_ID"
upsert_env .env AZURE_SECRET "$AZURE_SECRET"
upsert_env .env GLOBAL_S3_BUCKET "supabase-storage"
upsert_env .env REGION "local"
upsert_env .env FUNCTIONS_VERIFY_JWT "$FUNCTIONS_VERIFY_JWT"
upsert_env .env DOCKER_SOCKET_LOCATION "/var/run/docker.sock"
upsert_env .env SUPABASE_HTTP_PORT "$SUPABASE_HTTP_PORT"
upsert_env .env SUPABASE_HTTPS_PORT "$SUPABASE_HTTPS_PORT"
upsert_env .env SUPABASE_DB_PORT "$SUPABASE_DB_PORT"
upsert_env .env SUPABASE_DB_POOLER_PORT "$SUPABASE_DB_POOLER_PORT"

if [[ -n "$PREVIOUS_ENV" ]]; then
    rm -f "$PREVIOUS_ENV"
fi

pok "$(say "Saved .env with generated secure credentials." "Đã lưu .env với credentials bảo mật được tạo tự động.")"

# ========================================
# Step 5: Compose files & helper
# ========================================
echo ""
echo -e "${BOLD}$(step_title 5)${NC}"

cp -f supabase-upstream/docker-compose.yml docker-compose.yml
cp -f supabase-upstream/docker-compose.s3.yml docker-compose.s3.yml
cp -f supabase-upstream/docker-compose.caddy.yml docker-compose.caddy.yml
cp -f supabase-upstream/docker-compose.nginx.yml docker-compose.nginx.yml
mkdir -p volumes
cp -R supabase-upstream/volumes/. ./volumes/
mkdir -p volumes/db/data volumes/storage volumes/snippets

if [[ "$PLATFORM" == "mac" ]]; then
    sanitize_compose_file docker-compose.yml
    sanitize_compose_file docker-compose.s3.yml
    sanitize_compose_file docker-compose.caddy.yml
    sanitize_compose_file docker-compose.nginx.yml
    pok "$(say "Removed SELinux-only volume labels for macOS." "Đã bỏ volume labels chỉ dành cho SELinux trên macOS.")"
fi

cat > docker-compose.override.yml <<'OVEREOF'
services: {}
OVEREOF

patch_port_bindings docker-compose.yml
patch_storage_images docker-compose.s3.yml

create_helper_script
pok "$(say "Compose files and helper script are ready." "Các file Compose và helper script đã sẵn sàng.")"

# ========================================
# Step 6: Compose validation
# ========================================
echo ""
echo -e "${BOLD}$(step_title 6)${NC}"

if dc config >/dev/null 2>&1; then
    pok "$(say "docker compose config: OK" "docker compose config: OK")"
else
    perr "$(say "docker compose config failed." "docker compose config lỗi.")"
fi

# ========================================
# Step 7: Start containers
# ========================================
echo ""
echo -e "${BOLD}$(step_title 7)${NC}"

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping image pull and docker compose up." "Test mode: bỏ qua kéo image và docker compose up.")"
else
    MAX_START_ATTEMPTS=${SUPABASE_START_RETRIES:-5}
    SUCCESS_START=false

    for attempt in $(seq 1 "$MAX_START_ATTEMPTS"); do
        echo "  $(say "Attempt" "Lần thử") $attempt/$MAX_START_ATTEMPTS"
        if pull_supabase_images && dc up -d; then
            SUCCESS_START=true
            break
        fi
        pwn "$(say "Startup attempt failed, retrying..." "Lần khởi động này thất bại, đang thử lại...")"
        sleep 5
    done

    [[ "$SUCCESS_START" == "true" ]] || perr "$(say "Could not start Supabase containers." "Không thể khởi động các container Supabase.")"
    pok "$(say "Containers started." "Các container đã khởi động.")"
fi

# ========================================
# Step 8: Verify services
# ========================================
echo ""
echo -e "${BOLD}$(step_title 8)${NC}"

if [[ "$TEST_MODE" == "1" ]]; then
    pwn "$(say "Test mode: skipping health verification." "Test mode: bỏ qua kiểm tra health.")"
else
    wait_for_stack_health || {
        dc ps || true
        perr "$(say "Supabase did not become healthy in time." "Supabase không lên healthy kịp thời gian chờ.")"
    }
    pok "$(say "Supabase stack is healthy." "Supabase stack đã healthy.")"
fi

# ========================================
# Step 9: Summary
# ========================================
echo ""
echo -e "${BOLD}$(step_title 9)${NC}"

echo ""
echo -e "${BLUE}$(say "Access" "Truy cập")${NC}"
echo "  Dashboard     : $APP_URL"
echo "  REST API      : ${APP_URL%/}/rest/v1/"
echo "  Auth          : ${APP_URL%/}/auth/v1/"
echo "  Storage       : ${APP_URL%/}/storage/v1/"
echo "  Edge Function : ${APP_URL%/}/functions/v1/hello"
echo ""
echo -e "${BLUE}$(say "Credentials" "Thông tin đăng nhập")${NC}"
echo "  Dashboard user : $DASHBOARD_USERNAME"
echo "  Dashboard pass : $DASHBOARD_PASSWORD"
echo "  Postgres pass  : $POSTGRES_PASSWORD"
echo ""
echo -e "${BLUE}$(say "Database host ports" "Các cổng database trên host")${NC}"
echo "  Session pooler     : $SUPABASE_DB_PORT"
echo "  Transaction pooler : $SUPABASE_DB_POOLER_PORT"
echo ""
echo -e "${BLUE}$(say "Helper commands" "Lệnh quản lý")${NC}"
echo "  ./supa.sh start"
echo "  ./supa.sh stop"
echo "  ./supa.sh restart"
echo "  ./supa.sh status"
echo "  ./supa.sh logs kong"
echo "  ./supa.sh health"
echo "  ./supa.sh keys"
echo "  ./supa.sh reset"
echo ""
echo -e "${BLUE}$(say "Notes" "Ghi chú")${NC}"
echo "  - $(say "Official Docker source is stored in ./supabase-upstream" "Source Docker chính thức được lưu ở ./supabase-upstream")"
echo "  - $(say "For domain mode, put Caddy/Nginx/Traefik in front of port" "Với mode domain, hãy đặt Caddy/Nginx/Traefik ở trước cổng") $SUPABASE_HTTP_PORT"
echo "  - $(say "Update .env, then run ./supa.sh restart" "Sửa .env rồi chạy ./supa.sh restart")"
echo "  - $(say "Support: https://ai.vnrom.net" "Hỗ trợ: https://ai.vnrom.net")"
echo ""
