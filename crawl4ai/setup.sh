#!/usr/bin/env bash
# ==============================================================================
# Crawl4AI Standalone Setup (Gen 4 Standard)
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
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/crawl4ai}"
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
echo "          Crawl4AI Standalone Setup — Gen 4 Standard"
echo -e "                 Platform: ${PLATFORM_LABEL}${NC}"
echo "================================================================"
echo ""

# Step 1: Preflight & Memory Check
step_title "1/6" "System Preflight & Hardware Check" "Kiểm tra hệ thống & phần cứng"

if [[ "$OS" == "Linux" ]]; then
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    echo -e "  • $(say 'RAM:' 'Bộ nhớ RAM:'): ${TOTAL_MEM_MB}MB | $(say 'Swap:' 'Bộ nhớ Swap:'): ${TOTAL_SWAP_MB}MB"
    
    if [ "$TOTAL_MEM_MB" -lt 3000 ] && [ "$TOTAL_SWAP_MB" -lt 1500 ]; then
        pwn "$(say "Low memory detected (<3GB RAM). Crawl4AI browser automation needs sufficient swap." \
                   "Phát hiện RAM thấp (<3GB). Crawl4AI cần thêm Swap để chạy trình duyệt không bị crash.")"
        read -rp "  $(say 'Would you like to allocate 2GB Swap? [Y/n]: ' 'Bạn có muốn tự động tạo thêm 2GB Swap không? [Y/n]: ') " SWAP_CHOICE || true
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
                    pwn "$(say 'Insufficient disk space for 2GB swap. Skipping.' 'Không đủ ổ cứng trống để tạo swap. Bỏ qua.')"
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
mkdir -p backups

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

C4AI_PORT="${C4AI_PORT:-11235}"
if check_port "$C4AI_PORT"; then
    pwn "$(say "Port $C4AI_PORT is already in use!" "Cổng $C4AI_PORT hiện đang được sử dụng!")"
    ALT_PORT=11236
    while check_port "$ALT_PORT"; do
        ALT_PORT=$((ALT_PORT + 1))
    done
    read -rp "  $(say "Enter alternative port (default: $ALT_PORT): " "Nhập cổng khác (mặc định: $ALT_PORT): ") " USER_PORT || true
    C4AI_PORT="${USER_PORT:-$ALT_PORT}"
fi
pok "$(say "Selected port for Crawl4AI: $C4AI_PORT" "Cổng hoạt động Crawl4AI: $C4AI_PORT")"

# Step 4: Authoritative File Generation
step_title "4/6" "Authoritative Files Generation" "Khởi tạo file cấu hình & script chuẩn"

cat << 'COMPOSE_EOF' > "$INSTALL_DIR/docker-compose.yml"
# Crawl4AI Full-Stack Docker Compose
# Optimized for macOS (OrbStack) and Raspberry Pi (ARM64)
# Created by vnROM.net
#
# Usage:
#   Quick (pre-built image):  docker compose up -d
#   Full build (all features): INSTALL_TYPE=all docker compose up -d --build
#
# Endpoints:
#   API:            http://localhost:11235
#   Dashboard:      http://localhost:11235/dashboard
#   Playground:     http://localhost:11235/playground
#   MCP SSE:        http://localhost:11235/mcp/sse          (Claude Desktop, Antigravity)
#   MCP Streamable: http://localhost:11235/mcp/streamable   (LobeHub)
#   MCP WebSocket:  ws://localhost:11235/mcp/ws
#   MCP Schema:     http://localhost:11235/mcp/schema
#   Health:         http://localhost:11235/health
#   Metrics:        http://localhost:11235/metrics

