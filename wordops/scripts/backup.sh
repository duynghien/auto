#!/usr/bin/env bash
# ============================================================
# BACKUP SCRIPT - WordOps / WordPress
# - Sao lưu source (htdocs + conf + wp-config.php nếu có) + database theo từng site
# - Ghi dữ liệu local theo kiểu atomic (staging -> swap)
# - Upload Google Drive + dọn bản cũ theo retention
# - Thông báo Telegram đầu/cuối + chi tiết
# ============================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==== FILE CẤU HÌNH (cùng thư mục script) ====
ENV_FILE="${SCRIPT_DIR}/backup.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

# ==== CONFIG (WordOps defaults) ====
WEB_ROOT="${WEB_ROOT:-/var/www}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-3}"
MIN_FREE_GB="${MIN_FREE_GB:-5}"
LOCK_FILE="${LOCK_FILE:-/var/lock/wordpress-backup.lock}"

# Google Drive
GDRIVE_ENABLED="${GDRIVE_ENABLED:-true}"
GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive:backups/WORDOPS}"
GDRIVE_RETENTION_DAYS="${GDRIVE_RETENTION_DAYS:-7}"
RCLONE_CONFIG="${RCLONE_CONFIG:-/root/.config/rclone/rclone.conf}"

# DB dump behavior
DB_DUMP_TIMEOUT_SECONDS="${DB_DUMP_TIMEOUT_SECONDS:-300}"
DB_DUMP_RETRIES="${DB_DUMP_RETRIES:-3}"
DB_DUMP_BACKOFF_SECONDS="${DB_DUMP_BACKOFF_SECONDS:-10}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(awk -F'=' '/^[[:space:]]*password[[:space:]]*=/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' /etc/mysql/conf.d/my.cnf 2>/dev/null | head -1)}"

# Telegram (set via env file to avoid secret leak in script)
TG_ENABLED="${TG_ENABLED:-true}"
TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# Ignore directories in WEB_ROOT
SKIP_DIRS=("22222" "html" "cache" "tmp" "lost+found")

# ==== INIT ====
DATE="$(date +"%Y-%m-%d")"
DATETIME="$(date +"%Y-%m-%d_%H-%M-%S")"
DATE_HUMAN="$(date +"%d/%m/%Y %H:%M:%S")"
START_TS="$(date +%s)"
HOSTNAME_SHORT="$(hostname)"
LOG_FILE="/var/log/backup-${DATETIME}.log"

STAGING_DIR="${BACKUP_DIR}/.staging-${DATE}-${DATETIME}-$$"
NEW_FINAL_DIR=""
FINAL_DIR="${BACKUP_DIR}/${DATE}"
PREV_FINAL_DIR=""

TOTAL_ERRORS=0
SITE_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0
FOUND_SITES=()
SITE_REPORTS_HTML=""
GDRIVE_STATUS="⏭ Bỏ qua"
FINAL_ICON="✅"
DB_DUMP_CMD=""

