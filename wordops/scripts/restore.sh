#!/usr/bin/env bash
# ============================================================
# RESTORE SCRIPT - WordOps / WordPress
# Khôi phục files (htdocs) và/hoặc database từ /backup/YYYY-MM-DD/<site>
# ============================================================

set -u
set -o pipefail

BACKUP_DIR="${BACKUP_DIR:-/backup}"
WEB_ROOT="${WEB_ROOT:-/var/www}"
RESTORE_TIMEOUT_SECONDS="${RESTORE_TIMEOUT_SECONDS:-600}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILES=(
  "${SCRIPT_DIR}/backup.env"
  "/etc/backup/backup.env"
  "/opt/scripts/backup.env"
)
for env_file in "${ENV_FILES[@]}"; do
  if [ -f "$env_file" ]; then
    # shellcheck disable=SC1090
    . "$env_file"
  fi
done

usage() {
  cat <<USAGE
Cách dùng:
  sudo bash restore.sh <backup-date:YYYY-MM-DD> <site-name> [--files-only|--db-only] [--yes]

Ví dụ:
  sudo bash restore.sh 2026-02-28 addrom.com --yes
  sudo bash restore.sh 2026-02-28 addrom.com --files-only --yes
  sudo bash restore.sh 2026-02-28 addrom.com --db-only --yes
USAGE
}

log() {
  echo "[$(date +"%H:%M:%S")] $1"
}

find_wp_config() {
  local site_root="$1"
  if [ -f "$site_root/htdocs/wp-config.php" ]; then
    echo "$site_root/htdocs/wp-config.php"
    return
  fi
  if [ -f "$site_root/wp-config.php" ]; then
    echo "$site_root/wp-config.php"
    return
  fi
  echo ""
}

extract_wp_define() {
  local wp_config="$1"
  local key="$2"
  local line

  line=$(grep -E "^[[:space:]]*define[[:space:]]*\\([[:space:]]*['\"]${key}['\"][[:space:]]*," "$wp_config" | head -1)
  if [ -z "$line" ]; then
    echo ""
    return
  fi

  echo "$line" | sed -E "s/^[[:space:]]*define[[:space:]]*\\([[:space:]]*['\"]${key}['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]*)['\"].*/\\1/"
}

