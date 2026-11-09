#!/usr/bin/env bash
# ==============================================================================
# AnyCrawl Unified Standalone Setup (Gen 4 Standard)
# PostgreSQL + MinIO (S3) + Redis + SearXNG + MCP Server
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

# Safe user & path resolution
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP="$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")"
if command -v getent &>/dev/null; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/anycrawl}"
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

# ==============================================================================
# Language Selection (EN/VI)
# ==============================================================================
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

# ==============================================================================
# Platform Detection
# ==============================================================================
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
echo "        AnyCrawl Max-Option Setup — Gen 4 Standard"
echo -e "              Platform: ${PLATFORM_LABEL}${NC}"
echo "================================================================"
echo ""

# ==============================================================================
# Step 1: System Preflight & Dependencies
# ==============================================================================
step_title "1/6" "System Preflight & Hardware Check" "Kiểm tra hệ thống & phần cứng"

# RAM & Swap Check on Linux
if [[ "$OS" == "Linux" ]]; then
    TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    echo -e "  • $(say 'RAM:' 'Bộ nhớ RAM:'): ${TOTAL_MEM_MB}MB | $(say 'Swap:' 'Bộ nhớ Swap:'): ${TOTAL_SWAP_MB}MB"
    
    if [ "$TOTAL_MEM_MB" -lt 4000 ] && [ "$TOTAL_SWAP_MB" -lt 2000 ]; then
        pwn "$(say "Low memory detected (<4GB RAM and <2GB Swap). AnyCrawl with PostgreSQL and MinIO runs best with adequate memory." \
                   "Phát hiện RAM thấp (<4GB RAM và <2GB Swap). AnyCrawl cần đủ RAM để chạy mượt mà.")"
        read -rp "  $(say 'Would you like to allocate 4GB Swap? [Y/n]: ' 'Bạn có muốn tự động tạo thêm 4GB Swap không? [Y/n]: ') " SWAP_CHOICE || true
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
                    pwn "$(say 'Insufficient disk space for 4GB swap (<6GB free). Skipping.' 'Không đủ dung lượng ổ cứng để tạo 4GB swap (<6GB trống).')"
                fi
                ;;
            *)
                echo "  $(say 'Skipped swap creation.' 'Bỏ qua tạo swap.')"
                ;;
        esac
    fi
fi

# Docker Check / Auto-install
if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &> /dev/null; then
        perr "$(say 'Docker is not installed on macOS.' 'Chưa cài đặt Docker trên macOS.')"
        echo "  OrbStack (recommended): https://orbstack.dev"
        echo "  Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        exit 1
    fi
    pok "Docker: OK"
else
    if ! command -v docker &> /dev/null; then
        pwn "$(say 'Docker not found, installing automatically...' 'Docker chưa cài đặt, đang tự động cài đặt...')"
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

# Verify tools
for c in openssl curl git; do
    if ! command -v "$c" &>/dev/null; then
        if [[ "$OS" == "Linux" ]]; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$c" 2>/dev/null || true
        else
            perr "$(say "Missing required tool: $c" "Thiếu công cụ bắt buộc: $c")"
            exit 1
        fi
    fi
done
pok "$(say 'Required utilities: OK' 'Công cụ hệ thống: OK')"

# ==============================================================================
# Step 2: Target Directory & Permissions
# ==============================================================================
step_title "2/6" "Installation Directory" "Thư mục cài đặt"
echo -e "  • Target directory: ${PURPLE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

mkdir -p storage searxng mcp-server backups
chmod 777 searxng

# ==============================================================================
# Step 3: Network Mode & Port Conflict Diagnostics
# ==============================================================================
step_title "3/6" "Network Mode & Port Configuration" "Cấu hình mạng & kiểm tra cổng"

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
        pwn "$(say "Port $current_port is already in use!" "Cổng $current_port hiện đang có tiến trình sử dụng!")"
        local alt_port=$((current_port + 1))
        while check_port "$alt_port"; do
            alt_port=$((alt_port + 1))
        done
        read -rp "  $(say "Enter alternative port (default: $alt_port): " "Nhập cổng khác (mặc định: $alt_port): ") " USER_PORT || true
        eval "$port_var='${USER_PORT:-$alt_port}'"
        pok "$(say "Selected port for $port_var: ${!port_var}" "Cổng được chọn cho $port_var: ${!port_var}")"
    else
        eval "$port_var='$current_port'"
        pok "$(say "Port $current_port ($port_var): Available" "Cổng $current_port ($port_var): Sẵn sàng")"
    fi
}

