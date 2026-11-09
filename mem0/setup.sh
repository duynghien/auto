#!/usr/bin/env bash
# ==============================================================================
# Mem0 OpenMemory Standalone Setup (Gen 4 Standard)
# Stack: Qdrant + Neo4j Graph Memory + FastAPI + Next.js UI
# Supports: macOS (Apple Silicon), Raspberry Pi (ARM64), Linux VPS (amd64/arm64)
# Author: duynghien (vnROM.net)
# ==============================================================================

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if command -v docker &>/dev/null && [ -f "${INSTALL_DIR:-}/docker-compose.yml" ]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m cd \"${INSTALL_DIR:-.}\" && docker compose logs --tail=50" >&2
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
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/mem0}"
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
echo "         Mem0 OpenMemory Setup — Gen 4 Standard"
echo -e "       Stack: Qdrant + Neo4j + FastAPI + Next.js"
echo -e "                 Platform: ${PLATFORM_LABEL}${NC}"
echo "================================================================"
echo ""

# Step 1: Preflight & Memory Check
step_title "1/7" "System Preflight & Hardware Check" "Kiểm tra hệ thống & phần cứng"

if [[ "$OS" == "Linux" ]]; then
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    echo -e "  • $(say 'RAM:' 'Bộ nhớ RAM:'): ${TOTAL_MEM_MB}MB | $(say 'Swap:' 'Bộ nhớ Swap:'): ${TOTAL_SWAP_MB}MB"
    
    if [ "$TOTAL_MEM_MB" -lt 3000 ] && [ "$TOTAL_SWAP_MB" -lt 1500 ]; then
        pwn "$(say "Low memory detected (<3GB RAM). Mem0 with Neo4j and Qdrant requires adequate swap." \
                   "Phát hiện RAM thấp (<3GB RAM). Mem0 gồm Qdrant và Neo4j cần thêm Swap để hoạt động ổn định.")"
        read -rp "  $(say 'Would you like to allocate 2GB Swap? [Y/n]: ' 'Bạn có muốn tự động tạo 2GB Swap không? [Y/n]: ') " SWAP_CHOICE || true
        case "${SWAP_CHOICE:-y}" in
            y|Y|yes|YES)
                AVAILABLE_DISK_KB=$(df -P / | awk 'NR==2 {print $4}')
                if [ "$AVAILABLE_DISK_KB" -gt 3500000 ]; then
                    echo "  → $(say 'Creating 2GB swapfile...' 'Đang tạo 2GB swapfile...')"
                    sudo fallocate -l 2G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
                    sudo chmod 600 /swapfile
                    sudo mkswap /swapfile
                    if ! sudo swapon /swapfile 2>/dev/null; then
                        pwn "$(say 'swapon restricted on this virtual environment (LXC/OpenVZ). Skipping swap.' \
                                   'swapon bị giới hạn trên môi trường ảo hóa này (LXC/OpenVZ). Bỏ qua tạo swap.')"
                        sudo rm -f /swapfile
                    else
                        grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
                        pok "$(say '2GB Swap enabled.' 'Đã kích hoạt 2GB Swap.')"
                    fi
                else
                    pwn "$(say 'Insufficient disk space for 2GB swap. Skipping.' 'Không đủ dung lượng ổ cứng để tạo 2GB swap. Bỏ qua.')"
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

# Step 2: Directory Setup & Source
step_title "2/7" "Installation Directory & Source Code" "Thư mục cài đặt & mã nguồn"
echo -e "  • Target directory: ${PURPLE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p data backups

if [ ! -d "openmemory-source" ]; then
    echo "  → $(say 'Cloning Mem0 OpenMemory repository...' 'Đang clone mã nguồn Mem0 OpenMemory...')"
    git clone --depth=1 https://github.com/mem0ai/mem0.git openmemory-source
    pok "$(say 'OpenMemory source cloned.' 'Đã clone source code OpenMemory.')"
else
    pok "$(say 'OpenMemory source already exists.' 'Mã nguồn OpenMemory đã có sẵn.')"
fi

OPENMEMORY_DIR="$INSTALL_DIR/openmemory-source/openmemory"
mkdir -p "$OPENMEMORY_DIR"

# Step 3: Port Conflict Check
step_title "3/7" "Port Configuration" "Kiểm tra cổng dịch vụ"

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

resolve_port() {
    local port_var="$1"
    local default_port="$2"
    local current_port="${!port_var:-$default_port}"
    if check_port "$current_port"; then
        pwn "$(say "Port $current_port is in use!" "Cổng $current_port đang được sử dụng!")"
        local alt_port=$((current_port + 1))
        while check_port "$alt_port"; do
            alt_port=$((alt_port + 1))
        done
        read -rp "  $(say "Enter alternative port (default: $alt_port): " "Nhập cổng khác (mặc định: $alt_port): ") " USER_PORT || true
        eval "$port_var='${USER_PORT:-$alt_port}'"
    else
        eval "$port_var='$current_port'"
    fi
}

