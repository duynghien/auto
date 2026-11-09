#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

dc() {
  if docker info >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker compose "$@"
  else
    echo "Docker daemon is not accessible."
    exit 1
  fi
}

app_url() {
  grep '^SITE_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:8000"
}

http_port() {
  grep '^POSTHOG_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "8000"
}

compose_up() {
  local parallel="${POSTHOG_PULL_PARALLEL_LIMIT:-4}"
  COMPOSE_PARALLEL_LIMIT="$parallel" dc up -d --pull always
}

refresh_source_snapshot() {
  local ref="${POSTHOG_SOURCE_REF:-master}"
  local archive_url="https://codeload.github.com/PostHog/posthog/tar.gz/refs/heads/${ref}"
  local archive_file=""
  local tmp_dir=""

  archive_file=$(mktemp)
  tmp_dir=$(mktemp -d)

  curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 "$archive_url" -o "$archive_file"
  tar -xzf "$archive_file" -C "$tmp_dir" --strip-components=1

  rm -f "$archive_file"
  rm -rf posthog
  mv "$tmp_dir" posthog
}

apply_posthog_preflight_patch() {
  local views_file="posthog/posthog/views.py"
  local utils_file="posthog/posthog/utils.py"
  [[ -f "$views_file" && -f "$utils_file" ]] || return 0

  python3 - "$views_file" "$utils_file" <<'PYEOF'
import re
import sys
from pathlib import Path

views_path = Path(sys.argv[1])
utils_path = Path(sys.argv[2])

views = views_path.read_text(encoding="utf-8")
utils = utils_path.read_text(encoding="utf-8")

if "is_kafka_alive" not in utils:
    if "import socket\n" not in utils:
        utils = utils.replace("import re\n", "import re\nimport socket\n", 1)

    marker = "\n\ndef get_plugin_server_job_queues() -> Optional[list[str]]:\n"
    kafka_fn = """
def is_kafka_alive() -> bool:
    kafka_hosts = getattr(settings, "KAFKA_HOSTS", "")
    if not kafka_hosts:
        return False

    # KAFKA_HOSTS may be a string ("kafka:9092,kafka2:9092") or list/tuple.
    if isinstance(kafka_hosts, str):
        entries = kafka_hosts.split(",")
    elif isinstance(kafka_hosts, (list, tuple)):
        entries = kafka_hosts
    else:
        entries = [str(kafka_hosts)]

    for entry in entries:
        host_port = entry.strip()
        if not host_port:
            continue
        if ":" in host_port:
            host, port_str = host_port.rsplit(":", 1)
            try:
                port = int(port_str)
            except ValueError:
                port = 9092
        else:
            host, port = host_port, 9092
        try:
            with socket.create_connection((host, port), timeout=2):
                return True
        except OSError:
            continue
    return False

"""
    if marker in utils:
        utils = utils.replace(marker, "\n\n" + kafka_fn + marker, 1)

if "is_kafka_alive," not in views:
    views = views.replace("    is_celery_alive,\n", "    is_celery_alive,\n    is_kafka_alive,\n", 1)

views = re.sub(
    r'"kafka":\s*in_cloud\s*or\s*settings\.TEST,',
    '"kafka": in_cloud or _traced("preflight.is_kafka_alive", is_kafka_alive) or settings.TEST,',
    views,
    count=1,
)

views_path.write_text(views, encoding="utf-8")
utils_path.write_text(utils, encoding="utf-8")
PYEOF
}

apply_runtime_preflight_patch() {
  if ! dc ps --status running --services 2>/dev/null | grep -qx "web"; then
    echo "⚠️  Web container is not running yet, skip runtime Kafka preflight patch."
    return 0
  fi

  if dc exec -T web python - <<'PYEOF'
import re
from pathlib import Path

views_path = Path("/code/posthog/views.py")

if not views_path.exists():
    raise SystemExit("views.py not found in runtime container")

views = views_path.read_text(encoding="utf-8")

if "import socket\n" not in views:
    views = views.replace("import os\n", "import os\nimport socket\n", 1)

if "def _is_kafka_alive() -> bool:" not in views:
    marker = "\n\n@never_cache\ndef preflight_check(request: HttpRequest) -> JsonResponse:\n"
    kafka_fn = """
def _is_kafka_alive() -> bool:
    kafka_hosts = getattr(settings, "KAFKA_HOSTS", "")
    if not kafka_hosts:
        return False

    entries = kafka_hosts.split(",") if isinstance(kafka_hosts, str) else kafka_hosts
    for entry in entries:
        host_port = str(entry).strip()
        if not host_port:
            continue
        if ":" in host_port:
            host, port_str = host_port.rsplit(":", 1)
            try:
                port = int(port_str)
            except ValueError:
                port = 9092
        else:
            host, port = host_port, 9092
        try:
            with socket.create_connection((host, port), timeout=2):
                return True
        except OSError:
            continue
    return False
"""
    if marker in views:
        views = views.replace(marker, "\n\n" + kafka_fn + marker, 1)

views = re.sub(
    r'"kafka":\s*in_cloud\s*or\s*settings\.TEST,',
    '"kafka": in_cloud or _traced("preflight.is_kafka_alive", _is_kafka_alive) or settings.TEST,',
    views,
    count=1,
)

views_path.write_text(views, encoding="utf-8")
print("patched runtime preflight kafka check")
PYEOF
  then
    echo "✅ Patched runtime preflight Kafka check in web container"
    if dc restart web >/dev/null 2>&1; then
      echo "✅ Restarted web container to apply runtime patch"
    else
      echo "⚠️  Could not restart web container after runtime patch"
    fi
  else
    echo "⚠️  Failed to patch runtime preflight Kafka check in web container"
  fi
}

