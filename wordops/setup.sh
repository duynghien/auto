#!/usr/bin/env bash
# ============================================================
# SETUP TƯƠNG TÁC CHO WORDOPS BACKUP
# - Cài backup.sh / restore.sh
# - Sinh file backup.env từ dữ liệu nhập
# - Tạo cron tự động (tuỳ chọn)
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_BACKUP="$ROOT_DIR/scripts/backup.sh"
SRC_RESTORE="$ROOT_DIR/scripts/restore.sh"

if [ "$EUID" -ne 0 ]; then
  echo "[LỖI] Vui lòng chạy setup bằng quyền root (sudo)."
  exit 1
fi

if [ ! -f "$SRC_BACKUP" ] || [ ! -f "$SRC_RESTORE" ]; then
  echo "[LỖI] Không tìm thấy scripts/backup.sh hoặc scripts/restore.sh trong repo."
  exit 1
fi

check_dependencies() {
  local missing=()
  local cmd

  for cmd in bash flock tar gzip timeout awk sed grep find du df date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if ! command -v mariadb-dump >/dev/null 2>&1 && ! command -v mysqldump >/dev/null 2>&1; then
    missing+=("mariadb-dump|mysqldump")
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "[CẢNH BÁO] Thiếu command trên máy hiện tại: ${missing[*]}"
    echo "[CẢNH BÁO] Bạn vẫn có thể setup, nhưng backup có thể lỗi nếu không cài đủ."
    echo ""
  fi
}

ask_value() {
  local prompt="$1"
  local default_value="$2"
  local input=""

  read -r -p "$prompt [$default_value]: " input
  if [ -z "$input" ]; then
    echo "$default_value"
  else
    echo "$input"
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default_value="$2"
  local input=""

  read -r -p "$prompt [$default_value]: " input
  input="${input:-$default_value}"

  case "$input" in
    y|Y|yes|YES|true|TRUE|1)
      echo "true"
      ;;
    n|N|no|NO|false|FALSE|0)
      echo "false"
      ;;
    *)
      echo "$default_value" | sed 's/y/true/; s/n/false/'
      ;;
  esac
}

