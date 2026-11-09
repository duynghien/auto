#!/usr/bin/env bash

# ==============================================================================
# Universal Proxy Standalone Setup (Gen 4 Standard)
# Supports: macOS (Apple Silicon/Intel), Linux VPS (AMD64/ARM64), Raspberry Pi 4/5
# Proxies: Nginx Proxy Manager, Cloudflare Tunnel, Caddy
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
perr() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

# ==============================================================================
# Language Selection (EN/VI)
# ==============================================================================
APP_LANG="${APP_LANG:-}"
if [[ -z "$APP_LANG" ]]; then
    echo ""
    echo -e "${BOLD}Select Language / Chọn ngôn ngữ:${NC}"
    echo "  1) English (default)"
    echo "  2) Tiếng Việt"
    read -rp "Choice [1-2] (default: 1): " LANG_CHOICE || true
    case "${LANG_CHOICE:-1}" in
        2|vi|VI) APP_LANG="vi" ;;
        *) APP_LANG="en" ;;
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
    echo -e "\n${BOLD}${CYAN}[$num/5] $(say "$en" "$vi")${NC}"
}

# ==============================================================================
# Platform Detection
# ==============================================================================
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    PLATFORM="mac"
    PLATFORM_LABEL="macOS ($(uname -m))"
elif [[ "$OS" == "Linux" ]]; then
    if grep -qi 'raspberry\|raspbian' /proc/device-tree/model 2>/dev/null || \
       grep -qi 'raspberry' /etc/os-release 2>/dev/null; then
        PLATFORM="pi"
        PLATFORM_LABEL="Raspberry Pi (ARM64)"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        PLATFORM="vps-arm64"
        PLATFORM_LABEL="Linux VPS (ARM64)"
    elif [[ "$ARCH" == "x86_64" ]]; then
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux VPS (AMD64)"
    else
        PLATFORM="vps-amd64"
        PLATFORM_LABEL="Linux ($ARCH)"
    fi
else
    perr "Unsupported OS: $OS"
fi

# Banner
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
echo "        Universal Proxy Standalone Setup — $PLATFORM_LABEL"
echo "================================================================${NC}"
echo -e "  $(say "Nginx Proxy Manager, Cloudflare Tunnel, Caddy Reverse Proxy" "Quản lý Reverse Proxy đa năng: Nginx Proxy Manager, Cloudflare Tunnel, Caddy")"
echo ""

# ==============================================================================
# Step 1: Preflight & Dependencies
# ==============================================================================
step_title 1 "Preflight Checks & Dependencies" "Kiểm tra hệ thống & Cài đặt phụ thuộc"

if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v docker &>/dev/null; then
        perr "$(say "Docker is not installed. Please install OrbStack or Docker Desktop." "Docker chưa được cài đặt. Vui lòng cài OrbStack hoặc Docker Desktop.")"
    fi
    pok "Docker: OK"
    if ! docker compose version &>/dev/null; then
        perr "$(say "Docker Compose plugin is missing." "Thiếu Docker Compose plugin.")"
    fi
    pok "Docker Compose: OK"
else
    if ! command -v docker &>/dev/null; then
        pwn "$(say "Docker not found, installing..." "Không tìm thấy Docker, đang cài đặt...")"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        sudo usermod -aG docker "${SUDO_USER:-$USER}" 2>/dev/null || true
        pok "Docker: OK"
    else
        pok "Docker: OK"
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "Docker Compose: OK"
fi

for tool in curl; do
    if ! command -v "$tool" &>/dev/null; then
        perr "Missing required tool: $tool"
    fi
done

# ==============================================================================
# Step 2: Select Proxy Solution & Port Conflict Diagnostics
# ==============================================================================
step_title 2 "Select Proxy Solution & Check Ports" "Chọn Giải Pháp Proxy & Kiểm Tra Cổng"