services:
  crawl4ai:
    container_name: crawl4ai
    # Default: Pull official multi-arch image (AMD64 + ARM64)
    image: ${C4AI_IMAGE:-unclecode/crawl4ai:${C4AI_TAG:-latest}}

    # Optional: Build from source (uncomment or use --build flag)
    build:
      context: ./crawl4ai-source
      dockerfile: Dockerfile
      args:
        INSTALL_TYPE: ${INSTALL_TYPE:-default} # default | all | torch | transformer
        ENABLE_GPU: ${ENABLE_GPU:-false}

    ports:
      - "${C4AI_PORT:-11235}:11235"

    env_file:
      - path: .llm.env # LLM API keys (copy from .llm.env.example)
        required: false

    environment:
      # Security (optional - enable for production)
      - CRAWL4AI_API_TOKEN=${C4AI_API_TOKEN:-}
      # Hooks (disabled by default for security in v0.8.0)
      - CRAWL4AI_HOOKS_ENABLED=${C4AI_HOOKS_ENABLED:-false}

    volumes:
      # Chromium shared memory (required for performance)
      - /dev/shm:/dev/shm
      # Custom server configuration
      - ./config.yml:/app/config.yml:ro
      # Dynamic configuration entrypoint
      - ./docker-entrypoint.sh:/docker-entrypoint.sh:ro

    # Run as root to allow patching config.py
    user: root

    # Custom entrypoint to patch config before starting
    entrypoint: [ "/bin/bash", "/docker-entrypoint.sh" ]
    command: [ "supervisord", "-c", "supervisord.conf" ]

    deploy:
      resources:
        limits:
          memory: ${C4AI_MEMORY_LIMIT:-4G}
        reservations:
          memory: ${C4AI_MEMORY_RESERVE:-1G}

    restart: unless-stopped

    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:11235/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    # OrbStack: Automatically uses Rosetta for x86 images on Apple Silicon
    # No extra platform config needed
COMPOSE_EOF

cat << 'CONFIG_EOF' > "$INSTALL_DIR/config.yml"
# ============================================
# Crawl4AI Server Configuration (v0.8.0)
# ============================================
# This file is mounted into the container at /app/config.yml
# Modify settings here and restart the container to apply.
#
# Priority order for LLM config:
#   1. API Request Parameters (highest)
#   2. Provider-specific env vars (OPENAI_TEMPERATURE, etc.)
#   3. Global env vars (LLM_PROVIDER, LLM_TEMPERATURE, etc.)
#   4. This config file (lowest)

# Application Configuration
app:
  title: "Crawl4AI API"
  version: "0.8.0"
  host: "0.0.0.0"
  port: 11235
  reload: false
  workers: 1
  timeout_keep_alive: 300

# Default LLM (fallback when no env vars or request params)
llm:
  provider: "openai/deepseek-v3.2"  # Match .llm.env
  # api_key: sk-...  # Not recommended, use .llm.env instead

# Internal Redis (managed by supervisord inside container)
redis:
  host: "localhost"
  port: 6379
  db: 0
  password: ""
  ssl: false

# Rate Limiting
rate_limiting:
  enabled: true
  default_limit: "1000/minute"
  trusted_proxies: []
  storage_uri: "memory://"    # Use "redis://localhost:6379" for production

# Security (enable for production/public exposure)
# WARNING: For production, enable security and use proper SECRET_KEY:
#   - Set jwt_enabled: true for authentication
#   - Set SECRET_KEY environment variable to a secure random value
#   - Set CRAWL4AI_HOOKS_ENABLED=true only if you need hooks (RCE risk)
security:
  enabled: false
  jwt_enabled: false
  https_redirect: false
  trusted_hosts: ["*"]
  headers:
    x_content_type_options: "nosniff"
    x_frame_options: "DENY"
    content_security_policy: "default-src 'self'"
    strict_transport_security: "max-age=63072000; includeSubDomains"

# Crawler Engine
crawler:
  base_config:
    simulate_user: true
  memory_threshold_percent: 95.0
  rate_limiter:
    enabled: true
    base_delay: [1.0, 2.0]       # Min/max delay between requests
  timeouts:
    stream_init: 30.0            # Timeout for stream initialization
    batch_process: 300.0         # Timeout for batch processing
  pool:
    max_pages: 40                # Max concurrent pages (semaphore permits)
    idle_ttl_sec: 300            # Idle page cleanup after 5 minutes
  browser:
    kwargs:
      headless: true
      text_mode: true
    extra_args:
      - "--no-sandbox"
      - "--disable-dev-shm-usage"
      - "--disable-gpu"
      - "--disable-software-rasterizer"
      - "--disable-web-security"
      - "--allow-insecure-localhost"
      - "--ignore-certificate-errors"

# Logging
logging:
  level: "INFO"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# Observability
observability:
  prometheus:
    enabled: true
    endpoint: "/metrics"
  health_check:
    endpoint: "/health"

# Webhook Configuration
webhooks:
  enabled: true
  default_url: null              # Optional: default webhook URL for all jobs
  data_in_payload: false         # Include crawl data in webhook payload
  retry:
    max_attempts: 5
    initial_delay_ms: 1000       # Exponential backoff: 1s, 2s, 4s, 8s, 16s
    max_delay_ms: 32000
    timeout_ms: 30000            # 30s timeout per webhook call
  headers:
    User-Agent: "Crawl4AI-Webhook/1.0"