ANYCRAWL_PORT="${ANYCRAWL_API_PORT:-8880}"
resolve_port ANYCRAWL_PORT 8880

MINIO_PORT="${MINIO_PORT:-9000}"
resolve_port MINIO_PORT 9000

MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
resolve_port MINIO_CONSOLE_PORT 9001

SEARXNG_PORT="${SEARXNG_PORT:-8080}"
resolve_port SEARXNG_PORT 8080

MCP_PORT="${MCP_PORT:-8889}"
resolve_port MCP_PORT 8889

# Network mode selector
echo ""
echo "  1) Localhost only (127.0.0.1 - $(say 'Best for local dev / MCP on same machine' 'Thích hợp dev local / Agent cùng máy'))"
echo "  2) Local Network (LAN IP - $(say 'Accessible from other devices on WiFi/LAN' 'Truy cập từ các máy khác trong mạng nội bộ'))"
echo "  3) Public Domain / VPS (Reverse Proxy / HTTPS)"
read -rp "  $(say 'Select Network Mode [1-3] (default: 1): ' 'Chọn chế độ mạng [1-3] (mặc định: 1): ') " NET_CHOICE || true

case "${NET_CHOICE:-1}" in
    2)
        LAN_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
        ANYCRAWL_DOMAIN="http://${LAN_IP}:${ANYCRAWL_PORT}"
        ;;
    3)
        read -rp "  $(say 'Enter your public domain (e.g. anycrawl.example.com): ' 'Nhập domain công khai (ví dụ: anycrawl.example.com): ') " DOMAIN_INPUT || true
        ANYCRAWL_DOMAIN="https://${DOMAIN_INPUT:-localhost}"
        ;;
    *)
        ANYCRAWL_DOMAIN="http://localhost:${ANYCRAWL_PORT}"
        ;;
esac
pok "$(say "Base domain URL: $ANYCRAWL_DOMAIN" "URL domain gốc: $ANYCRAWL_DOMAIN")"

# ==============================================================================
# Step 4: Authoritative File Generation
# ==============================================================================
step_title "4/6" "Authoritative Configuration Generation" "Khởi tạo file cấu hình chuẩn"