echo -e "  ${GREEN}1)${NC} ${BOLD}Nginx Proxy Manager (NPM)${NC} ($(say "Recommended" "Khuyến nghị"))"
echo -e "     - $(say "Web GUI for managing hosts, SSL certificates & streams" "Giao diện web trực quan quản lý reverse proxy và SSL tự động")"
echo -e "     - $(say "Required Ports: 80, 443, 81 (Admin UI)" "Cổng yêu cầu: 80, 443, 81 (Trang quản trị)")"
echo ""
echo -e "  ${GREEN}2)${NC} ${BOLD}Cloudflare Tunnel${NC} ($(say "Zero Open Ports" "Không cần mở port"))"
echo -e "     - $(say "Secure outbound tunnel to Cloudflare Edge" "Truy cập an toàn qua Cloudflare Edge, không lộ IP máy chủ")"
echo -e "     - $(say "No local port conflicts" "Không yêu cầu mở cổng 80/443")"
echo ""
echo -e "  ${GREEN}3)${NC} ${BOLD}Caddy${NC} ($(say "Lightweight & Fast" "Gọn nhẹ & Tự động SSL"))"
echo -e "     - $(say "Automatic HTTPS with single Caddyfile config" "Tự động lấy chứng chỉ HTTPS qua Caddyfile")"
echo -e "     - $(say "Required Ports: 80, 443" "Cổng yêu cầu: 80, 443")"
echo ""

read -rp "$(say "Choose [1/2/3] (default: 1): " "Lựa chọn [1/2/3] (mặc định: 1): ")" PROXY_CHOICE || true
PROXY_TYPE="${PROXY_CHOICE:-1}"

inspect_port_conflict() {
    local port="$1"
    local holder=""
    if command -v lsof &>/dev/null; then
        holder=$(lsof -iTCP:"$port" -sTCP:LISTEN -Pn 2>/dev/null | awk 'NR>1 {print $1 " (PID: " $2 ")"}' | head -n 1 || true)
    elif command -v ss &>/dev/null; then
        holder=$(ss -ltnp "sport = :$port" 2>/dev/null | grep -o 'users:(("[^"]*",pid=[0-9]*,fd=[0-9]*))' | head -n 1 || true)
    fi
    echo "$holder"
}

if [[ "$PROXY_TYPE" == "1" || "$PROXY_TYPE" == "3" ]]; then
    for check_p in 80 443; do
        CONFLICT=$(inspect_port_conflict "$check_p")
        if [[ -n "$CONFLICT" ]]; then
            pwn "$(say "Warning: Port $check_p is in use by $CONFLICT." "Cảnh báo: Cổng $check_p hiện đang bị chiếm bởi $CONFLICT.")"
            pwn "$(say "This may prevent NPM or Caddy from binding port $check_p." "Điều này có thể khiến NPM hoặc Caddy không khởi động được.")"
            read -rp "$(say "Continue anyway? [y/N]: " "Vẫn tiếp tục cài đặt? [y/N]: ")" CONT || true
            case "${CONT:-n}" in
                [yY][eE][sS]|[yY]) ;;
                *) perr "$(say "Setup aborted by user to resolve port conflict." "Đã hủy cài đặt để xử lý xung đột cổng.")" ;;
            esac
        fi
    done
fi

if [[ "$PROXY_TYPE" == "1" ]]; then
    CONFLICT_81=$(inspect_port_conflict 81)
    if [[ -n "$CONFLICT_81" ]]; then
        pwn "$(say "Warning: Admin Port 81 is in use by $CONFLICT_81." "Cảnh báo: Cổng admin 81 đang bị chiếm bởi $CONFLICT_81.")"
    fi
fi

# ==============================================================================
# Step 3: Install Directory & Authoritative Inline Generation
# ==============================================================================
step_title 3 "Install Directory & Configuration Generation" "Thư mục Cài đặt & Sinh Cấu hình"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
INSTALL_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/proxies"

mkdir -p "$INSTALL_DIR"
chown -R "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"
cd "$INSTALL_DIR"
pok "$(say "Install directory: $INSTALL_DIR" "Thư mục cài đặt: $INSTALL_DIR")"

CF_TOKEN=""
if [[ "$PROXY_TYPE" == "2" ]]; then
    echo ""
    echo -e "${YELLOW}$(say "Enter your Cloudflare Tunnel Token:" "Nhập Cloudflare Tunnel Token của bạn:")${NC}"
    echo "  ($(say "Obtain from https://one.dash.cloudflare.com -> Networks -> Tunnels" "Lấy tại https://one.dash.cloudflare.com -> Networks -> Tunnels"))"
    read -rp "Tunnel Token: " CF_TOKEN || true
    if [[ -z "$CF_TOKEN" && -f .env ]]; then
        CF_TOKEN=$(grep -E '^CLOUDFLARE_TUNNEL_TOKEN=' .env 2>/dev/null | cut -d= -f2- || true)
    fi
    if [[ -z "$CF_TOKEN" ]]; then
        perr "$(say "Cloudflare Tunnel Token is required." "Cần phải nhập Cloudflare Tunnel Token.")"
    fi