CONFIG_EOF

cat << 'ENTRYPOINT_EOF' > "$INSTALL_DIR/docker-entrypoint.sh"
#!/bin/bash
set -e

# ── 1. Dynamic LLM Configuration ──────────────────────────────
echo "[Entrypoint] Checking LLM configuration..."

CONFIG_PY="/usr/local/lib/python3.12/site-packages/crawl4ai/config.py"

if [ -n "$LLM_PROVIDER" ]; then
    echo "[Entrypoint] LLM_PROVIDER is set to: $LLM_PROVIDER"
    if grep -q "DEFAULT_PROVIDER = \"openai/gpt-4o\"" "$CONFIG_PY"; then
        echo "[Entrypoint] Patching Default Provider..."
        sed -i "s|DEFAULT_PROVIDER = \"openai/gpt-4o\"|DEFAULT_PROVIDER = \"$LLM_PROVIDER\"|" "$CONFIG_PY"
        echo "[Entrypoint] Patch applied."
    else
        CURRENT_PROVIDER=$(grep "DEFAULT_PROVIDER =" "$CONFIG_PY" | cut -d'"' -f2)
        if [ "$CURRENT_PROVIDER" != "$LLM_PROVIDER" ]; then
             echo "[Entrypoint] Overriding $CURRENT_PROVIDER → $LLM_PROVIDER..."
             sed -i "s|DEFAULT_PROVIDER = \".*\"|DEFAULT_PROVIDER = \"$LLM_PROVIDER\"|" "$CONFIG_PY"
        else
             echo "[Entrypoint] Config already matches. No patch needed."
        fi
    fi
else
    echo "[Entrypoint] LLM_PROVIDER not set. Using default."
fi

# ── 2. Permissions ─────────────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    if [ -d "/home/appuser" ]; then
        chown -R appuser:appuser /home/appuser
    fi
    export HOME=/home/appuser
fi

# ── 3. MCP Patches (identifier + Streamable HTTP) ─────────────
echo "[Entrypoint] Checking MCP configuration..."

python3 - <<'PYEOF'
import sys, os

FILE = "/app/mcp_bridge.py"
if not os.path.exists(FILE):
    print("[MCP Patch] mcp_bridge.py not found, skipping.")
    sys.exit(0)

with open(FILE) as f:
    src = f.read()

# Skip if already fully patched
if "class ToolWithId" in src and "StreamableHTTPServerTransport" in src:
    print("[MCP Patch] Already patched.")
    sys.exit(0)

print("[MCP Patch] Applying patches...")
changed = False

# ── Patch A: ToolWithId (identifier field for LobeHub) ────────
if "class ToolWithId" not in src:
    anchor = "from mcp.server.models import InitializationOptions"
    if anchor in src:
        new_class = '''

class ToolWithId(t.Tool):
    identifier: str
'''
        src = src.replace(anchor, anchor + new_class)
        changed = True
        print("[MCP Patch] Added ToolWithId class.")

    old_inst = "t.Tool(name=k, description=desc, inputSchema=schema)"
    new_inst = "ToolWithId(name=k, identifier=k, description=desc, inputSchema=schema)"
    if old_inst in src:
        src = src.replace(old_inst, new_inst)
        changed = True
        print("[MCP Patch] Replaced Tool instantiation.")