# Render docker-compose.yml
cat << 'COMPOSE_EOF' > "$INSTALL_DIR/docker-compose.yml"
services:
  anycrawl:
    container_name: anycrawl_core
    image: anycrawl/anycrawl:latest
    restart: unless-stopped
    environment:
      # --- System ---
      NODE_ENV: production
      ANYCRAWL_API_PORT: ${ANYCRAWL_API_PORT}
      ANYCRAWL_HEADLESS: "true"
      ANYCRAWL_KEEPALIVE: "true"
      ANYCRAWL_AVAILABLE_ENGINES: ${ANYCRAWL_AVAILABLE_ENGINES}
      ANYCRAWL_IGNORE_SSL_ERROR: "true"

      # --- PostgreSQL ---
      ANYCRAWL_API_DB_TYPE: postgresql
      ANYCRAWL_API_DB_CONNECTION: "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"

      # --- Redis ---
      ANYCRAWL_REDIS_URL: "redis://redis:6379"

      # --- SearXNG ---
      ANYCRAWL_SEARCH_DEFAULT_ENGINE: searxng
      ANYCRAWL_SEARCH_ENABLED_ENGINES: searxng
      ANYCRAWL_SEARXNG_URL: http://searxng:8080

      # --- MinIO (S3) ---
      ANYCRAWL_S3_BUCKET: ${ANYCRAWL_S3_BUCKET:-anycrawl-data}
      ANYCRAWL_S3_REGION: us-east-1
      ANYCRAWL_S3_ENDPOINT: http://minio:9000
      ANYCRAWL_S3_ACCESS_KEY: ${MINIO_ROOT_USER}
      ANYCRAWL_S3_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}

      # --- AI Configuration ---
      DEFAULT_LLM_MODEL: ${DEFAULT_LLM_MODEL:-}
      DEFAULT_EXTRACT_MODEL: ${DEFAULT_EXTRACT_MODEL:-}
      DEFAULT_EMBEDDING_MODEL: ${DEFAULT_EMBEDDING_MODEL:-}
      CUSTOM_BASE_URL: ${CUSTOM_BASE_URL:-}
      CUSTOM_API_KEY: ${CUSTOM_API_KEY:-}

      # --- Credits & Timeouts ---
      ANYCRAWL_EXTRACT_JSON_CREDITS: ${ANYCRAWL_EXTRACT_JSON_CREDITS:-5}
      ANYCRAWL_PROXY_STEALTH_CREDITS: ${ANYCRAWL_PROXY_STEALTH_CREDITS:-5}
      ANYCRAWL_TEMPLATE_EXECUTION_TIMEOUT: ${ANYCRAWL_TEMPLATE_EXECUTION_TIMEOUT:-600000}
      ANYCRAWL_REQUEST_HANDLER_TIMEOUT_SECS: ${ANYCRAWL_REQUEST_HANDLER_TIMEOUT_SECS:-600}
      ANYCRAWL_AC_ENGINE_URL: ${ANYCRAWL_AC_ENGINE_URL:-}

    ports:
      - "${ANYCRAWL_API_PORT}:${ANYCRAWL_API_PORT}"
    volumes:
      - ./storage:/usr/src/app/storage
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
      searxng:
        condition: service_started
      minio:
        condition: service_healthy
    networks:
      - anycrawl-network

  postgres:
    image: postgres:17-alpine
    container_name: anycrawl_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}" ]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - anycrawl-network

  redis:
    image: redis:alpine
    container_name: anycrawl_redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    networks:
      - anycrawl-network

  minio:
    image: minio/minio
    container_name: anycrawl_minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio-data:/data
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:9000/minio/health/live" ]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - anycrawl-network

  # Optional: Create bucket automatically
  mc:
    image: minio/mc
    restart: "no"
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c '
      set -eu
      for i in $$(seq 1 15); do
        if /usr/bin/mc alias set myminio http://minio:9000 "$${MINIO_ROOT_USER}" "$${MINIO_ROOT_PASSWORD}" >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done
      if ! /usr/bin/mc ls "myminio/$${ANYCRAWL_S3_BUCKET:-anycrawl-data}" >/dev/null 2>&1; then
        /usr/bin/mc mb "myminio/$${ANYCRAWL_S3_BUCKET:-anycrawl-data}" >/dev/null 2>&1 || true
      fi
      /usr/bin/mc anonymous set download "myminio/$${ANYCRAWL_S3_BUCKET:-anycrawl-data}" >/dev/null 2>&1 || true
      exit 0
      '
    networks:
      - anycrawl-network

  searxng:
    image: searxng/searxng:latest
    container_name: anycrawl_searxng
    restart: unless-stopped
    environment:
      - SEARXNG_BASE_URL=http://localhost:8080/
    volumes:
      - ./searxng:/etc/searxng:rw
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
    networks:
      - anycrawl-network

  # Custom MCP Server for AnyCrawl
  mcp-server:
    build:
      context: ./mcp-server
      dockerfile: Dockerfile
    container_name: anycrawl_mcp
    restart: unless-stopped
    environment:
      ANYCRAWL_API_URL: http://anycrawl:8880
      ANYCRAWL_API_KEY: ${ANYCRAWL_API_KEY}
    ports:
      - "8889:8889" # SSE port
    depends_on:
      - anycrawl
    networks:
      - anycrawl-network

volumes:
  postgres-data:
  redis-data:
  minio-data:


networks:
  anycrawl-network:
    driver: bridge
COMPOSE_EOF

# Render searxng/settings.yml
cat << 'SETTINGS_EOF' > "$INSTALL_DIR/searxng/settings.yml"
use_default_settings: true
server:
  secret_key: "anycrawl_super_secure_random_secret_key_change_me_if_public" # Changed to avoid warning
  limiter: false
  image_proxy: true
search:
  formats:
    - html
    - json # REQUIRED for AnyCrawl
