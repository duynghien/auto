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

env_val() {
  local key="$1"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2-
}

compose_up() {
  local retries="${N8N_START_RETRIES:-3}"
  local ok="false"

  for attempt in $(seq 1 "$retries"); do
    if [[ "$(env_val ENABLE_CUSTOM_IMAGE)" == "true" ]]; then
      if dc up -d --build; then
        ok="true"
        break
      fi
    else
      if dc up -d --pull always; then
        ok="true"
        break
      fi
    fi
    sleep 10
  done

  [[ "$ok" == "true" ]] || return 1
}

case "${1:-}" in
  start)
    echo "Starting n8n stack..."
    compose_up
    echo "Started: $(env_val N8N_EDITOR_BASE_URL)"
    ;;
  stop)
    echo "Stopping n8n stack..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting n8n stack..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-n8n}"
    ;;
  health)
    PORT="$(env_val N8N_PORT)"
    PORT="${PORT:-5678}"
    if curl -fsS "http://localhost:${PORT}/healthz" >/dev/null 2>&1; then
      echo "Health OK: http://localhost:${PORT}/healthz"
    else
      echo "Health FAILED: http://localhost:${PORT}/healthz"
      exit 1
    fi
    ;;
  open)
    URL="$(env_val N8N_EDITOR_BASE_URL)"
    URL="${URL:-http://localhost:5678}"
    if command -v open >/dev/null 2>&1; then
      open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$URL"
    else
      echo "$URL"
    fi
    ;;
  upgrade|update)
    echo "Upgrading n8n stack..."
    if [[ "$(env_val ENABLE_CUSTOM_IMAGE)" == "true" ]]; then
      dc build --pull
      dc up -d
    else
      dc pull
      dc up -d
    fi
    echo "Upgrade complete"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    if [[ "$(env_val USE_POSTGRES)" == "true" ]] || dc ps --services --filter "status=running" 2>/dev/null | grep -q "postgres"; then
      ARCHIVE="$BACKUP_DIR/n8n-backup-$TIMESTAMP.sql.gz"
      echo "📦 Backing up PostgreSQL database to $ARCHIVE..."
      PG_USER="$(env_val DB_POSTGRESDB_USER)"
      [ -z "$PG_USER" ] && PG_USER="n8n"
      PG_DB="$(env_val DB_POSTGRESDB_DATABASE)"
      [ -z "$PG_DB" ] && PG_DB="n8n"
      dc exec -T postgres pg_dump -U "$PG_USER" "$PG_DB" | gzip > "$ARCHIVE"
      chmod 600 "$ARCHIVE"
      echo "✅ PostgreSQL backup completed: $ARCHIVE"
    else
      ARCHIVE="$BACKUP_DIR/n8n-data-$TIMESTAMP.tar.gz"
      echo "📦 Backing up SQLite / data directory to $ARCHIVE..."
      tar -czf "$ARCHIVE" -C data . 2>/dev/null || true
      chmod 600 "$ARCHIVE"
      echo "✅ Data backup completed: $ARCHIVE"
    fi
    cp .env "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    chmod 600 "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./n8n.sh restore <backup-file.sql.gz|tar.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    echo "⚠️  Restoring will overwrite current n8n data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S)"
    echo "📦 Creating safety pre-restore backup..."
    if [[ "$RESTORE_FILE" == *.sql.gz ]]; then
      PG_USER="$(env_val DB_POSTGRESDB_USER)"
      [ -z "$PG_USER" ] && PG_USER="n8n"
      PG_DB="$(env_val DB_POSTGRESDB_DATABASE)"
      [ -z "$PG_DB" ] && PG_DB="n8n"
      dc exec -T postgres pg_dump -U "$PG_USER" "$PG_DB" 2>/dev/null | gzip > "${PRE_BACKUP}.sql.gz" || true
      chmod 600 "${PRE_BACKUP}.sql.gz" 2>/dev/null || true
      echo "🛑 Stopping n8n web/workers during restore..."
      dc stop n8n 2>/dev/null || true
      echo "📥 Importing database..."
      gzip -dc "$RESTORE_FILE" | dc exec -T postgres psql -U "$PG_USER" -d "$PG_DB"
      echo "🚀 Restarting n8n..."
      dc start n8n
      echo "✅ PostgreSQL database restored successfully!"
    else
      tar -czf "${PRE_BACKUP}.tar.gz" -C data . 2>/dev/null || true
      chmod 600 "${PRE_BACKUP}.tar.gz" 2>/dev/null || true
      echo "🛑 Stopping n8n during restore..."
      dc stop
      tar -xzf "$RESTORE_FILE" -C data
      echo "🚀 Restarting services..."
      dc start
      echo "✅ Data restored successfully!"
    fi
    ;;
  doctor)
    echo "🩺 Running n8n Diagnostics..."
    echo "----------------------------------------"
    echo "1. Container Status:"
    dc ps
    echo ""
    echo "2. Port Listeners:"
    PORT="$(env_val N8N_PORT)"
    PORT="${PORT:-5678}"
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$PORT" -sTCP:LISTEN -n -P || echo "Port $PORT not listening"
    fi
    echo ""
    echo "3. Health Check:"
    if curl -fsS "http://localhost:${PORT}/healthz" >/dev/null 2>&1; then
      echo "✅ Healthz OK"
    else
      echo "⚠️  Healthz check failed on port $PORT"
    fi
    echo ""
    echo "4. Database Check:"
    if [[ "$(env_val USE_POSTGRES)" == "true" ]]; then
      PG_USER="$(env_val DB_POSTGRESDB_USER)"
      [ -z "$PG_USER" ] && PG_USER="n8n"
      if dc exec -T postgres pg_isready -U "$PG_USER" 2>/dev/null; then
        echo "✅ PostgreSQL is ready"
      else
        echo "❌ PostgreSQL is not ready"
      fi
    else
      echo "ℹ️  Using SQLite database"
    fi
    echo ""
    echo "5. Compose Config Validation:"
    dc config -q && echo "✅ Compose file syntax is valid" || echo "❌ Compose file validation error"
    echo ""
    echo "6. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  uninstall)
    echo "⚠️  Uninstall n8n"
    echo "Choose uninstall mode:"
    echo "  1) Stop and remove containers and networks (KEEP data volumes)"
    echo "  2) FULL PURGE: Remove containers, networks, data volumes, and installation files"
    echo "  3) Cancel"
    read -r -p "Select [1-3]: " uopt
    case "$uopt" in
      1)
        dc down
        echo "✅ Containers removed. Data preserved in ./data."
        ;;
      2)
        read -r -p "Are you ABSOLUTELY sure? All workflows, executions, and credentials will be DELETED forever! (type 'yes'): " uconfirm
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
  env)
    echo "Environment summary (.env):"
    grep -E '^(N8N_EDITOR_BASE_URL|N8N_HOST|N8N_PROTOCOL|N8N_PORT|DB_TYPE|EXECUTIONS_MODE|ENABLE_WORKER|ENABLE_WEBHOOK_PROCESSOR|USE_POSTGRES|USE_REDIS|ENABLE_TASK_RUNNERS_EXTERNAL|ENABLE_FFMPEG|ENABLE_PUPPETEER|ENABLE_BROWSERLESS|ENABLE_FFMPEG_HELPER|ENABLE_S3_BINARY_MODE)=' .env || true
    ;;
  reset)
    echo "WARNING: This will DELETE all local n8n data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "n8n Helper"
    echo ""
    echo "Usage: ./n8n.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start/upgrade stack"
    echo "  stop         - Stop services"
    echo "  restart      - Restart services"
    echo "  status       - Show service status"
    echo "  logs [svc]   - Follow logs (default: n8n)"
    echo "  health       - Check /healthz endpoint"
    echo "  backup       - Safe database & .env backup to ./backups"
    echo "  restore <f>  - Restore database from backup file"
    echo "  doctor       - Run diagnostic checks"
    echo "  open         - Open n8n URL in browser"
    echo "  upgrade      - Pull/update containers (alias: update)"
    echo "  env          - Show selected env values"
    echo "  uninstall    - Uninstall containers (keep data or purge)"
    echo "  reset        - Delete all local data"
    ;;
esac