# ── Patch B: Add Streamable HTTP transport ────────────────────
if "StreamableHTTPServerTransport" not in src:
    # Add import
    import_anchor = "from mcp.server.sse import SseServerTransport"
    new_imports = """from mcp.server.sse import SseServerTransport
from mcp.server.streamable_http import StreamableHTTPServerTransport
import anyio as _anyio"""
    if import_anchor in src:
        src = src.replace(import_anchor, new_imports)
        changed = True
        print("[MCP Patch] Added Streamable HTTP imports.")

    # Add the streamable HTTP endpoint block after SSE mount
    sse_mount = '    app.mount(f"{base}/messages", app=sse.handle_post_message)'
    streamable_block = '''    app.mount(f"{base}/messages", app=sse.handle_post_message)

    # ── Streamable HTTP transport (for LobeHub etc.) ──────────
    _streamable_path = f"{base}/streamable"

    from starlette.types import ASGIApp, Receive, Scope, Send

    class StreamableMW:
        def __init__(self, app_inner: ASGIApp):
            self.app = app_inner
        async def __call__(self, scope: Scope, receive: Receive, send: Send):
            if scope["type"] == "http" and scope["path"].rstrip("/") == _streamable_path:
                import anyio
                transport = StreamableHTTPServerTransport(
                    mcp_session_id=None,
                    is_json_response_enabled=False,
                )
                async with anyio.create_task_group() as tg:
                    async def _run():
                        async with transport.connect() as (rs, ws):
                            await mcp.run(rs, ws, mcp.create_initialization_options(), stateless=True)
                    tg.start_soon(_run)
                    await anyio.sleep(0.05)
                    await transport.handle_request(scope, receive, send)
                    await transport.terminate()
                    tg.cancel_scope.cancel()
                return
            await self.app(scope, receive, send)

    app.add_middleware(StreamableMW)'''
    if sse_mount in src:
        src = src.replace(sse_mount, streamable_block)
        changed = True
        print("[MCP Patch] Added Streamable HTTP transport at /mcp/streamable.")

if changed:
    with open(FILE, "w") as f:
        f.write(src)
    print("[MCP Patch] All patches applied successfully!")
else:
    print("[MCP Patch] No changes needed.")
PYEOF

echo "[Entrypoint] Starting Supervisord..."
exec "$@"
ENTRYPOINT_EOF
chmod +x "$INSTALL_DIR/docker-entrypoint.sh"

cat << 'ENV_EXAMPLE_EOF' > "$INSTALL_DIR/.env.example"
# ============================================
# Crawl4AI Docker Compose Environment
# ============================================
# Usage: cp .env.example .env

# --- Image Settings ---
# Use official pre-built image (recommended)
C4AI_IMAGE=unclecode/crawl4ai
C4AI_TAG=latest

# --- Build Settings (only for --build) ---
# INSTALL_TYPE: default | all | torch | transformer
# - default: Core crawling + Playwright (recommended)
# - all:     + PyTorch + Transformers + NLTK (large image ~4-6GB)
# - torch:   + PyTorch features only
# - transformer: + Transformer features + model loader
INSTALL_TYPE=default
ENABLE_GPU=false

# --- Port ---
C4AI_PORT=11235

# --- Security (Optional) ---
# Set a token to require authentication for API calls
# C4AI_API_TOKEN=your-secret-token-here

# --- Hooks (Security) ---
# Enable user-provided hooks (disabled by default for security)
C4AI_HOOKS_ENABLED=false

# --- Resource Limits ---
# Adjust based on your hardware
# macOS (M1/M2/M3/M4): 4G recommended
# Raspberry Pi 4 (4GB): 2G recommended
# Raspberry Pi 5 (8GB): 4G recommended
C4AI_MEMORY_LIMIT=4G
C4AI_MEMORY_RESERVE=1G
ENV_EXAMPLE_EOF

cat << 'LLM_ENV_EXAMPLE_EOF' > "$INSTALL_DIR/.llm.env.example"
# ============================================
# Crawl4AI - LLM API Keys Configuration
# ============================================
# Copy this file to .llm.env and fill in your API keys.
# Only fill in the providers you plan to use.
#
# Usage: cp .llm.env.example .llm.env

# --- OpenAI ---
OPENAI_API_KEY=
# OPENAI_TEMPERATURE=0.7
# OPENAI_BASE_URL=https://api.openai.com/v1

# --- Anthropic ---
ANTHROPIC_API_KEY=
# ANTHROPIC_TEMPERATURE=0.7

# --- DeepSeek ---
DEEPSEEK_API_KEY=

# --- Google Gemini ---
GEMINI_API_TOKEN=

# --- Groq ---
GROQ_API_KEY=

# --- Together AI ---
TOGETHER_API_KEY=

# --- Mistral ---
MISTRAL_API_KEY=

# --- Global LLM Settings (Optional) ---
# These apply to ALL providers as defaults.
# Per-request parameters override these, and provider-specific
# env vars (e.g., OPENAI_TEMPERATURE) override globals.
#
# LLM_PROVIDER=openai/gpt-4o-mini
# LLM_TEMPERATURE=0.7
# LLM_BASE_URL=https://api.custom-proxy.com/v1