engines:
  - name: google
    engine: google
    use_mobile_ui: false
    disabled: false
  - name: bing
    engine: bing
    disabled: false
  - name: duckduckgo
    engine: duckduckgo
    disabled: false
SETTINGS_EOF

# Render mcp-server/Dockerfile
cat << 'DOCKERFILE_EOF' > "$INSTALL_DIR/mcp-server/Dockerfile"
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

# Expose port for SSE (if used) or stdio
EXPOSE 8889

CMD ["npm", "start"]
DOCKERFILE_EOF

# Render mcp-server/package.json
cat << 'PKG_EOF' > "$INSTALL_DIR/mcp-server/package.json"
{
  "name": "anycrawl-mcp-server",
  "version": "1.0.0",
  "description": "MCP Server for AnyCrawl",
  "type": "module",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.6.0",
    "axios": "^1.6.0",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "cors": "^2.8.5"
  }
}
PKG_EOF

# Render mcp-server/index.js
cat << 'INDEX_JS_EOF' > "$INSTALL_DIR/mcp-server/index.js"
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import axios from "axios";
import express from "express";
import cors from "cors";

// Configuration
const ANYCRAWL_API_URL = process.env.ANYCRAWL_API_URL || "http://localhost:8880";
const ANYCRAWL_API_KEY = process.env.ANYCRAWL_API_KEY || "YOUR_API_KEY";
const PORT = process.env.PORT || 8889;

// Helper function to call AnyCrawl API
async function callAnyCrawl(endpoint, method, data) {
    try {
        const url = `${ANYCRAWL_API_URL}${endpoint}`;
        console.error(`Calling AnyCrawl: ${method} ${url}`);
        const response = await axios({
            method,
            url,
            headers: {
                "Content-Type": "application/json",
                "x-api-key": ANYCRAWL_API_KEY // AnyCrawl use x-api-key
            },
            data,
        });
        return response.data;
    } catch (error) {
        console.error("AnyCrawl API Error:", error.message);
        if (error.response) {
            console.error("Response data:", error.response.data);
            throw new Error(`AnyCrawl API Error: ${JSON.stringify(error.response.data)}`);
        }
        throw error;
    }
}

// Helper to create a fresh server instance
// We need this because the SDK Server is stateful (once initialized, it rejects new initialize requests).
// For stateless HTTP (LobeHub), we treat each request as a fresh session.
const TOOLS = [
    {
        name: "crawl_url",
        description: "Crawl a single URL and return the content (markdown/html).",
        inputSchema: {
            type: "object",
            properties: {
                url: { type: "string", description: " The URL to crawl" },
            },
            required: ["url"],
        },
    },
    {
        name: "search",
        description: "Search the web using AnyCrawl's integrated search engine (SearXNG).",
        inputSchema: {
            type: "object",
            properties: {
                query: { type: "string", description: "Search query" },
                limit: { type: "number", description: "Number of results (default 5)" },
            },
            required: ["query"],
        },
    },
    {
        name: "crawl_status",
        description: "Check the status of a crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID returned by crawl_url" },
            },
            required: ["id"],
        },
    },
    {
        name: "scrape_url",
        description: "Scrape a single URL synchronously with optional AI extraction and screenshots.",
        inputSchema: {
            type: "object",
            properties: {
                url: { type: "string", description: "The URL to scrape" },
                engine: { type: "string", enum: ["playwright", "cheerio"], description: "Scraping engine to use" },
                json_options: {
                    type: "object",
                    description: "AI extraction schema. Example: { \"product_name\": \"string\", \"price\": \"number\" }"
                },
                screenshot: { type: "boolean", description: "Whether to capture a screenshot" }
            },
            required: ["url"],
        },
    },
    {
        name: "crawl_results",
        description: "Fetch the results of a completed crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID" },
                skip: { type: "number", description: "Number of results to skip (pagination)" }
            },
            required: ["id"],
        },
    },
    {
        name: "crawl_cancel",
        description: "Cancel an active crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID" }
            },
            required: ["id"],
        },
    },
    {
        name: "list_scheduled_tasks",
        description: "List all scheduled automation tasks.",
        inputSchema: { type: "object", properties: {} }
    },
    {
        name: "list_webhooks",
        description: "List all configured webhook subscriptions.",
        inputSchema: { type: "object", properties: {} }
    },
];