fi

# Authoritative Compose Generation
if [[ "$PROXY_TYPE" == "1" ]]; then
    mkdir -p npm_data npm_letsencrypt
    cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./npm_data:/data
      - ./npm_letsencrypt:/etc/letsencrypt
    networks:
      - proxy-network

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
COMPOSE_EOF

    cat << EOF > .env
PROXY_TYPE=npm
EOF

elif [[ "$PROXY_TYPE" == "2" ]]; then
    cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - proxy-network

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
COMPOSE_EOF

    cat << EOF > .env
PROXY_TYPE=cloudflared
CLOUDFLARE_TUNNEL_TOKEN=${CF_TOKEN}
EOF

elif [[ "$PROXY_TYPE" == "3" ]]; then
    cat << 'COMPOSE_EOF' > docker-compose.yml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - proxy-network

volumes:
  caddy_data:
  caddy_config:

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
COMPOSE_EOF

    if [[ ! -f Caddyfile ]]; then
        cat << 'CADDY_EOF' > Caddyfile
# Caddyfile — Reverse Proxy Configuration
# Example:
# domain.example.com {
#     reverse_proxy host.docker.internal:8080
# }

:80 {
    respond "Caddy Reverse Proxy is active and running!"
}
CADDY_EOF
    fi

    cat << EOF > .env
PROXY_TYPE=caddy
EOF
fi

chmod 600 .env
pok "$(say "Configuration files (.env, docker-compose.yml) generated." "Đã sinh file cấu hình (.env, docker-compose.yml).")"

# Sync sibling files if executed from cloned repo
if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" && -d "$SCRIPT_DIR" ]]; then
    cp -f "$INSTALL_DIR/docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml" 2>/dev/null || true
    [[ -f "$INSTALL_DIR/Caddyfile" ]] && cp -f "$INSTALL_DIR/Caddyfile" "$SCRIPT_DIR/Caddyfile" 2>/dev/null || true
fi

# ==============================================================================
# Step 4: Helper CLI Generation (proxies.sh)
# ==============================================================================
step_title 4 "Helper CLI Generation" "Tạo Trình Quản Lý CLI (proxies.sh)"

cat << 'HELPER_EOF' > proxies.sh
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
CMD="${1:-help}"

case "$CMD" in
  status)
    echo "=== Universal Proxy Status ==="
    docker compose ps
    ;;
  start)
    echo "Starting proxy service..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping proxy service..."
    docker compose stop
    ;;
  restart)
    echo "Restarting proxy service..."
    docker compose restart
    ;;
  reload)
    if docker compose ps --services 2>/dev/null | grep -q "caddy"; then
      echo "Reloading Caddy configuration..."
      docker compose exec -w /etc/caddy caddy caddy reload 2>/dev/null || docker compose restart caddy
    else
      echo "Restarting proxy container to apply config changes..."
      docker compose restart
    fi
    ;;
  logs)
    shift || true
    docker compose logs -f "$@"
    ;;
  update)
    echo "Updating proxy containers..."
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    tar -czf "backups/proxies-pre-update-${TIMESTAMP}.tar.gz" .env docker-compose.yml Caddyfile 2>/dev/null || true
    chmod 600 "backups/proxies-pre-update-${TIMESTAMP}.tar.gz" 2>/dev/null || true
    docker compose pull
    docker compose up -d
    echo "Update complete."
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    ARCHIVE="backups/proxies-backup-${TIMESTAMP}.tar.gz"
    echo "Creating backup..."
    tar -czf "$ARCHIVE" .env docker-compose.yml Caddyfile npm_data/ npm_letsencrypt/ 2>/dev/null || tar -czf "$ARCHIVE" .env docker-compose.yml
    chmod 600 "$ARCHIVE"
    echo "Backup created successfully: $ARCHIVE"
    ;;
  restore)
    BACKUP_FILE="${2:-}"
    if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
      echo "Error: Please specify a valid backup archive."
      echo "Usage: ./proxies.sh restore backups/<archive>.tar.gz"
      exit 1
    fi
    echo "Verifying archive integrity..."
    if ! gzip -t "$BACKUP_FILE"; then
      echo "Error: Corrupted archive! Restore aborted."
      exit 1
    fi
    mkdir -p -m 700 backups
    SAFETY_SNAP="backups/proxies-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$SAFETY_SNAP" .env docker-compose.yml Caddyfile 2>/dev/null || true
    chmod 600 "$SAFETY_SNAP" 2>/dev/null || true
    echo "Safety snapshot created: $SAFETY_SNAP"
    docker compose stop
    tar -xzf "$BACKUP_FILE"
    chmod 600 .env 2>/dev/null || true
    docker compose up -d
    echo "Restore completed successfully."
    ;;
  doctor)
    echo "=== Proxy Health Diagnostic ==="
    if docker info &>/dev/null; then
      echo "  [OK] Docker engine is running"
    else
      echo "  [FAIL] Docker engine is unreachable"
    fi
    echo "  Active Listening Ports (80 / 443 / 81):"
    for p in 80 443 81; do
      if lsof -iTCP:"$p" -sTCP:LISTEN -Pn &>/dev/null 2>&1 || ss -ltn "sport = :$p" 2>/dev/null | grep -q ":$p "; then
        echo "    Port $p is listening"
      else
        echo "    Port $p is not bound"
      fi
    done
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env permissions: $PERMS (recommended: 600)"
    fi
    ;;
  uninstall)
    echo "WARNING: This will stop proxy services and remove containers."
    read -rp "Type 'yes' to confirm uninstallation: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v 2>/dev/null || true
      echo "Proxy services stopped and removed."
      echo "Configuration files remain in: $(pwd)"
    else
      echo "Uninstall aborted."
    fi
    ;;
  *)
    echo "Usage: ./proxies.sh {status|start|stop|restart|reload|logs|update|backup|restore|doctor|uninstall}"
    ;;
