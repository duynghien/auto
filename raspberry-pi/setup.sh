#!/usr/bin/env bash

# ==============================================================================
# Raspberry Pi ARM Toolbox & Portainer Setup (Gen 4 Standard)
# Supports: Raspberry Pi 4/5, Debian/Ubuntu ARM64/ARMv7
# Author: duynghien (vnROM.net)
# ==============================================================================

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
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

# OS / Root Preflight
if [[ "$(uname -s)" != "Linux" ]]; then
    perr "This script is designed for Linux (Raspberry Pi OS / Ubuntu / Debian). Detected: $(uname -s)"
fi

if [[ "$EUID" -ne 0 ]]; then
    perr "Please run as root (sudo ./setup.sh)"
fi

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

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")
ACTUAL_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || eval echo "~$TARGET_USER")
INSTALL_DIR="${ACTUAL_HOME:-$HOME}/self-hosted/raspberry-pi"
mkdir -p "$INSTALL_DIR"
chown "$TARGET_USER:$TARGET_GROUP" "$INSTALL_DIR"

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
echo "       Raspberry Pi ARM Toolbox — Gen 4 Standard"
echo "================================================================${NC}"
echo -e "  $(say "Hardware optimization, Docker & Portainer CE manager" "Tối ưu phần cứng, cài đặt Docker và quản lý Portainer CE")"
echo ""

install_docker() {
    echo -e "\n${BOLD}${CYAN}=== $(say "Installing Docker Engine & Docker Compose" "Cài đặt Docker Engine & Docker Compose") ===${NC}"
    if command -v docker &>/dev/null; then
        pok "$(say "Docker is already installed" "Docker đã được cài đặt sẵn")"
    else
        pwn "$(say "Installing Docker via official get.docker.com script..." "Cài Docker qua script chính thức get.docker.com...")"
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
        usermod -aG docker "$TARGET_USER" 2>/dev/null || true
        pok "$(say "Docker Engine installed" "Đã cài đặt xong Docker Engine")"
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
    fi
    pok "$(say "Docker Compose plugin ready" "Plugin Docker Compose đã sẵn sàng")"

    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true
    pok "$(say "Docker service enabled & active" "Dịch vụ Docker đã được kích hoạt")"
}

check_port() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN -Pn &>/dev/null
    elif command -v ss &>/dev/null; then
        ss -ltn "sport = :$port" 2>/dev/null | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -ltn 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

install_portainer() {
    echo -e "\n${BOLD}${CYAN}=== $(say "Deploying Portainer CE" "Triển khai Portainer CE") ===${NC}"
    
    if check_port 9000 || check_port 9443; then
        pwn "$(say "Port 9000 or 9443 is in use. Checking existing container..." "Cổng 9000 hoặc 9443 đang bận. Kiểm tra container hiện tại...")"
    fi

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
        pok "$(say "Portainer container already exists." "Container Portainer đã tồn tại.")"
        docker start portainer 2>/dev/null || true
    else
        docker run -d -p 9000:9000 -p 9443:9443 --name portainer \
            --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            cr.portainer.io/portainer/portainer-ce:latest
        pok "$(say "Portainer deployed successfully!" "Đã triển khai Portainer thành công!")"
    fi

    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    echo ""
    echo -e "  HTTPS URL: ${GREEN}https://${IP}:9443${NC}"
    echo -e "  HTTP  URL: ${CYAN}http://${IP}:9000${NC}"
}

configure_swap() {
    echo -e "\n${BOLD}${CYAN}=== $(say "Configuring System Swap" "Cấu hình Swap hệ thống") ===${NC}"
    echo "$(say "Select Swapfile size:" "Chọn dung lượng Swapfile:")"
    echo "  1) 2 GB"
    echo "  2) 4 GB ($(say "Recommended for building from source" "Khuyến nghị khi cần build mã nguồn"))"
    echo "  3) 8 GB ($(say "For heavy compilation & AI workloads" "Cho tác vụ build nặng & AI"))"
    read -rp "$(say "Choice [1-3] (default: 2): " "Lựa chọn [1-3] (mặc định: 2): ")" SWAP_CHOICE || true

    local swap_size="4G"
    local count_mb=4096
    case "${SWAP_CHOICE:-2}" in
        1) swap_size="2G"; count_mb=2048 ;;
        3) swap_size="8G"; count_mb=8192 ;;
        *) swap_size="4G"; count_mb=4096 ;;
    esac

    local free_disk_mb
    free_disk_mb=$(df -Pm / | awk 'NR==2 {print $4}')
    if [[ "$free_disk_mb" -lt $((count_mb + 2048)) ]]; then
        pwn "$(say "Insufficient free disk space on root partition (<$((count_mb + 2048))MB free). Skipping swap creation." "Dung lượng trống không đủ trên phân vùng root. Bỏ qua tạo swap.")"
        return 0
    fi

    if [[ -f /swapfile ]] || swapon --show | grep -q '/swapfile'; then
        pwn "$(say "Existing /swapfile detected. Turning off before resizing..." "Phát hiện /swapfile cũ. Tắt swap cũ để cấu hình lại...")"
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile 2>/dev/null || true
    fi

    echo "Allocating $swap_size /swapfile..."
    fallocate -l "$swap_size" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="$count_mb" status=progress
    chmod 600 /swapfile
    mkswap /swapfile

    if ! swapon /swapfile 2>/dev/null; then
        pwn "$(say "swapon restricted on this virtual environment (LXC/OpenVZ). Skipping swap." "swapon bị giới hạn trên môi trường ảo hóa này (LXC/OpenVZ). Bỏ qua tạo swap.")"
        rm -f /swapfile
    else
        grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
        pok "$(say "Swap: $swap_size configured and active." "Swap: Đã cấu hình và kích hoạt $swap_size thành công.")"
    fi
}