build_mysql_args() {
  local db_user="$1"
  local db_password="$2"
  local db_host="$3"
  MYSQL_ARGS=(-u "$db_user")

  if [ -n "$db_password" ]; then
    MYSQL_ARGS+=(-p"$db_password")
  fi

  if [[ "$db_host" == *:* ]]; then
    local host_part="${db_host%%:*}"
    local port_or_socket="${db_host#*:}"
    if [[ "$port_or_socket" == /* ]]; then
      [ -z "$host_part" ] && host_part="localhost"
      MYSQL_ARGS+=(-h "$host_part" --socket="$port_or_socket")
    elif [[ "$port_or_socket" =~ ^[0-9]+$ ]]; then
      [ -z "$host_part" ] && host_part="localhost"
      MYSQL_ARGS+=(-h "$host_part" -P "$port_or_socket")
    else
      MYSQL_ARGS+=(-h "$db_host")
    fi
  elif [[ "$db_host" == /* ]]; then
    MYSQL_ARGS+=(--socket="$db_host")
  else
    MYSQL_ARGS+=(-h "$db_host")
  fi
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

BACKUP_DATE="$1"
SITE_NAME="$2"
shift 2

DO_FILES=true
DO_DB=true
ASSUME_YES=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --files-only)
      DO_DB=false
      ;;
    --db-only)
      DO_FILES=false
      ;;
    --yes)
      ASSUME_YES=true
      ;;
    *)
      echo "Tham số không hợp lệ: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [ "$DO_FILES" = false ] && [ "$DO_DB" = false ]; then
  echo "Không có gì để khôi phục (đã tắt cả files và DB)."
  exit 1
fi

if ! [[ "$BACKUP_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Định dạng ngày backup không hợp lệ: $BACKUP_DATE"
  exit 1
fi

if ! command -v tar >/dev/null 2>&1 || ! command -v gzip >/dev/null 2>&1 || ! command -v timeout >/dev/null 2>&1; then
  echo "Thiếu command bắt buộc (tar/gzip/timeout)."
  exit 1
fi

MYSQL_IMPORT_CMD=""
if command -v mariadb >/dev/null 2>&1; then
  MYSQL_IMPORT_CMD="mariadb"
elif command -v mysql >/dev/null 2>&1; then
  MYSQL_IMPORT_CMD="mysql"
fi

if [ "$DO_DB" = true ] && [ -z "$MYSQL_IMPORT_CMD" ]; then
  echo "Thiếu mariadb/mysql client để restore DB."
  exit 1
fi

SITE_BACKUP_DIR="$BACKUP_DIR/$BACKUP_DATE/$SITE_NAME"
SITE_ROOT="$WEB_ROOT/$SITE_NAME"
HTDOCS_DIR="$SITE_ROOT/htdocs"

if [ ! -d "$SITE_BACKUP_DIR" ]; then
  echo "Không tìm thấy thư mục backup site: $SITE_BACKUP_DIR"
  exit 1
fi

if [ ! -d "$SITE_ROOT" ]; then
  echo "Không tìm thấy thư mục site: $SITE_ROOT"
  exit 1
fi

SOURCE_ARCHIVE="$(ls -1t "$SITE_BACKUP_DIR"/source_*.tar.gz 2>/dev/null | head -1)"
DB_ARCHIVE="$(ls -1t "$SITE_BACKUP_DIR"/database_*.sql.gz 2>/dev/null | head -1)"

if [ "$DO_FILES" = true ] && [ -z "$SOURCE_ARCHIVE" ]; then
  echo "Không tìm thấy source archive trong: $SITE_BACKUP_DIR"
  exit 1
fi

if [ "$DO_DB" = true ] && [ -z "$DB_ARCHIVE" ]; then
  echo "Không tìm thấy database archive trong: $SITE_BACKUP_DIR"
  exit 1
fi

if [ "$ASSUME_YES" != true ]; then
  echo "Site cần khôi phục: $SITE_NAME"
  echo "Ngày backup: $BACKUP_DATE"
  echo "Khôi phục files: $DO_FILES"
  echo "Khôi phục DB: $DO_DB"
  echo "Lưu ý: thao tác này có thể ghi đè dữ liệu hiện tại."
  read -r -p "Tiếp tục? [y/N]: " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Đã huỷ"
    exit 1
  fi
fi

RESTORE_TS="$(date +"%Y-%m-%d_%H-%M-%S")"

if [ "$DO_FILES" = true ]; then
  log "Khôi phục files từ: $SOURCE_ARCHIVE"

  if [ -d "$HTDOCS_DIR" ]; then
    PREV_HTDOCS="${HTDOCS_DIR}.pre-restore-${RESTORE_TS}"
    mv "$HTDOCS_DIR" "$PREV_HTDOCS"
    log "Đã đổi tên htdocs hiện tại -> $PREV_HTDOCS"
  fi

  mkdir -p "$HTDOCS_DIR"
  if timeout "$RESTORE_TIMEOUT_SECONDS" tar -xzf "$SOURCE_ARCHIVE" -C "$HTDOCS_DIR"; then
    log "Khôi phục files thành công vào: $HTDOCS_DIR"
  else
    log "Khôi phục files thất bại"
    exit 1
  fi
fi

if [ "$DO_DB" = true ]; then
  log "Khôi phục database từ: $DB_ARCHIVE"

  WP_CONFIG="$(find_wp_config "$SITE_ROOT")"
  if [ -z "$WP_CONFIG" ]; then
    log "Không tìm thấy wp-config.php của site: $SITE_NAME"
    exit 1
  fi

  DB_NAME="$(extract_wp_define "$WP_CONFIG" "DB_NAME")"
  DB_USER="$(extract_wp_define "$WP_CONFIG" "DB_USER")"
  DB_PASSWORD="$(extract_wp_define "$WP_CONFIG" "DB_PASSWORD")"
  DB_HOST="$(extract_wp_define "$WP_CONFIG" "DB_HOST")"

  if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    log "Không đọc được DB credentials từ wp-config.php"
    exit 1
  fi

  [ -z "$DB_HOST" ] && DB_HOST="localhost"
  build_mysql_args "$DB_USER" "$DB_PASSWORD" "$DB_HOST"

  if timeout "$RESTORE_TIMEOUT_SECONDS" bash -c "gzip -dc '$DB_ARCHIVE' | '$MYSQL_IMPORT_CMD' \"\${@}\" '$DB_NAME'" _ "${MYSQL_ARGS[@]}"; then
    log "Khôi phục DB thành công: $DB_NAME"
  else
    log "Khôi phục DB thất bại"
    exit 1
  fi
fi

log "Khôi phục hoàn tất thành công"
exit 0