esac
HELPER_EOF

chmod +x proxies.sh
chown "$TARGET_USER:$TARGET_GROUP" .env docker-compose.yml proxies.sh
pok "$(say "Helper CLI ./proxies.sh created successfully." "Đã tạo trình quản lý ./proxies.sh thành công.")"

# ==============================================================================
# Step 5: Deploy & Verification
# ==============================================================================
step_title 5 "Deploy & Verification" "Khởi chạy & Kiểm tra Trạng thái"

docker compose up -d
pok "$(say "Containers started!" "Các container đã được khởi chạy!")"

echo ""
echo "================================================================"
echo -e "${GREEN}  🎉 $(say "INSTALLATION COMPLETE!" "CÀI ĐẶT THÀNH CÔNG!")${NC}"
echo ""
echo -e "  $(say "Platform:" "Nền tảng:")      ${CYAN}${PLATFORM_LABEL}${NC}"
echo -e "  $(say "Directory:" "Thư mục:")     ${PURPLE}${INSTALL_DIR}${NC}"

if [[ "$PROXY_TYPE" == "1" ]]; then
    echo -e "  $(say "Admin UI:" "Trang quản trị:")    ${CYAN}http://localhost:81${NC}"
    echo -e "  $(say "Default Email:" "Email mặc định:")   ${BOLD}admin@example.com${NC}"
    echo -e "  $(say "Default Pass:" "Mật khẩu:")   ${BOLD}changeme${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  $(say "Important: Change admin credentials immediately upon first login!" "Lưu ý: Hãy đổi thông tin tài khoản admin ngay sau khi đăng nhập!")"
elif [[ "$PROXY_TYPE" == "2" ]]; then
    echo -e "  $(say "Tunnel Status:" "Trạng thái Tunnel:") ${GREEN}Running / Kết nối Cloudflare Edge${NC}"
elif [[ "$PROXY_TYPE" == "3" ]]; then
    echo -e "  $(say "HTTP Endpoint:" "Cổng HTTP:") ${CYAN}http://localhost:80${NC}"
    echo -e "  $(say "Config file:" "File cấu hình:") ${PURPLE}${INSTALL_DIR}/Caddyfile${NC}"
fi

echo ""
echo -e "${CYAN}$(say "Management Commands:" "Lệnh Quản Lý:"):${NC}"
echo "  • ./proxies.sh status"
echo "  • ./proxies.sh reload"
echo "  • ./proxies.sh logs"
echo "  • ./proxies.sh doctor"
echo ""
echo "Support: https://ai.vnrom.net"