optimize_system() {
    echo -e "\n${BOLD}${CYAN}=== $(say "System Optimization & Package Updates" "Tối ưu hóa Hệ thống & Cập nhật Gói") ===${NC}"
    apt-get update -qq && apt-get upgrade -y -qq
    pok "$(say "System packages updated" "Đã cập nhật toàn bộ gói hệ thống")"

    apt-get install -y -qq htop btop neofetch git curl lm-sensors 2>/dev/null || true
    pok "$(say "Diagnostic tools installed (htop, btop, neofetch, lm-sensors)" "Đã cài đặt công cụ chẩn đoán")"

    configure_swap
}

generate_helper_cli() {
    local helper_path="$INSTALL_DIR/pi-toolbox.sh"
    cat << 'HELPER_EOF' > "$helper_path"
#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-help}"

case "$CMD" in
  status)
    echo "=== Raspberry Pi & Portainer Status ==="
    if command -v docker &>/dev/null; then
      docker ps --filter "name=portainer"
    fi
    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
    echo "Portainer UI: https://${IP}:9443"
    ;;
  start)
    echo "Starting Portainer..."
    docker start portainer 2>/dev/null || docker restart portainer
    ;;
  stop)
    echo "Stopping Portainer..."
    docker stop portainer
    ;;
  restart)
    echo "Restarting Portainer..."
    docker restart portainer
    ;;
  logs)
    docker logs -f portainer
    ;;
  update)
    echo "Updating Portainer CE to latest version..."
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    docker pull cr.portainer.io/portainer/portainer-ce:latest
    docker run -d -p 9000:9000 -p 9443:9443 --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      cr.portainer.io/portainer/portainer-ce:latest
    echo "Portainer updated successfully."
    ;;
  doctor)
    echo "=== Hardware & System Health Doctor ==="
    # Temperature
    if command -v vcgencmd &>/dev/null; then
      echo "  CPU Temp:       $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
      echo "  Throttling:     $(vcgencmd get_throttled 2>/dev/null || echo 'N/A')"
    elif [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
      MILLI=$(cat /sys/class/thermal/thermal_zone0/temp)
      CELSIUS=$((MILLI / 1000))
      echo "  CPU Temp:       ${CELSIUS}°C"
    fi
    # Memory & Swap
    echo "  RAM & Swap:"
    free -h | awk 'NR<=3 {print "    " $0}'
    # Disk Usage
    echo "  Disk Usage (Root /):"
    df -h / | awk 'NR==2 {print "    Used: " $3 " / " $2 " (" $5 " full)"}'
    # Docker
    if command -v docker &>/dev/null; then
      echo "  Docker Engine:  Running (version $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown'))"
    else
      echo "  Docker Engine:  Not installed"
    fi
    ;;
  uninstall)
    echo "WARNING: This will remove the Portainer container."
    read -rp "Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker stop portainer 2>/dev/null || true
      docker rm portainer 2>/dev/null || true
      echo "Portainer container removed. Data volume 'portainer_data' was preserved."
    fi
    ;;
  *)
    echo "Usage: ./pi-toolbox.sh {status|start|stop|restart|logs|update|doctor|uninstall}"
    ;;
esac
HELPER_EOF

    chmod +x "$helper_path"
    chown "$TARGET_USER:$TARGET_GROUP" "$helper_path"
    ln -sf "$helper_path" /usr/local/bin/pi-toolbox 2>/dev/null || true
    pok "$(say "CLI helper generated at $helper_path (and /usr/local/bin/pi-toolbox)" "Đã tạo công cụ CLI tại $helper_path (và /usr/local/bin/pi-toolbox)")"
}

# Menu
echo -e "${BOLD}$(say "Select Action:" "Chọn thao tác:")${NC}"
echo "  1) $(say "Install Docker & Docker Compose" "Cài đặt Docker & Docker Compose")"
echo "  2) $(say "Install Portainer CE" "Cài đặt Portainer CE")"
echo "  3) $(say "Install Full Stack (Docker + Portainer CE)" "Cài đặt toàn bộ (Docker + Portainer CE)")"
echo "  4) $(say "System Optimization (Update + Diagnostic Tools + Swap)" "Tối ưu hóa hệ thống (Update + Công cụ + Swap)")"
echo "  5) $(say "Run Hardware Health Doctor" "Chạy chẩn đoán phần cứng (Doctor)")"
echo "  6) $(say "Exit" "Thoát")"
echo ""
read -rp "$(say "Choice [1-6]: " "Lựa chọn [1-6]: ")" CHOICE || true

case "${CHOICE:-3}" in
    1)
        install_docker
        generate_helper_cli
        ;;
    2)
        install_portainer
        generate_helper_cli
        ;;
    3)
        install_docker
        install_portainer
        generate_helper_cli
        ;;
    4)
        optimize_system
        generate_helper_cli
        ;;
    5)
        generate_helper_cli
        "$INSTALL_DIR/pi-toolbox.sh" doctor
        ;;
    *)
        exit 0
        ;;
esac

echo ""
echo "================================================================"
echo -e "${GREEN}  🎉 $(say "SETUP TASK COMPLETED!" "HOÀN TẤT THAO TÁC!")${NC}"
echo ""
echo -e "${CYAN}$(say "Quick Management:" "Quản Lý Nhanh:"):${NC}"
echo "  • pi-toolbox status"
echo "  • pi-toolbox doctor"
echo "  • pi-toolbox restart"
echo ""
echo "Support: https://ai.vnrom.net"