# ==== FUNCTIONS ====
log() {
  echo "[$(date +"%H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

human_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

elapsed_since() {
  local started="$1"
  local elapsed=$(( $(date +%s) - started ))
  printf "%02dm%02ds" $((elapsed/60)) $((elapsed%60))
}

is_true() {
  case "$1" in
    true|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

escape_html() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

strip_html() {
  printf '%s' "$1" | sed -E 's/<[^>]+>//g'
}

send_telegram_message() {
  local message_html="$1"
  local max_len=3800
  local response=""

  if ! is_true "$TG_ENABLED"; then
    return 0
  fi

  if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    log "⚠️ Telegram bật nhưng thiếu TG_BOT_TOKEN/TG_CHAT_ID"
    return 1
  fi

  if [ ${#message_html} -gt $max_len ]; then
    message_html="${message_html:0:$max_len}
... (rút gọn do quá dài)"
  fi

  response=$(curl -sS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${message_html}" \
    --data-urlencode "parse_mode=HTML" \
    --max-time 30 2>>"$LOG_FILE")

  if echo "$response" | grep -q '"ok":true'; then
    log "📨 Telegram: gửi HTML thành công"
    return 0
  fi

  log "⚠️ Telegram HTML lỗi, fallback plain-text: $response"

  local message_plain
  message_plain="$(strip_html "$message_html")"
  if [ ${#message_plain} -gt $max_len ]; then
    message_plain="${message_plain:0:$max_len}
... (truncated)"
  fi

  response=$(curl -sS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=${message_plain}" \
    --max-time 30 2>>"$LOG_FILE")

  if echo "$response" | grep -q '"ok":true'; then
    log "📨 Telegram: gửi plain-text fallback thành công"
    return 0
  fi

  log "❌ Telegram fallback cũng lỗi: $response"
  return 1
}

is_skipped_dir() {
  local name="$1"
  local skip
  for skip in "${SKIP_DIRS[@]}"; do
    if [ "$name" = "$skip" ]; then
      return 0
    fi
  done
  return 1
}

find_wp_config() {
  local site_path="$1"
  if [ -f "$site_path/htdocs/wp-config.php" ]; then
    echo "$site_path/htdocs/wp-config.php"
    return
  fi
  if [ -f "$site_path/wp-config.php" ]; then
    echo "$site_path/wp-config.php"
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

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "❌ Thiếu command bắt buộc: $cmd"
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    return 1
  fi
  return 0
}

detect_dump_command() {
  if command -v mariadb-dump >/dev/null 2>&1; then
    DB_DUMP_CMD="mariadb-dump"
    return 0
  fi

  if command -v mysqldump >/dev/null 2>&1; then
    DB_DUMP_CMD="mysqldump"
    log "⚠️ Không có mariadb-dump, fallback sang mysqldump"
    return 0
  fi

  log "❌ Không tìm thấy mariadb-dump hoặc mysqldump"
  TOTAL_ERRORS=$((TOTAL_ERRORS+1))
  return 1
}

check_free_disk() {
  local target_path="$1"
  local min_kb=$((MIN_FREE_GB * 1024 * 1024))
  local available_kb

  available_kb=$(df -Pk "$target_path" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ -z "$available_kb" ]; then
    log "❌ Không đọc được dung lượng trống tại $target_path"
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    return 1
  fi

  if [ "$available_kb" -lt "$min_kb" ]; then
    log "❌ Dung lượng trống không đủ (cần >= ${MIN_FREE_GB}GB)"
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    return 1
  fi

  log "✅ Dung lượng trống đủ: $(awk "BEGIN {printf \"%.2f\", ${available_kb}/1024/1024}")GB"
  return 0
}

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    log "⚠️ Backup đang chạy ở phiên khác, thoát để tránh chồng job"
    send_telegram_message "⚠️ <b>Backup bị bỏ qua</b>
Server: $(escape_html "$HOSTNAME_SHORT")
Lý do: job trước chưa kết thúc (lock file)."
    exit 1
  fi
}

preflight_check() {
  local ok=0

  log "🧪 Preflight check..."
  require_command flock || ok=1
  require_command tar || ok=1
  require_command gzip || ok=1
  require_command rclone || ok=1
  require_command timeout || ok=1
  require_command awk || ok=1
  require_command sed || ok=1
  require_command grep || ok=1
  require_command find || ok=1
  require_command du || ok=1
  require_command df || ok=1
  require_command date || ok=1
  detect_dump_command || ok=1

  mkdir -p "$BACKUP_DIR"
  check_free_disk "$BACKUP_DIR" || ok=1

  if [ $ok -ne 0 ]; then
    log "❌ Preflight thất bại"
    return 1
  fi

  log "✅ Preflight pass | DB dump tool: $DB_DUMP_CMD"
  return 0
}

discover_sites() {
  local site_path=""
  local site_name=""
  local wp_config=""

  log "📂 Scanning sites trong $WEB_ROOT..."
  FOUND_SITES=()

  for site_path in "$WEB_ROOT"/*; do
    [ -d "$site_path" ] || continue
    site_name="$(basename "$site_path")"

    if is_skipped_dir "$site_name"; then
      log "  ⏭ Bỏ qua: $site_name (system dir)"
      continue
    fi

    if [ ! -d "$site_path/htdocs" ]; then
      log "  ⏭ Bỏ qua: $site_name (không có htdocs)"
      continue
    fi

    wp_config="$(find_wp_config "$site_path")"
    if [ -z "$wp_config" ]; then
      log "  ⏭ Bỏ qua: $site_name (không có wp-config.php)"
      continue
    fi

    FOUND_SITES+=("$site_name")
    log "  ✔ WordPress site: $site_name"
  done

  log "📊 Tổng số site WordPress hợp lệ: ${#FOUND_SITES[@]}"
}

build_dump_args() {
  local db_user="$1"
  local db_password="$2"
  local db_host="$3"
  DUMP_ARGS=(--single-transaction --quick --lock-tables=false -u "$db_user")

  if [ -n "$db_password" ]; then
    DUMP_ARGS+=(-p"$db_password")
  fi

  if [[ "$db_host" == *:* ]]; then
    local host_part="${db_host%%:*}"
    local port_or_socket="${db_host#*:}"

    if [[ "$port_or_socket" == /* ]]; then
      [ -z "$host_part" ] && host_part="localhost"
      DUMP_ARGS+=(-h "$host_part" --socket="$port_or_socket")
    elif [[ "$port_or_socket" =~ ^[0-9]+$ ]]; then
      [ -z "$host_part" ] && host_part="localhost"
      DUMP_ARGS+=(-h "$host_part" -P "$port_or_socket")
    else
      DUMP_ARGS+=(-h "$db_host")
    fi
  elif [[ "$db_host" == /* ]]; then
    DUMP_ARGS+=(--socket="$db_host")
  else
    DUMP_ARGS+=(-h "$db_host")
  fi
}

backup_site() {
  local site_name="$1"
  local site_path="$WEB_ROOT/$site_name"
  local site_stage_dir="$STAGING_DIR/$site_name"
  local site_start_ts
  local site_errors=0
  local site_status=""
  local site_total_size=""

  local wp_config=""
  local db_name=""
  local db_user=""
  local db_password=""
  local db_host=""
  local auth_user=""
  local auth_password=""
  local db_tmp_file=""
  local db_file=""
  local db_err_file=""
  local db_ok="❌"
  local src_ok="❌"

  site_start_ts=$(date +%s)
  mkdir -p "$site_stage_dir"

  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "🌐 Bắt đầu backup site: $site_name"

  wp_config="$(find_wp_config "$site_path")"
  if [ -z "$wp_config" ]; then
    log "  ❌ Không tìm thấy wp-config.php"
    site_errors=$((site_errors+1))
  else
    log "  📄 wp-config.php: $wp_config"

    db_name="$(extract_wp_define "$wp_config" "DB_NAME")"
    db_user="$(extract_wp_define "$wp_config" "DB_USER")"
    db_password="$(extract_wp_define "$wp_config" "DB_PASSWORD")"
    db_host="$(extract_wp_define "$wp_config" "DB_HOST")"

    if [ -z "$db_name" ]; then
      log "  ❌ Không đọc được DB_NAME"
      site_errors=$((site_errors+1))
    else
      auth_user="$db_user"
      auth_password="$db_password"

      if [ -z "$auth_user" ]; then
        auth_user="$MYSQL_USER"
        auth_password="$MYSQL_PASSWORD"
        log "  ⚠️ Thiếu DB_USER trong wp-config, fallback user mặc định: $auth_user"
      fi
      [ -z "$db_host" ] && db_host="localhost"

      build_dump_args "$auth_user" "$auth_password" "$db_host"

      db_tmp_file="$site_stage_dir/database_${db_name}_${DATETIME}.sql"
      db_file="${db_tmp_file}.gz"
      db_err_file="$site_stage_dir/database_${db_name}_${DATETIME}.err.log"

      rm -f "$db_tmp_file" "$db_file" "$db_err_file"

      local attempt=1
      local dump_success=0

      while [ "$attempt" -le "$DB_DUMP_RETRIES" ]; do
        log "  🗄 DB: $db_name | User: $auth_user | Host: $db_host | Attempt $attempt/$DB_DUMP_RETRIES"

        if timeout "$DB_DUMP_TIMEOUT_SECONDS" "$DB_DUMP_CMD" "${DUMP_ARGS[@]}" "$db_name" > "$db_tmp_file" 2> "$db_err_file"; then
          if [ -s "$db_tmp_file" ] && gzip -f "$db_tmp_file" 2>>"$LOG_FILE" && [ -s "$db_file" ]; then
            db_ok="✅"
            dump_success=1
            log "  ✅ DB backup: $db_file ($(human_size "$db_file"))"
            break
          else
            echo "DB dump file rỗng hoặc gzip lỗi" > "$db_err_file"
            rm -f "$db_tmp_file" "$db_file"
          fi
        else
          local rc=$?
          if [ "$rc" -eq 124 ]; then
            echo "Dump timeout sau ${DB_DUMP_TIMEOUT_SECONDS}s" >> "$db_err_file"
          fi
        fi

        if [ -s "$db_err_file" ]; then
          sed 's/^/    /' "$db_err_file" >> "$LOG_FILE"
        fi

        if [ "$attempt" -lt "$DB_DUMP_RETRIES" ]; then
          local sleep_seconds=$((DB_DUMP_BACKOFF_SECONDS * attempt))
          if grep -qiE "1040|Too many connections" "$db_err_file"; then
            log "  ⚠️ DB 1040 Too many connections, retry sau ${sleep_seconds}s"
          else
            log "  ⚠️ DB dump lỗi, retry sau ${sleep_seconds}s"
          fi
          sleep "$sleep_seconds"
        fi

        attempt=$((attempt+1))
      done

      if [ "$dump_success" -ne 1 ]; then
        log "  ❌ Lỗi backup DB: $db_name (chi tiết: $db_err_file, log: $LOG_FILE)"
        site_errors=$((site_errors+1))
      fi
    fi
  fi

  # Source backup (WordOps: htdocs + conf + wp-config.php nếu có, bỏ logs)
  local src_root="$site_path"
  local src_file="$site_stage_dir/source_${site_name}_${DATETIME}.tar.gz"
  local source_items=()
  local has_htdocs=0

  if [ -d "$src_root/htdocs" ]; then
    source_items+=("htdocs")
    has_htdocs=1
  fi

  if [ -d "$src_root/conf" ]; then
    source_items+=("conf")
  else
    log "  ⚠️ Không có thư mục conf, vẫn tiếp tục backup source"
  fi

  if [ -f "$src_root/wp-config.php" ]; then
    source_items+=("wp-config.php")
  fi

  if [ "$has_htdocs" -eq 1 ]; then
    log "  📁 Source root: $src_root"
    log "  📦 Thành phần source: ${source_items[*]}"
    if tar -czf "$src_file" \
      --exclude='htdocs/wp-content/cache' \
      --exclude='htdocs/wp-content/wflogs' \
      --exclude='htdocs/wp-content/updraft' \
      --exclude='htdocs/wp-content/ai1wm-backups' \
      --exclude='htdocs/wp-content/backups' \
      --exclude='htdocs/wp-content/uploads/backup*' \
      --exclude='htdocs/wp-content/uploads/wp-clone*' \
      --exclude='htdocs/cache' \
      --exclude='htdocs/logs' \
      -C "$src_root" "${source_items[@]}" 2>>"$LOG_FILE"; then
      if [ -s "$src_file" ]; then
        src_ok="✅"
        log "  ✅ Source backup: $src_file ($(human_size "$src_file"))"
      else
        log "  ❌ Source backup lỗi: file rỗng"
        site_errors=$((site_errors+1))
      fi
    else
      log "  ❌ Lỗi backup source"
      site_errors=$((site_errors+1))
    fi
  else
    log "  ❌ Thiếu thư mục htdocs"
    site_errors=$((site_errors+1))
  fi

  site_total_size="$(human_size "$site_stage_dir")"
  if [ "$site_errors" -eq 0 ]; then
    site_status="✅ OK"
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  else
    site_status="❌ Lỗi"
    FAIL_COUNT=$((FAIL_COUNT+1))
    TOTAL_ERRORS=$((TOTAL_ERRORS+site_errors))
  fi

  SITE_REPORTS_HTML+="
<b>$(escape_html "$site_name")</b> | ${site_status} | ${site_total_size} | ⏱$(elapsed_since "$site_start_ts")
DB: ${db_ok}
Source: ${src_ok}
"

  SITE_COUNT=$((SITE_COUNT+1))
  log "  📊 Site $site_name: $site_status | Size: $site_total_size | Time: $(elapsed_since "$site_start_ts")"
}

commit_staging_atomic() {
  NEW_FINAL_DIR="${BACKUP_DIR}/.new-${DATE}-${DATETIME}-$$"

  if ! mv "$STAGING_DIR" "$NEW_FINAL_DIR"; then
    log "❌ Không thể chuyển staging sang new-final"
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    return 1
  fi
  STAGING_DIR=""

  if [ -d "$FINAL_DIR" ]; then
    PREV_FINAL_DIR="${BACKUP_DIR}/.prev-${DATE}-${DATETIME}-$$"
    if ! mv "$FINAL_DIR" "$PREV_FINAL_DIR"; then
      log "❌ Không thể giữ bản backup cũ để swap"
      TOTAL_ERRORS=$((TOTAL_ERRORS+1))
      return 1
    fi
  fi

  if mv "$NEW_FINAL_DIR" "$FINAL_DIR"; then
    NEW_FINAL_DIR=""
    log "✅ Atomic swap hoàn tất: $FINAL_DIR"
    return 0
  fi

  log "❌ Atomic swap thất bại"
  TOTAL_ERRORS=$((TOTAL_ERRORS+1))

  if [ -n "$PREV_FINAL_DIR" ] && [ -d "$PREV_FINAL_DIR" ]; then
    mv "$PREV_FINAL_DIR" "$FINAL_DIR" 2>/dev/null || true
    PREV_FINAL_DIR=""
    log "↩️ Đã rollback về bản cũ"
  fi

  return 1
}

upload_to_gdrive() {
  if ! is_true "$GDRIVE_ENABLED"; then
    GDRIVE_STATUS="⏭ Bỏ qua"
    return 0
  fi

  log "--- Upload Google Drive ---"
  if rclone copy "$FINAL_DIR" "$GDRIVE_REMOTE/$DATE" \
    --config "$RCLONE_CONFIG" \
    --transfers 4 \
    --checkers 8 \
    --retries 3 \
    --retries-sleep 10s \
    --contimeout 30s \
    --timeout 10m \
    --stats 15s \
    --log-file "$LOG_FILE" \
    --log-level INFO 2>>"$LOG_FILE"; then
    GDRIVE_STATUS="✅ Thành công"
    log "✅ Upload Google Drive thành công"
  else
    GDRIVE_STATUS="❌ Thất bại"
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    log "❌ Upload Google Drive thất bại"
    return 1
  fi

  log "🗑 Dọn Google Drive backup cũ hơn $GDRIVE_RETENTION_DAYS ngày..."
  rclone lsf "$GDRIVE_REMOTE" --dirs-only --config "$RCLONE_CONFIG" 2>/dev/null | while read -r folder; do
    folder_name="${folder%/}"
    if [[ "$folder_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      folder_date=""
      cutoff_date=""
      folder_date=$(date -d "$folder_name" +%s 2>/dev/null)
      cutoff_date=$(date -d "-${GDRIVE_RETENTION_DAYS} days" +%s 2>/dev/null)
      if [ -n "$folder_date" ] && [ "$folder_date" -lt "$cutoff_date" ]; then
        log "  🗑 Xoá Google Drive/$folder_name"
        rclone purge "$GDRIVE_REMOTE/$folder_name" \
          --config "$RCLONE_CONFIG" \
          --log-file "$LOG_FILE" \
          --log-level INFO 2>>"$LOG_FILE"
      fi
    fi
  done

  log "✅ Dọn Google Drive xong"
  return 0
}

cleanup_local_old_backups() {
  local base=""
  local dir_date=""
  local cutoff_date=""

  log "🗑 Dọn local backup cũ hơn $RETENTION_DAYS ngày..."

  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    base="$(basename "$dir")"

    if [[ "$base" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      dir_date=$(date -d "$base" +%s 2>/dev/null)
      cutoff_date=$(date -d "-${RETENTION_DAYS} days" +%s 2>/dev/null)
      if [ -n "$dir_date" ] && [ "$dir_date" -lt "$cutoff_date" ]; then
        log "  🗑 Xoá local/$base"
        rm -rf "$dir"
      fi
    fi
  done

  # Dọn thư mục tạm còn sót (nếu có)
  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
    \( -name '.staging-*' -o -name '.new-*' -o -name '.prev-*' \) \
    -mtime +1 -exec rm -rf {} + 2>/dev/null || true

  log "✅ Dọn local xong"
}

notify_finish() {
  local total_time total_size summary_msg detail_msg
  total_time="$(elapsed_since "$START_TS")"
  total_size="$(human_size "$FINAL_DIR")"

  if [ "$TOTAL_ERRORS" -eq 0 ]; then
    FINAL_ICON="✅"
  else
    FINAL_ICON="⚠️"
  fi

  summary_msg="$FINAL_ICON <b>Backup WordOps hoàn tất</b>
<b>Server:</b> $(escape_html "$HOSTNAME_SHORT")
<b>Thời gian:</b> $DATE_HUMAN
<b>Runtime:</b> $total_time
<b>Tổng dung lượng:</b> $total_size
<b>Sites:</b> $SITE_COUNT (✅ $SUCCESS_COUNT | ❌ $FAIL_COUNT)
<b>Google Drive:</b> $GDRIVE_STATUS"

  detail_msg="<b>Chi tiết theo site</b>
$SITE_REPORTS_HTML"

  send_telegram_message "$summary_msg" || true
  send_telegram_message "$detail_msg" || true

  log "⏱ Thời gian chạy: $total_time"
}

cleanup_on_exit() {
  if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
    rm -rf "$STAGING_DIR"
  fi

  if [ -n "$NEW_FINAL_DIR" ] && [ -d "$NEW_FINAL_DIR" ]; then
    rm -rf "$NEW_FINAL_DIR"
  fi
}

# ==== MAIN ====
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"
trap cleanup_on_exit EXIT

acquire_lock

log "╔══════════════════════════════════════╗"
log "║       BẮT ĐẦU BACKUP WORDOPS        ║"
log "╚══════════════════════════════════════╝"
log "📅 Thời gian: $DATE_HUMAN"
log "🖥 Server: $HOSTNAME_SHORT"

send_telegram_message "🔄 <b>Backup WordOps bắt đầu</b>
Server: $(escape_html "$HOSTNAME_SHORT")
Time: $DATE_HUMAN
Scan path: $(escape_html "$WEB_ROOT")" || true

if ! preflight_check; then
  notify_finish
  exit 1
fi

discover_sites
if [ "${#FOUND_SITES[@]}" -eq 0 ]; then
  log "❌ Không tìm thấy site WordPress hợp lệ"
  TOTAL_ERRORS=$((TOTAL_ERRORS+1))
  notify_finish
  exit 1
fi

mkdir -p "$STAGING_DIR"

for site in "${FOUND_SITES[@]}"; do
  backup_site "$site"
done

if ! commit_staging_atomic; then
  notify_finish
  exit 1
fi

upload_to_gdrive || true
cleanup_local_old_backups

# Chỉ dọn bản cũ cùng ngày sau khi backup mới đã hoàn tất
if [ -n "$PREV_FINAL_DIR" ] && [ -d "$PREV_FINAL_DIR" ]; then
  rm -rf "$PREV_FINAL_DIR"
  PREV_FINAL_DIR=""
fi

log ""
log "╔══════════════════════════════════════╗"
log "║         KẾT THÚC BACKUP              ║"
log "╚══════════════════════════════════════╝"
log "📊 Tổng sites: $SITE_COUNT | ✅ $SUCCESS_COUNT OK | ❌ $FAIL_COUNT lỗi"
log "☁️ Google Drive: $GDRIVE_STATUS"

notify_finish

if [ "$TOTAL_ERRORS" -gt 0 ]; then
  exit 1
fi

exit 0