# --- Custom/Self-hosted LLM (e.g., Ollama, vLLM) ---
# LLM_PROVIDER=ollama/qwen2
# LLM_BASE_URL=http://host.docker.internal:11434
LLM_ENV_EXAMPLE_EOF

cat << 'C4AI_EOF' > "$INSTALL_DIR/c4ai.sh"
#!/bin/bash

# ============================================
# c4ai.sh - Crawl4AI Management Helper
# Created by vnROM.net
# ============================================
# Usage: ./c4ai.sh [command]
#   start    - Start Crawl4AI
#   stop     - Stop Crawl4AI
#   restart  - Restart Crawl4AI
#   status   - Show container status
#   logs     - Follow container logs
#   update   - Pull latest image and restart
#   test     - Run quick health/feature test
#   info     - Show all endpoints and MCP tools
#   shell    - Open shell in container

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PORT=$(grep -E "^C4AI_PORT=" .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-11235}
BASE_URL="http://localhost:${PORT}"

case "${1:-help}" in
    start)
        echo -e "${GREEN}Starting Crawl4AI...${NC}"
        docker compose up -d
        echo -e "${GREEN}✓ Started. Dashboard: ${BASE_URL}/dashboard${NC}"
        ;;

    stop)
        echo -e "${YELLOW}Stopping Crawl4AI...${NC}"
        docker compose down
        echo -e "${GREEN}✓ Stopped${NC}"
        ;;

    restart)
        echo -e "${YELLOW}Restarting Crawl4AI...${NC}"
        docker compose restart
        echo -e "${GREEN}✓ Restarted${NC}"
        ;;

    status)
        echo -e "${BOLD}Container Status:${NC}"
        docker compose ps
        echo ""
        # Health check
        if curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ API: Healthy${NC}"
        else
            echo -e "${RED}✗ API: Not responding${NC}"
        fi
        ;;

    logs)
        docker compose logs -f --tail=100
        ;;

    update)
        echo -e "${YELLOW}Updating Crawl4AI...${NC}"
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}✓ Updated to latest version${NC}"
        ;;

    test)
        echo -e "${BOLD}🧪 Running Crawl4AI Tests...${NC}"
        echo ""
        PASS=0
        FAIL=0

        # Health check
        echo -n "  Health Check... "
        if curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Dashboard
        echo -n "  Dashboard... "
        if curl -sf "${BASE_URL}/dashboard" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Playground
        echo -n "  Playground... "
        if curl -sf "${BASE_URL}/playground" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # MCP Schema
        echo -n "  MCP Schema... "
        MCP_RESULT=$(curl -sf "${BASE_URL}/mcp/schema" 2>/dev/null)
        if [ -n "$MCP_RESULT" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Metrics
        echo -n "  Prometheus Metrics... "
        if curl -sf "${BASE_URL}/metrics" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${YELLOW}~ SKIP (may not be enabled)${NC}"
        fi

        # Test crawl
        echo -n "  Test Crawl (example.com)... "
        CRAWL_RESULT=$(curl -sf -X POST "${BASE_URL}/crawl" \
            -H "Content-Type: application/json" \
            -d '{"urls":["https://example.com"],"priority":10}' 2>/dev/null)
        if [ -n "$CRAWL_RESULT" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        echo ""
        echo -e "  ${BOLD}Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
        ;;

    info)
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🕷️  Crawl4AI Endpoints${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}API:${NC}         ${BASE_URL}                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Dashboard:${NC}   ${BASE_URL}/dashboard         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Playground:${NC}  ${BASE_URL}/playground        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Health:${NC}      ${BASE_URL}/health            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Metrics:${NC}     ${BASE_URL}/metrics           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}MCP Endpoints:${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🔌 SSE${NC}          ${BASE_URL}/mcp/sse          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}📡 Streamable${NC}   ${BASE_URL}/mcp/streamable   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🌐 WebSocket${NC}    ws://localhost:${PORT}/mcp/ws      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}📋 Schema${NC}       ${BASE_URL}/mcp/schema       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}MCP Tools (7):${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   md, html, screenshot, pdf,                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   execute_js, crawl, ask                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}REST API:${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /crawl      - Crawl URLs                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   GET  /task/{id}   - Get task result            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /html       - Extract HTML               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /screenshot  - Capture screenshot        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /pdf        - Generate PDF               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /execute_js  - Run JavaScript            ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}AI Agent Integration:${NC}"
        echo -e "  ${GREEN}Claude Desktop/Code:${NC}"
        echo "    claude mcp add --transport sse c4ai ${BASE_URL}/mcp/sse"
        echo -e "  ${GREEN}LobeHub (Streamable HTTP):${NC}"
        echo "    URL: ${BASE_URL}/mcp/streamable"
        echo -e "  ${GREEN}Antigravity / OpenClaw:${NC}"
        echo "    SSE: ${BASE_URL}/mcp/sse"
        ;;

    shell)
        echo -e "${YELLOW}Opening shell in Crawl4AI container...${NC}"
        docker compose exec crawl4ai /bin/bash || docker compose exec crawl4ai /bin/sh
        ;;

    backup)
        BACKUP_DIR="./backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/crawl4ai_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Creating Crawl4AI configuration and state backup...${NC}"
        tar -czf "$ARCHIVE" .env .llm.env config.yml docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;

    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./c4ai.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${YELLOW}WARNING: This will overwrite existing configurations with archive contents!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            tar -xzf "$FILE"
            chmod 600 .env .llm.env 2>/dev/null || true
            echo -e "${GREEN}✓ Restore completed! Restarting stack...${NC}"
            docker compose restart
        else
            echo "Restore aborted."
        fi
        ;;

    doctor)
        echo -e "${BOLD}=== Crawl4AI Diagnostic Doctor ===${NC}"
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
        echo "File permissions:"
        for f in .env .llm.env; do
            if [[ -f "$f" ]]; then
                P=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%Lp" "$f" 2>/dev/null || echo "unknown")
                echo "  $f: $P (recommended: 600)"
            else
                echo "  $f: not found"
            fi
        done
        echo -n "Port ${PORT} status: "
        if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
            echo -e "${GREEN}Listening${NC}"
        else
            echo -e "${YELLOW}Not listening${NC}"
        fi
        echo -n "Health endpoint (${BASE_URL}/health): "
        if curl -sf "${BASE_URL}/health" >/dev/null 2>&1; then
            echo -e "${GREEN}Healthy${NC}"
        else
            echo -e "${RED}Not responding${NC}"
        fi
        ;;

    uninstall)
        echo -e "${RED}WARNING: This will stop and remove all Crawl4AI containers and networks.${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ Crawl4AI containers and volumes removed.${NC}"
        else
            echo "Uninstall aborted."
        fi
        ;;

    help|*)
        echo -e "${BOLD}Usage:${NC} ./c4ai.sh [command]"
        echo ""
        echo -e "  ${GREEN}start${NC}      Start Crawl4AI"
        echo -e "  ${GREEN}stop${NC}       Stop Crawl4AI"
        echo -e "  ${GREEN}restart${NC}    Restart Crawl4AI"
        echo -e "  ${GREEN}status${NC}     Show container status + health"
        echo -e "  ${GREEN}logs${NC}       Follow container logs"
        echo -e "  ${GREEN}update${NC}     Pull latest image and restart"
        echo -e "  ${GREEN}test${NC}       Run quick health checks"
        echo -e "  ${GREEN}info${NC}       Show all endpoints and MCP tools"
        echo -e "  ${GREEN}shell${NC}      Open shell in container"
        echo -e "  ${GREEN}backup${NC}     Archive configs to ./backups/"
        echo -e "  ${GREEN}restore${NC}    Restore configs from archive"
        echo -e "  ${GREEN}doctor${NC}     Diagnostic system check"
        echo -e "  ${GREEN}uninstall${NC}  Remove containers and volumes"
        ;;
