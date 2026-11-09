#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -f "docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

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
  upgrade|update)
    dc pull
    dc up -d
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="$BACKUP_DIR/supabase-db-$TIMESTAMP.sql.gz"
    echo "📦 Backing up Supabase database (service: db) to $ARCHIVE..."
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      dc exec -T db pg_dump -U "postgres" "postgres" | gzip > "$ARCHIVE"
      chmod 600 "$ARCHIVE"
      echo "✅ Database backup complete: $ARCHIVE"
    else
      echo "❌ Database service 'db' is not running. Run './supa.sh start' first."
      exit 1
    fi
    cp .env "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    chmod 600 "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./supa.sh restore <backup-file.sql.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    if ! dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      echo "❌ Database service 'db' is not running. Run './supa.sh start' first."
      exit 1
    fi
    echo "⚠️  Restoring database from $RESTORE_FILE will overwrite current Supabase data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "📦 Creating safety pre-restore backup at $PRE_BACKUP..."
    dc exec -T db pg_dump -U "postgres" "postgres" 2>/dev/null | gzip > "$PRE_BACKUP" || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping API services during restore..."
    dc stop rest auth realtime storage functions 2>/dev/null || true
    echo "📥 Importing database..."
    gzip -dc "$RESTORE_FILE" | dc exec -T db psql -U "postgres" -d "postgres"
    echo "🚀 Restarting services..."
    dc start rest auth realtime storage functions 2>/dev/null || true
    echo "✅ Database restored successfully!"
    ;;
  doctor)
    echo "🩺 Running Supabase Diagnostics..."
    echo "----------------------------------------"
    echo "1. Container Status:"
    dc ps
    echo ""
    echo "2. Port Listeners:"
    [[ -n "$HTTP_PORT" ]] || HTTP_PORT="8000"
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$HTTP_PORT" -sTCP:LISTEN -n -P || echo "Port $HTTP_PORT not listening"
    fi
    echo ""
    echo "3. Health Checks:"
    check_service kong || true
    check_service studio || true
    check_service auth || true
    check_service rest || true
    check_service db || true
    echo ""
    echo "4. Database Readiness:"
    if dc exec -T db pg_isready -U "postgres" 2>/dev/null; then
      echo "✅ PostgreSQL (db) is ready"
    else
      echo "❌ PostgreSQL is not ready"
    fi
    echo ""
    echo "5. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
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
  uninstall)
    echo "⚠️  Uninstall Supabase"
    echo "Choose uninstall mode:"
    echo "  1) Stop and remove containers and networks (KEEP data volumes)"
    echo "  2) FULL PURGE: Remove containers, networks, data volumes, and installation files"
    echo "  3) Cancel"
    read -r -p "Select [1-3]: " uopt
    case "$uopt" in
      1)
        dc down
        echo "✅ Containers removed. Data preserved in volumes."
        ;;
      2)
        read -r -p "Are you ABSOLUTELY sure? All schemas, users, and tables will be DELETED forever! (type 'yes'): " uconfirm
        if [[ "$uconfirm" == "yes" ]]; then
          dc down -v --remove-orphans
          cd ..
          rm -rf "$(basename "$PWD")"
          echo "✅ Full purge complete. Directory removed."
        else
          echo "Uninstall cancelled."
        fi
        ;;
      *)
        echo "Cancelled."
        ;;
    esac
    ;;
  reset)
    echo "This will remove Supabase containers and volumes."
    read -rp "Type 'yes' to continue: " confirm
    [[ "$confirm" == "yes" ]] || exit 1
    dc down -v --remove-orphans
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs [service]|health|backup|restore <file>|doctor|upgrade|env|keys|uninstall|reset}"
    exit 1
    ;;
esac