// Helper to create a fresh server instance for SSE
function createMCPServer() {
    const server = new Server(
        {
            name: "anycrawl-mcp",
            version: "1.0.0",
        },
        {
            capabilities: {
                tools: {},
            },
        }
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        try {
            let result;
            if (name === "crawl_url") {
                result = await callAnyCrawl("/v1/crawl", "POST", { url: args.url });
            } else if (name === "search") {
                result = await callAnyCrawl("/v1/search", "POST", { query: args.query, limit: args.limit || 5 });
            } else if (name === "crawl_status") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}/status`, "GET");
            } else if (name === "scrape_url") {
                result = await callAnyCrawl("/v1/scrape", "POST", {
                    url: args.url,
                    engine: args.engine || "playwright",
                    options: {
                        json_options: args.json_options,
                        formats: args.screenshot ? ["html", "markdown", "screenshot"] : ["html", "markdown"]
                    }
                });
            } else if (name === "crawl_results") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}?skip=${args.skip || 0}`, "GET");
            } else if (name === "crawl_cancel") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}`, "DELETE");
            } else if (name === "list_scheduled_tasks") {
                result = await callAnyCrawl("/v1/scheduled-tasks", "GET");
            } else if (name === "list_webhooks") {
                result = await callAnyCrawl("/v1/webhooks", "GET");
            } else {
                throw new Error(`Unknown tool: ${name}`);
            }

            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        } catch (error) {
            return {
                content: [{ type: "text", text: `Error: ${error.message}` }],
                isError: true,
            };
        }
    });

    return server;
}

// Global server for standard SSE connections (stateful)
const globalServer = createMCPServer();

const app = express();

// 1. Logger first to capture everything
app.use((req, res, next) => {
    // Log headers to debug what client sends
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - SessionID: ${req.query.sessionId || 'none'}`);
    console.log(`Buffers: headers=${JSON.stringify(req.headers)}`);
    next();
});

// 2. CORS with specific options
app.use(cors({
    origin: true, // Allow all origins reflected
    credentials: true,
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "x-api-key", "mcp-version", "x-session-id", "mcp-protocol-version"]
}));

app.use(express.json());

// Map to store active transports: sessionId -> transport
const transports = new Map();

app.get("/sse", async (req, res) => {
    console.log("New SSE connection attempt");

    // Create a new transport
    const transport = new SSEServerTransport("/sse", res);

    console.log(`Transport created, session ID: ${transport.sessionId}`);
    transports.set(transport.sessionId, transport);

    transport.onclose = () => {
        console.log(`Transport closed, session ID: ${transport.sessionId}`);
        transports.delete(transport.sessionId);
    };

    await globalServer.connect(transport);
});