esac
C4AI_EOF
chmod +x "$INSTALL_DIR/c4ai.sh"

# Canonical symlinks
ln -sf c4ai.sh "$INSTALL_DIR/crawl4ai.sh"
sudo ln -sf "$INSTALL_DIR/c4ai.sh" /usr/local/bin/c4ai 2>/dev/null || true
sudo ln -sf "$INSTALL_DIR/c4ai.sh" /usr/local/bin/crawl4ai 2>/dev/null || true

# Synchronize back to repo if run from within repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -f "$SCRIPT_DIR/c4ai.sh" ]]; then
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
    cp -f "$INSTALL_DIR/config.yml" "$SCRIPT_DIR/config.yml" 2>/dev/null || true
    cp -f "$INSTALL_DIR/docker-entrypoint.sh" "$SCRIPT_DIR/docker-entrypoint.sh" 2>/dev/null || true
    cp -f "$INSTALL_DIR/c4ai.sh" "$SCRIPT_DIR/c4ai.sh" 2>/dev/null || true
    ln -sf c4ai.sh "$SCRIPT_DIR/crawl4ai.sh" 2>/dev/null || true
fi
pok "$(say 'Authoritative configuration and helper CLI created.' 'Đã khởi tạo cấu hình và trình quản lý c4ai.sh.')"