UI_PORT="${UI_PORT:-3000}"
resolve_port UI_PORT 3000
pok "$(say "Selected UI port: $UI_PORT" "Cổng hoạt động UI: $UI_PORT")"

# Step 4: Authoritative File Generation
step_title "4/7" "Authoritative Files Generation" "Khởi tạo file cấu hình & script chuẩn"

cat > "$OPENMEMORY_DIR/docker-compose.yml" << 'COMPOSEOF'
services:
  mem0_store:
    image: qdrant/qdrant:latest
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - mem0_qdrant_data:/qdrant/storage

  neo4j:
    image: neo4j:5
    restart: unless-stopped
    environment:
      - NEO4J_AUTH=neo4j/${NEO4J_PASSWORD:-mem0_neo4j_pass}
      - NEO4J_PLUGINS=["apoc"]
      - NEO4J_server_memory_heap_initial__size=256m
      - NEO4J_server_memory_heap_max__size=512m
      - NEO4J_server_memory_pagecache_size=128m
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - mem0_neo4j_data:/data
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p ${NEO4J_PASSWORD:-mem0_neo4j_pass} 'RETURN 1' || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 30s

  openmemory-mcp:
    image: mem0/openmemory-mcp
    build: api/
    restart: unless-stopped
    env_file:
      - ../../.env
    depends_on:
      mem0_store:
        condition: service_started
      neo4j:
        condition: service_healthy
    ports:
      - "8765:8765"
    volumes:
      - ./api:/usr/src/openmemory
    command: >
      sh -c "uvicorn main:app --host 0.0.0.0 --port 8765 --reload --workers 4"
    healthcheck:
      test: ["CMD-SHELL", "python -c "import urllib.request; urllib.request.urlopen('http://localhost:8765/docs')" || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 8
      start_period: 30s

  openmemory-ui:
    build:
      context: ui/
      dockerfile: Dockerfile
    image: mem0/openmemory-ui:latest
    restart: unless-stopped
    env_file:
      - ../../.env
    ports:
      - "${UI_PORT:-3000}:3000"
    depends_on:
      openmemory-mcp:
        condition: service_healthy

volumes:
  mem0_qdrant_data:
  mem0_neo4j_data:
COMPOSEOF

cat << 'MEM0_EOF' > "$INSTALL_DIR/mem0.sh"
#!/usr/bin/env bash
# mem0.sh — Mem0 OpenMemory management helper (Gen 4 Standard)
# Stack: Qdrant + Neo4j + FastAPI + Next.js UI
# Usage: ./mem0.sh [command]

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
if command -v getent &>/dev/null; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/mem0}"
COMPOSE_DIR="$INSTALL_DIR/openmemory-source/openmemory"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -d "$COMPOSE_DIR" ]; then
    echo -e "${YELLOW}OpenMemory directory not found at $COMPOSE_DIR${NC}"
    echo "Please run setup.sh first."
    exit 1
fi

cd "$COMPOSE_DIR"

# Export environment variables for docker compose interpolation
set -a
[ -f "$INSTALL_DIR/.env" ] && source "$INSTALL_DIR/.env"
set +a

export API_KEY="${API_KEY:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export NEO4J_PASSWORD="${NEO4J_PASSWORD:-mem0_neo4j_pass}"
export NEXT_PUBLIC_API_URL="http://localhost:8765"
export NEXT_PUBLIC_USER_ID="${TARGET_USER}"
UI_PORT="${UI_PORT:-3000}"

CMD="${1:-help}"