// Manual MCP handler for stateless requests (LobeHub)
async function handleStatelessRequest(req, res) {
    const { jsonrpc, id, method, params } = req.body;
    console.log(`Handling stateless request: ${method} (ID: ${id})`);

    try {
        if (method === "initialize") {
            return res.json({
                jsonrpc: "2.0",
                id,
                result: {
                    protocolVersion: "2024-11-05",
                    capabilities: { tools: {} },
                    serverInfo: { name: "anycrawl-mcp", version: "1.0.0" }
                }
            });
        }

        if (method === "notifications/initialized") {
            return res.status(202).end();
        }

        if (method === "tools/list") {
            return res.json({
                jsonrpc: "2.0",
                id,
                result: { tools: TOOLS }
            });
        }

        if (method === "tools/call") {
            const { name, arguments: args } = params;
            console.log(`Tool call: ${name}`, args);

            let result;
            if (name === "crawl_url") {
                result = await callAnyCrawl("/v1/crawl", "POST", { url: args.url });
            } else if (name === "search") {
                result = await callAnyCrawl("/v1/search", "POST", { query: args.query, limit: args.limit || 5 });
            } else if (name === "crawl_status") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}/status`, "GET");
            } else if (name === "scrape_url") {
                result = await callAnyCrawl("/v1/scrape", "POST", {
                    url: args.url,
                    engine: args.engine || "playwright",
                    options: {
                        json_options: args.json_options,
                        formats: args.screenshot ? ["html", "markdown", "screenshot"] : ["html", "markdown"]
                    }
                });
            } else if (name === "crawl_results") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}?skip=${args.skip || 0}`, "GET");
            } else if (name === "crawl_cancel") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}`, "DELETE");
            } else if (name === "list_scheduled_tasks") {
                result = await callAnyCrawl("/v1/scheduled-tasks", "GET");
            } else if (name === "list_webhooks") {
                result = await callAnyCrawl("/v1/webhooks", "GET");
            } else {
                return res.status(404).json({
                    jsonrpc: "2.0",
                    id,
                    error: { code: -32601, message: `Method not found: ${name}` }
                });
            }

            return res.json({
                jsonrpc: "2.0",
                id,
                result: {
                    content: [{ type: "text", text: JSON.stringify(result, null, 2) }]
                }
            });
        }

        // Generic error for unknown methods
        return res.status(404).json({
            jsonrpc: "2.0",
            id,
            error: { code: -32601, message: `Method not found: ${method}` }
        });

    } catch (error) {
        console.error("Stateless handler error:", error);
        return res.status(500).json({
            jsonrpc: "2.0",
            id,
            error: { code: -32603, message: error.message }
        });
    }
}

async function handleMessage(req, res) {
    const sessionId = req.query.sessionId;

    // 1. Try to find existing SSE transport
    if (sessionId) {
        const transport = transports.get(sessionId);
        if (transport) {
            await transport.handlePostMessage(req, res);
            return;
        }
    }

    // 2. Fallback: No session ID or no existing transport -> handle as stateless request
    console.log("No session ID or transport found, handling as stateless request.");
    await handleStatelessRequest(req, res);
}

// Handle POST on both endpoints
app.post("/sse", handleMessage);
app.post("/messages", handleMessage);

app.listen(PORT, () => {
    console.log(`AnyCrawl MCP Server running on port ${PORT}`);
    console.log(`SSE endpoint: http://localhost:${PORT}/sse`);
    console.log(`Message endpoint: http://localhost:${PORT}/sse`);
});
INDEX_JS_EOF

# Synchronize back to repo sibling files if run from cloned repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -d "$SCRIPT_DIR/searxng" && -d "$SCRIPT_DIR/mcp-server" ]]; then
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
    cp -f "$INSTALL_DIR/searxng/settings.yml" "$SCRIPT_DIR/searxng/settings.yml" 2>/dev/null || true
    cp -f "$INSTALL_DIR/mcp-server/Dockerfile" "$SCRIPT_DIR/mcp-server/Dockerfile" 2>/dev/null || true
    cp -f "$INSTALL_DIR/mcp-server/package.json" "$SCRIPT_DIR/mcp-server/package.json" 2>/dev/null || true
    cp -f "$INSTALL_DIR/mcp-server/index.js" "$SCRIPT_DIR/mcp-server/index.js" 2>/dev/null || true
fi
pok "$(say 'Docker Compose and MCP configurations created.' 'Đã khởi tạo docker-compose và MCP server.')"

# Generate or preserve .env
if [ -f .env ]; then
    pwn "$(say '.env file already exists. Preserving existing secrets.' 'File .env đã tồn tại. Giữ nguyên secrets hiện có.')"
    chmod 600 .env
else
    API_KEY=$(openssl rand -hex 16)
    MINIO_ROOT_USER="admin"
    MINIO_ROOT_PASSWORD=$(openssl rand -hex 12)
    POSTGRES_PASSWORD=$(openssl rand -hex 12)

    cat <<ENVEOF > .env
# --- General ---
NODE_ENV=production
ANYCRAWL_NAME=AnyCrawl
ANYCRAWL_DOMAIN=${ANYCRAWL_DOMAIN}
ANYCRAWL_API_PORT=${ANYCRAWL_PORT}
ANYCRAWL_API_KEY=${API_KEY}
ANYCRAWL_API_AUTH_ENABLED=true