get_mysql_client_password() {
  local conf_file="/etc/mysql/conf.d/my.cnf"
  local password=""

  if [ ! -f "$conf_file" ]; then
    echo ""
    return 0
  fi

  password="$(awk '
    BEGIN { in_client=0 }
    /^[[:space:]]*\[client\][[:space:]]*$/ { in_client=1; next }
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_client=0 }
    in_client && /^[[:space:]]*password[[:space:]]*=/ {
      sub(/^[[:space:]]*password[[:space:]]*=[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$conf_file")"

  echo "$password"
}

echo "============================================================"
echo "      CÀI ĐẶT WORDOPS BACKUP (LẦN ĐẦU)"
echo "============================================================"

check_dependencies

echo "[Bước 1/5] Chọn đường dẫn cài đặt"
INSTALL_DIR="$(ask_value "- Thư mục cài script" "/opt/scripts")"
ENV_FILE="$INSTALL_DIR/backup.env"

echo ""
echo "[Bước 2/5] Cấu hình backup local"
WEB_ROOT="$(ask_value "- Web root WordOps" "/var/www")"
BACKUP_DIR="$(ask_value "- Thư mục lưu backup local" "/backup")"
RETENTION_DAYS="$(ask_value "- Số ngày giữ backup local" "3")"
MIN_FREE_GB="$(ask_value "- Dung lượng trống tối thiểu trước backup (GB)" "5")"
LOCK_FILE="$(ask_value "- Đường dẫn lock file" "/var/lock/wordpress-backup.lock")"

echo ""
echo "[Bước 3/5] Cấu hình Google Drive (rclone)"
GDRIVE_ENABLED="$(ask_yes_no "- Bật upload Google Drive? (y/n)" "y")"
if [ "$GDRIVE_ENABLED" = "true" ]; then
  GDRIVE_REMOTE="$(ask_value "- Remote đích" "gdrive:backups/WORDOPS")"
  GDRIVE_RETENTION_DAYS="$(ask_value "- Số ngày giữ bản backup trên Google Drive" "7")"
  RCLONE_CONFIG="$(ask_value "- Đường dẫn rclone.conf" "/root/.config/rclone/rclone.conf")"
else
  GDRIVE_REMOTE="gdrive:backups/WORDOPS"
  GDRIVE_RETENTION_DAYS="7"
  RCLONE_CONFIG="/root/.config/rclone/rclone.conf"
fi

echo ""
echo "[Bước 4/5] Cấu hình DB dump"
DB_DUMP_TIMEOUT_SECONDS="$(ask_value "- Timeout cho mỗi lần dump DB (giây)" "300")"
DB_DUMP_RETRIES="$(ask_value "- Số lần retry dump DB" "3")"
DB_DUMP_BACKOFF_SECONDS="$(ask_value "- Backoff base giữa các lần retry (giây)" "10")"
MYSQL_USER="$(ask_value "- User DB fallback (khi wp-config thiếu DB_USER)" "root")"
MYSQL_PASSWORD="$(get_mysql_client_password)"
if [ -n "$MYSQL_PASSWORD" ]; then
  echo "- Đã tự động lấy MYSQL_PASSWORD từ /etc/mysql/conf.d/my.cnf"
else
  echo "[CẢNH BÁO] Không tìm thấy password trong /etc/mysql/conf.d/my.cnf, MYSQL_PASSWORD sẽ để trống."
fi

echo ""
echo "[Bước 5/5] Cấu hình Telegram"
TG_ENABLED="$(ask_yes_no "- Bật thông báo Telegram? (y/n)" "y")"
if [ "$TG_ENABLED" = "true" ]; then
  TG_BOT_TOKEN="$(ask_value "- TG_BOT_TOKEN" "")"
  TG_CHAT_ID="$(ask_value "- TG_CHAT_ID" "")"
else
  TG_BOT_TOKEN=""
  TG_CHAT_ID=""
fi

echo ""
CRON_ENABLED="$(ask_yes_no "- Tạo cron chạy tự động mỗi ngày? (y/n)" "y")"
CRON_SCHEDULE="0 2 * * *"
if [ "$CRON_ENABLED" = "true" ]; then
  CRON_SCHEDULE="$(ask_value "- Lịch cron" "0 2 * * *")"
fi

mkdir -p "$INSTALL_DIR" "$BACKUP_DIR"

cp -f "$SRC_BACKUP" "$INSTALL_DIR/backup.sh"
cp -f "$SRC_RESTORE" "$INSTALL_DIR/restore.sh"
chmod +x "$INSTALL_DIR/backup.sh" "$INSTALL_DIR/restore.sh"

cat > "$ENV_FILE" <<ENVEOF
# Sinh tự động bởi setup.sh lúc: $(date +"%Y-%m-%d %H:%M:%S")
WEB_ROOT=$WEB_ROOT
BACKUP_DIR=$BACKUP_DIR
RETENTION_DAYS=$RETENTION_DAYS
MIN_FREE_GB=$MIN_FREE_GB
LOCK_FILE=$LOCK_FILE

GDRIVE_ENABLED=$GDRIVE_ENABLED
GDRIVE_REMOTE=$GDRIVE_REMOTE
GDRIVE_RETENTION_DAYS=$GDRIVE_RETENTION_DAYS
RCLONE_CONFIG=$RCLONE_CONFIG

DB_DUMP_TIMEOUT_SECONDS=$DB_DUMP_TIMEOUT_SECONDS
DB_DUMP_RETRIES=$DB_DUMP_RETRIES
DB_DUMP_BACKOFF_SECONDS=$DB_DUMP_BACKOFF_SECONDS
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

TG_ENABLED=$TG_ENABLED
TG_BOT_TOKEN=$TG_BOT_TOKEN
TG_CHAT_ID=$TG_CHAT_ID
ENVEOF

chmod 600 "$ENV_FILE"

if [ "$CRON_ENABLED" = "true" ]; then
  CRON_FILE="/etc/cron.d/wordops-backup"
  cat > "$CRON_FILE" <<CRONEOF
$CRON_SCHEDULE root bash $INSTALL_DIR/backup.sh >> /var/log/backup-cron.log 2>&1
CRONEOF
  chmod 644 "$CRON_FILE"
fi

echo ""
echo "============================================================"
echo "Hoàn tất cài đặt"
echo "- Script backup:  $INSTALL_DIR/backup.sh"
echo "- Script restore: $INSTALL_DIR/restore.sh"
echo "- File cấu hình:  $ENV_FILE"
if [ "$CRON_ENABLED" = "true" ]; then
  echo "- Cron:           /etc/cron.d/wordops-backup ($CRON_SCHEDULE)"
else
  echo "- Cron:           chưa tạo"
fi
echo "============================================================"

echo "Kiểm tra đề xuất sau setup:"
echo "1) rclone listremotes"
echo "2) sudo bash $INSTALL_DIR/backup.sh"
echo "3) tail -f /var/log/backup-*.log"