case "$CMD" in
    start)
        echo -e "${GREEN}▶ Starting Mem0 stack...${NC}"
        docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}■ Stopping Mem0 stack...${NC}"
        docker compose stop
        ;;
    restart)
        echo -e "${YELLOW}↻ Restarting Mem0 stack...${NC}"
        docker compose restart
        ;;
    logs)
        shift || true
        SERVICE="${1:-}"
        if [ -n "$SERVICE" ]; then
            docker compose logs -f --tail=50 "$SERVICE"
        else
            docker compose logs -f --tail=50
        fi
        ;;
    status)
        echo -e "${CYAN}=== Mem0 Container Status ===${NC}"
        docker compose ps
        echo ""
        echo -e "${CYAN}=== Service Health Diagnostics ===${NC}"
        echo -n "  • Mem0 API (port 8765):       "
        curl -sf http://localhost:8765/docs > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • Qdrant Vector DB (port 6333): "
        curl -sf http://localhost:6333/healthz > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • Neo4j Graph DB (port 7474):   "
        curl -sf http://localhost:7474 > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • OpenMemory UI (port ${UI_PORT}): "
        curl -sf "http://localhost:${UI_PORT}" > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo ""
        echo -n "  • API_KEY in container:       "
        if docker exec openmemory-openmemory-mcp-1 printenv API_KEY 2>/dev/null | grep -q '.'; then
            echo -e "${GREEN}configured${NC}"
        else
            echo -e "${RED}NOT SET${NC}"
        fi
        echo -n "  • qdrant-client package:      "
        if docker exec openmemory-openmemory-mcp-1 python -c "import qdrant_client" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        echo -n "  • neo4j driver package:       "
        if docker exec openmemory-openmemory-mcp-1 python -c "import neo4j" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        ;;
    test)
        echo -e "${CYAN}=== Smoke Test (Add Memory) ===${NC}"
        echo "  Adding memory..."
        RESULT=$(curl -sf -X POST http://localhost:8765/api/v1/memories/ \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"${TARGET_USER}\", \"text\": \"My name is OpenClaw test user. I like AI and self-hosted tools.\"}" 2>&1 || true)
        if [ -n "$RESULT" ] && ! echo "$RESULT" | grep -q '"error"'; then
            echo -e "  ${GREEN}✓ Memory added successfully${NC}"
            echo "  $RESULT" | head -n 5
        else
            echo -e "  ${YELLOW}✗ Failed to add memory${NC}"
            echo "  Response: $RESULT" | head -n 5
        fi
        ;;
    update)
        echo -e "${CYAN}=== Updating Mem0 ===${NC}"
        cd "$INSTALL_DIR"
        git -C openmemory-source pull || true
        cd "$COMPOSE_DIR"
        docker compose up -d --build
        echo "  Waiting for API container..."
        sleep 15
        docker exec openmemory-openmemory-mcp-1 pip install "qdrant-client>=1.9.1" "neo4j>=5.0.0" --quiet 2>/dev/null || true
        docker compose restart openmemory-mcp 2>/dev/null || true
        echo -e "${GREEN}✓ Update complete!${NC}"
        ;;
    backup)
        BACKUP_DIR="$INSTALL_DIR/backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/mem0_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Archiving Mem0 configurations and environment...${NC}"
        tar -czf "$ARCHIVE" -C "$INSTALL_DIR" .env -C "$COMPOSE_DIR" docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;
    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./mem0.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${RED}WARNING: This will overwrite existing configurations!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            tar -xzf "$FILE" -C "$INSTALL_DIR"
            chmod 600 "$INSTALL_DIR/.env" 2>/dev/null || true
            echo -e "${GREEN}✓ Configurations restored. Restarting stack...${NC}"
            docker compose restart
        else
            echo "Restore aborted."
        fi
        ;;
    doctor)
        echo -e "${BOLD}=== Mem0 System Doctor ===${NC}"
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
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            PERMS=$(stat -c "%a" "$INSTALL_DIR/.env" 2>/dev/null || stat -f "%Lp" "$INSTALL_DIR/.env" 2>/dev/null || echo "unknown")
            echo "  $INSTALL_DIR/.env: $PERMS (recommended: 600)"
        else
            echo "  [FAIL] .env not found"
        fi
        echo "Port Bindings:"
        for p in 8765 6333 7474 7687 "$UI_PORT"; do
            if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
                echo "  [BOUND] Port $p is listening"
            else
                echo "  [OPEN/UNKNOWN] Port $p"
            fi
        done
        ;;
    purge|uninstall)
        echo -e "${RED}WARNING: This will REMOVE all Mem0 containers, volumes, memories, and graph data!${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ All containers and volumes removed.${NC}"
        else
            echo "Uninstall cancelled."
        fi
        ;;
    help|*)
        echo "Mem0 OpenMemory Management CLI (Gen 4 Standard)"
        echo "Stack: Qdrant + Neo4j + FastAPI + Next.js UI"
        echo ""
        echo "Usage: ./mem0.sh {start|stop|restart|logs|status|test|update|backup|restore|doctor|uninstall}"
        echo ""
        echo "  start      — Start all containers"
        echo "  stop       — Stop all containers"
        echo "  restart    — Restart all containers"
        echo "  logs [svc] — View live logs"
        echo "  status     — Check service health & dependencies"
        echo "  test       — Run smoke test (add memory)"
        echo "  update     — Pull latest source & rebuild"
        echo "  backup     — Archive configurations to ./backups/"
        echo "  restore    — Restore configurations from archive"
        echo "  doctor     — Run system health diagnostics"
        echo "  uninstall  — Remove all containers and volumes"
        ;;