case "${1:-}" in
  start)
    echo "🚀 Starting PostHog..."
    apply_posthog_preflight_patch
    compose_up
    apply_runtime_preflight_patch
    echo "✅ Started: $(app_url)"
    ;;
  start-full)
    echo "🚀 Starting PostHog with optional profiles (temporal + exceptions)..."
    apply_posthog_preflight_patch
    COMPOSE_PARALLEL_LIMIT="${POSTHOG_PULL_PARALLEL_LIMIT:-4}" dc --profile temporal --profile exceptions up -d --pull always
    apply_runtime_preflight_patch
    echo "✅ Full stack started: $(app_url)"
    ;;
  stop)
    echo "🛑 Stopping PostHog..."
    dc stop
    echo "✅ Stopped"
    ;;
  restart)
    echo "🔄 Restarting PostHog..."
    apply_posthog_preflight_patch
    dc restart
    apply_runtime_preflight_patch
    echo "✅ Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-web}"
    ;;
  health)
    PORT=$(http_port)
    if curl -fsS "http://localhost:${PORT}/_health" >/dev/null 2>&1; then
      echo "✅ Health OK: http://localhost:${PORT}/_health"
    else
      echo "❌ Health failed: http://localhost:${PORT}/_health"
      exit 1
    fi
    ;;
  upgrade|update)
    echo "⬆️  Upgrading PostHog source and containers..."
    if [[ -d posthog ]]; then
      refresh_source_snapshot || true
      apply_posthog_preflight_patch
      cp -f posthog/docker-compose.base.yml docker-compose.base.yml
      cp -f posthog/docker-compose.hobby.yml docker-compose.yml
    fi
    compose_up
    apply_runtime_preflight_patch
    echo "✅ Upgrade complete"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="$BACKUP_DIR/posthog-db-$TIMESTAMP.sql.gz"
    echo "📦 Backing up PostgreSQL database to $ARCHIVE..."
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      dc exec -T db pg_dump -U "posthog" "posthog" | gzip > "$ARCHIVE"
      chmod 600 "$ARCHIVE"
      echo "✅ Database backup complete: $ARCHIVE"
    else
      echo "❌ Database service 'db' is not running. Run './hog.sh start' first."
      exit 1
    fi
    cp .env "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    chmod 600 "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./hog.sh restore <backup-file.sql.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    if ! dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      echo "❌ Database service 'db' is not running. Run './hog.sh start' first."
      exit 1
    fi
    echo "⚠️  Restoring PostgreSQL database from $RESTORE_FILE will overwrite existing data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "📦 Creating safety pre-restore backup at $PRE_BACKUP..."
    dc exec -T db pg_dump -U "posthog" "posthog" 2>/dev/null | gzip > "$PRE_BACKUP" || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping web & worker services during restore..."
    dc stop web plugins async-web 2>/dev/null || true
    echo "📥 Importing database..."
    gzip -dc "$RESTORE_FILE" | dc exec -T db psql -U "posthog" -d "posthog"
    echo "🚀 Restarting services..."
    dc start
    echo "✅ Database restored successfully!"
    ;;
  doctor)
    echo "🩺 Running PostHog Diagnostics..."
    echo "----------------------------------------"
    echo "1. Container Status:"
    dc ps
    echo ""
    echo "2. Port Listeners:"
    PORT=$(http_port)
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$PORT" -sTCP:LISTEN -n -P || echo "Port $PORT not listening"
    fi
    echo ""
    echo "3. Health Check:"
    if curl -fsS "http://localhost:${PORT}/_health" >/dev/null 2>&1; then
      echo "✅ Web Health OK (/_health)"
    else
      echo "⚠️  Web Health check failed on port $PORT"
    fi
    echo ""
    echo "4. Database Check:"
    if dc exec -T db pg_isready -U "posthog" 2>/dev/null; then
      echo "✅ PostgreSQL (db) is ready"
    else
      echo "❌ PostgreSQL is not ready"
    fi
    echo ""
    echo "5. ClickHouse Check:"
    if dc ps --services 2>/dev/null | grep -qx "clickhouse"; then
      if dc exec -T clickhouse clickhouse-client --query "SELECT 1" >/dev/null 2>&1; then
        echo "✅ ClickHouse is responding"
      else
        echo "⚠️  ClickHouse check warning"
      fi
    fi
    echo ""
    echo "6. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  uninstall)
    echo "⚠️  Uninstall PostHog"
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
        read -r -p "Are you ABSOLUTELY sure? All events, dashboards, and databases will be DELETED forever! (type 'yes'): " uconfirm
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
    echo "⚠️  This will DELETE all PostHog data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      rm -rf compose share
      echo "✅ Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "PostHog Helper"
    echo ""
    echo "Usage: ./hog.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start       - Start/upgrade stack"
    echo "  start-full  - Start with optional profiles (temporal + exceptions)"
    echo "  stop        - Stop services"
    echo "  restart     - Restart services"
    echo "  status      - Show service status"
    echo "  logs [svc]  - Follow logs (default: web)"
    echo "  health      - Check /_health endpoint"
    echo "  backup      - Safe database & .env backup to ./backups"
    echo "  restore <f> - Restore database from backup file"
    echo "  doctor      - Run diagnostic checks"
    echo "  upgrade     - Pull latest source and restart (alias: update)"
    echo "  uninstall   - Uninstall containers (keep data or purge)"
    echo "  reset       - Delete all local data"
    ;;
esac