# --- Engine ---
ANYCRAWL_HEADLESS=true
ANYCRAWL_AVAILABLE_ENGINES=playwright,cheerio
ANYCRAWL_IGNORE_SSL_ERROR=true

# --- Database ---
POSTGRES_USER=anycrawl
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=anycrawl_db
ANYCRAWL_API_DB_TYPE=postgresql

# --- Redis ---
ANYCRAWL_REDIS_URL=redis://redis:6379

# --- MinIO (S3) ---
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
ANYCRAWL_S3_BUCKET=anycrawl-data
ANYCRAWL_S3_ENDPOINT=http://minio:9000

# --- Search ---
ANYCRAWL_SEARCH_DEFAULT_ENGINE=searxng
ANYCRAWL_SEARCH_ENABLED_ENGINES=searxng
ANYCRAWL_SEARXNG_URL=http://searxng:8080

# --- Advanced ---
ANYCRAWL_SCHEDULER_ENABLED=true
ANYCRAWL_WEBHOOKS_ENABLED=true
ANYCRAWL_MAX_CONCURRENCY=20

# --- AI (Optional) ---
DEFAULT_LLM_MODEL=
DEFAULT_EXTRACT_MODEL=
DEFAULT_EMBEDDING_MODEL=
OPENAI_API_KEY=
CUSTOM_BASE_URL=
CUSTOM_API_KEY=

# --- Credits & Performance ---
ANYCRAWL_EXTRACT_JSON_CREDITS=5
ANYCRAWL_PROXY_STEALTH_CREDITS=5
ANYCRAWL_TEMPLATE_EXECUTION_TIMEOUT=600000
ANYCRAWL_REQUEST_HANDLER_TIMEOUT_SECS=600
ANYCRAWL_AC_ENGINE_URL=
ENVEOF
    chmod 600 .env
    pok "$(say '.env generated with secure credentials (chmod 600).' 'Đã tạo file .env bảo mật (chmod 600).')"
fi

# ==============================================================================
# Step 5: Helper CLI (anycrawl.sh)
# ==============================================================================
step_title "5/6" "Helper Management CLI" "Trình điều khiển quản lý"

cat << 'HELPER_EOF' > "$INSTALL_DIR/anycrawl.sh"
#!/usr/bin/env bash
# AnyCrawl Management CLI (Gen 4 Standard)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
CMD="${1:-help}"

case "$CMD" in
  status)
    echo "=== AnyCrawl Services Status ==="
    docker compose ps
    echo ""
    echo "=== Health Diagnostics ==="
    docker exec anycrawl_postgres pg_isready -U anycrawl &>/dev/null && echo "  [OK] PostgreSQL" || echo "  [WARN] PostgreSQL not ready"
    docker exec anycrawl_redis redis-cli ping &>/dev/null && echo "  [OK] Redis" || echo "  [WARN] Redis not responding"
    curl -sf http://localhost:9000/minio/health/live &>/dev/null && echo "  [OK] MinIO S3" || echo "  [WARN] MinIO not responding"
    curl -sf http://localhost:8880 &>/dev/null && echo "  [OK] AnyCrawl API" || echo "  [WARN] AnyCrawl API not responding"
    ;;
  start)
    echo "Starting AnyCrawl stack..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping AnyCrawl stack..."
    docker compose stop
    ;;
  restart)
    echo "Restarting AnyCrawl stack..."
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-anycrawl}"
    ;;
  update)
    echo "Backing up .env..."
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo "Pulling latest container images..."
    docker compose pull
    echo "Rebuilding MCP server..."
    docker compose build mcp-server
    echo "Restarting stack..."
    docker compose up -d --remove-orphans
    echo "Update completed!"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/anycrawl_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/anycrawl_cfg_$TIMESTAMP.tar.gz"
    
    echo "Dumping PostgreSQL database..."
    if docker exec anycrawl_postgres pg_dump -U anycrawl anycrawl_db | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo "  ✓ Database archived to: $DB_ARCHIVE"
    else
      echo "  ✗ Database dump failed!"
    fi
    
    echo "Archiving configurations..."
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml searxng/settings.yml 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo "  ✓ Configuration archived to: $CFG_ARCHIVE"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo "Usage: ./anycrawl.sh restore <path-to-sql-gz-archive>"
      exit 1
    fi
    echo "Verifying archive integrity..."
    gzip -t "$FILE"
    echo "WARNING: Restoring database will overwrite current anycrawl_db data!"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      gunzip -c "$FILE" | docker exec -i anycrawl_postgres psql -U anycrawl -d anycrawl_db
      echo "Database restore completed successfully!"
    else
      echo "Restore aborted."
    fi
    ;;
  doctor)
    echo "=== AnyCrawl System Doctor ==="
    echo "Checking Docker..."
    docker --version || echo "  [FAIL] Docker not found"
    docker compose version || echo "  [FAIL] Docker Compose not found"
    echo "Checking Disk Space:"
    df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env mode: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo "Testing Port Bindings:"
    for p in 8880 9000 9001 8080 8889; do
      if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
        echo "  [BOUND] Port $p is listening"
      else
        echo "  [OPEN/UNKNOWN] Port $p"
      fi
    done
    ;;
  uninstall)
    echo "WARNING: This will completely destroy AnyCrawl containers and data volumes."
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo "Containers and volumes removed."
    else
      echo "Uninstall canceled."
    fi
    ;;
  *)
    echo "Usage: ./anycrawl.sh {status|start|stop|restart|logs|update|backup|restore|doctor|uninstall}"
    ;;