esac
MEM0_EOF
chmod +x "$INSTALL_DIR/mem0.sh"

# System symlink
sudo ln -sf "$INSTALL_DIR/mem0.sh" /usr/local/bin/mem0 2>/dev/null || true

# Synchronize back to repo if run from within repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -f "$SCRIPT_DIR/mem0.sh" ]]; then
    cp -f "$INSTALL_DIR/mem0.sh" "$SCRIPT_DIR/mem0.sh" 2>/dev/null || true
fi
pok "$(say 'Authoritative configuration and helper CLI mem0.sh created.' 'Đã khởi tạo cấu hình và trình quản lý mem0.sh.')"

# Step 5: Environment Setup (.env)
step_title "5/7" "Configuring Environment (.env)" "Thiết lập biến môi trường"

ENV_FILE="$INSTALL_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "  $(say 'OpenAI API Key is required for Mem0 embedding and memory extraction.' 'OpenAI API Key là bắt buộc đối với Mem0 để tạo embedding và trích xuất bộ nhớ.')"
    read -rp "  $(say 'Enter OpenAI API Key: ' 'Nhập OpenAI API Key: ') " NEW_OPENAI_KEY || true
    NEW_OPENAI_KEY="${NEW_OPENAI_KEY:-sk-placeholder}"
    
    cat > "$ENV_FILE" << EOF
OPENAI_API_KEY=${NEW_OPENAI_KEY}
API_KEY=${NEW_OPENAI_KEY}
NEO4J_PASSWORD=mem0_neo4j_pass
UI_PORT=${UI_PORT}
NEXT_PUBLIC_API_URL=http://localhost:8765
NEXT_PUBLIC_USER_ID=${TARGET_USER}
EOF
    chmod 600 "$ENV_FILE"
    pok "$(say '.env initialized (chmod 600).' 'Đã tạo file .env (chmod 600).')"
else
    chmod 600 "$ENV_FILE"
    pok "$(say 'Preserved existing .env (chmod 600).' 'Giữ nguyên file .env hiện có (chmod 600).')"
fi

# Step 6: Deploy & Service
step_title "6/7" "Deployment & Health Verification" "Triển khai & Kiểm tra dịch vụ"

if [[ -n "${TARGET_USER:-}" && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR" 2>/dev/null || true
fi

cd "$OPENMEMORY_DIR"
set -a
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
set +a

echo "  → $(say 'Building and launching OpenMemory containers...' 'Đang build và khởi động các container OpenMemory...')"
docker compose up -d --build

echo "  → $(say 'Waiting for API container readiness...' 'Đang đợi container API khởi động...')"
for i in $(seq 1 45); do
    if docker exec openmemory-openmemory-mcp-1 python -c "import sys; print('ready')" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Install packages
echo "  → $(say 'Installing qdrant-client and neo4j driver inside API container...' 'Đang cài đặt qdrant-client và neo4j driver vào container API...')"
docker exec openmemory-openmemory-mcp-1 pip install "qdrant-client>=1.9.1" "neo4j>=5.0.0" --quiet 2>/dev/null || true
docker compose restart openmemory-mcp 2>/dev/null || true

# Safe host files ownership
find "$INSTALL_DIR" -maxdepth 1 -type f -exec chown "$TARGET_USER:$TARGET_GROUP" {} + 2>/dev/null || true

# Step 7: Summary
step_title "7/7" "Summary" "Tổng kết"

echo ""
echo "================================================================"
echo -e "${GREEN}${BOLD}  🎉 $(say 'MEM0 SETUP COMPLETED SUCCESSFULLY!' 'CÀI ĐẶT MEM0 HOÀN TẤT THÀNH CÔNG!')${NC}"
echo "================================================================"
echo -e "  • Mem0 API:        ${PURPLE}http://localhost:8765${NC}"
echo -e "  • OpenMemory UI:   ${PURPLE}http://localhost:${UI_PORT}${NC}"
echo -e "  • Qdrant DB:       ${PURPLE}http://localhost:6333${NC}"
echo -e "  • Neo4j Graph DB:  ${PURPLE}http://localhost:7474${NC}"
echo -e "  • Config file:     ${PURPLE}$ENV_FILE${NC} (chmod 600)"
echo -e "  • Helper CLI:      ${PURPLE}mem0${NC} (or ./mem0.sh)"
echo "================================================================"
echo "$(say 'Quick management commands:' 'Các lệnh quản lý nhanh:'):"
echo "  • mem0 status"
echo "  • mem0 test"
echo "  • mem0 logs"
echo "  • mem0 backup"
echo "  • mem0 doctor"