# Step 5: Environment Setup (.env & .llm.env)
step_title "5/6" "Configuring Environment (.env & .llm.env)" "Thiết lập biến môi trường"

if [ ! -f .env ]; then
    cp .env.example .env
    sed -i.bak "s/^C4AI_PORT=.*/C4AI_PORT=${C4AI_PORT}/" .env && rm -f .env.bak 2>/dev/null || true
    
    # Auto-adjust limits for low RAM
    if [[ "$PLATFORM" != "mac" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 4000 ]; then
            sed -i.bak "s/^C4AI_MEMORY_LIMIT=.*/C4AI_MEMORY_LIMIT=2G/" .env && rm -f .env.bak 2>/dev/null || true
            sed -i.bak "s/^C4AI_MEMORY_RESERVE=.*/C4AI_MEMORY_RESERVE=512M/" .env && rm -f .env.bak 2>/dev/null || true
        fi
        if [[ "$PLATFORM" == "pi" ]]; then
            sed -i.bak "s/^INSTALL_TYPE=.*/INSTALL_TYPE=default/" .env && rm -f .env.bak 2>/dev/null || true
        fi
    fi
    chmod 600 .env
    pok "$(say '.env initialized (chmod 600).' 'Đã tạo file .env (chmod 600).')"
else
    chmod 600 .env
    pok "$(say 'Preserved existing .env (chmod 600).' 'Giữ nguyên file .env hiện có (chmod 600).')"
fi

if [ ! -f .llm.env ]; then
    cp .llm.env.example .llm.env
    chmod 600 .llm.env
    pok "$(say '.llm.env initialized (chmod 600).' 'Đã tạo file .llm.env (chmod 600).')"
else
    chmod 600 .llm.env
    pok "$(say 'Preserved existing .llm.env (chmod 600).' 'Giữ nguyên file .llm.env hiện có (chmod 600).')"
fi

# Step 6: Deploy & Service
step_title "6/6" "Deployment & Health Verification" "Triển khai & Kiểm tra dịch vụ"

if [[ -n "${TARGET_USER:-}" && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR" 2>/dev/null || true
fi

echo "  → $(say 'Pulling latest Crawl4AI image...' 'Đang tải image Crawl4AI mới nhất...')"
docker compose pull
docker compose up -d

echo "  → $(say 'Waiting for Crawl4AI API readiness...' 'Đang đợi Crawl4AI khởi động...')"
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${C4AI_PORT}/health" >/dev/null 2>&1; then
        pok "$(say 'Crawl4AI API is healthy!' 'Crawl4AI API đã sẵn sàng!')"
        break
    fi
    sleep 2
done

# Safe post-startup host files ownership
find "$INSTALL_DIR" -maxdepth 1 -type f -exec chown "$TARGET_USER:$TARGET_GROUP" {} + 2>/dev/null || true

echo ""
echo "================================================================"
echo -e "${GREEN}${BOLD}  🎉 $(say 'CRAWL4AI SETUP COMPLETED SUCCESSFULLY!' 'CÀI ĐẶT CRAWL4AI HOÀN TẤT THÀNH CÔNG!')${NC}"
echo "================================================================"
echo -e "  • API Endpoint:    ${PURPLE}http://localhost:${C4AI_PORT}${NC}"
echo -e "  • Dashboard:       ${PURPLE}http://localhost:${C4AI_PORT}/dashboard${NC}"
echo -e "  • MCP SSE:         ${PURPLE}http://localhost:${C4AI_PORT}/mcp/sse${NC}"
echo -e "  • Config files:    ${PURPLE}$INSTALL_DIR/.env${NC}, ${PURPLE}$INSTALL_DIR/.llm.env${NC} (chmod 600)"
echo -e "  • Helper CLI:      ${PURPLE}c4ai${NC} (or crawl4ai / ./c4ai.sh)"
echo "================================================================"
echo "$(say 'Quick management commands:' 'Các lệnh quản lý nhanh:'):"
echo "  • c4ai status"
echo "  • c4ai test"
echo "  • c4ai logs"
echo "  • c4ai backup"
echo "  • c4ai doctor"