esac
HELPER_EOF

chmod +x "$INSTALL_DIR/anycrawl.sh"
sudo ln -sf "$INSTALL_DIR/anycrawl.sh" /usr/local/bin/anycrawl 2>/dev/null || true
pok "$(say 'Helper CLI anycrawl.sh installed (available as anycrawl).' 'Đã cài đặt trình quản lý anycrawl.sh (gọi bằng anycrawl).')"

# ==============================================================================
# Step 6: Container Startup & Database Migration
# ==============================================================================
step_title "6/6" "Starting Containers & Migration" "Khởi động container & Migration"

# Host files ownership before launch
if [[ -n "${TARGET_USER:-}" && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR" 2>/dev/null || true
fi

echo "  → $(say 'Building MCP server and launching containers...' 'Đang build MCP server và khởi động containers...')"
docker compose up -d --build

echo "  → $(say 'Waiting for PostgreSQL database readiness...' 'Đang đợi cơ sở dữ liệu PostgreSQL sẵn sàng...')"
for i in $(seq 1 20); do
    if docker exec anycrawl_postgres pg_isready -U anycrawl -d anycrawl_db &>/dev/null; then
        pok "$(say 'PostgreSQL is ready.' 'PostgreSQL đã sẵn sàng.')"
        break
    fi
    sleep 2
done

# Safe host-files-only ownership adjustment post startup (preserving container internal UIDs)
find "$INSTALL_DIR" -maxdepth 1 -type f -exec chown "$TARGET_USER:$TARGET_GROUP" {} + 2>/dev/null || true

echo ""
echo "================================================================"
echo -e "${GREEN}${BOLD}  🎉 $(say 'ANYCRAWL SETUP COMPLETED SUCCESSFULLY!' 'CÀI ĐẶT ANYCRAWL HOÀN TẤT THÀNH CÔNG!')${NC}"
echo "================================================================"
echo -e "  • AnyCrawl API:    ${PURPLE}http://localhost:${ANYCRAWL_PORT}${NC}"
echo -e "  • MinIO Console:   ${PURPLE}http://localhost:${MINIO_CONSOLE_PORT}${NC}"
echo -e "  • SearXNG Search:  ${PURPLE}http://localhost:${SEARXNG_PORT}${NC}"
echo -e "  • MCP Server:      ${PURPLE}http://localhost:${MCP_PORT}/sse${NC}"
echo -e "  • Config file:     ${PURPLE}$INSTALL_DIR/.env${NC} (chmod 600)"
echo -e "  • Helper CLI:      ${PURPLE}anycrawl${NC} (or ./anycrawl.sh)"
echo "================================================================"
echo "$(say 'Quick management commands:' 'Các lệnh quản lý nhanh:'):"
echo "  • anycrawl status"
echo "  • anycrawl logs"
echo "  • anycrawl backup"
echo "  • anycrawl doctor"
echo "  • anycrawl update"
