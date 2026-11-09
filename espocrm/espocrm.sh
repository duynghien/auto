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

read_env() {
  local key="$1"
  grep -m1 "^${key}=" .env 2>/dev/null | cut -d= -f2- || true
}

app_url() {
  local value
  value=$(read_env "ESPOCRM_SITE_URL")
  echo "${value:-http://localhost:8080}"
}

ws_url() {
  local value
  value=$(read_env "ESPOCRM_WS_URL")
  echo "${value:-ws://localhost:8081}"
}

http_port() {
  local value
  value=$(read_env "ESPOCRM_HTTP_PORT")
  echo "${value:-8080}"
}

ws_port() {
  local value
  value=$(read_env "ESPOCRM_WS_PORT")
  echo "${value:-8081}"
}

db_name() {
  local value
  value=$(read_env "MARIADB_DATABASE")
  echo "${value:-espocrm}"
}

db_user() {
  local value
  value=$(read_env "MARIADB_USER")
  echo "${value:-espocrm}"
}

db_password() {
  local value
  value=$(read_env "MARIADB_PASSWORD")
  echo "${value:-}"
}

backup_name() {
  date +"backups/espocrm-db-backup-%Y%m%d-%H%M%S.sql"
}

case "${1:-}" in
  start)
    echo "Starting EspoCRM..."
    dc up -d --pull always
    echo "Started: $(app_url)"
    ;;
  stop)
    echo "Stopping EspoCRM..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting EspoCRM..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-app}"
    ;;
  health)
    PORT=$(http_port)
    WS_PORT=$(ws_port)
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "Web OK: http://localhost:${PORT}"
    else
      echo "Web failed: http://localhost:${PORT}"
      exit 1
    fi

    if dc exec -T db mariadb-admin ping -h localhost -uroot -p"$(read_env MARIADB_ROOT_PASSWORD)" >/dev/null 2>&1; then
      echo "DB OK"
    else
      echo "DB failed"
      exit 1
    fi

    if (echo > /dev/tcp/127.0.0.1/"${WS_PORT}") >/dev/null 2>&1; then
      echo "WebSocket port open: ${WS_PORT}"
    else
      echo "WebSocket port not reachable: ${WS_PORT}"
      exit 1
    fi
    ;;
  upgrade|update)
    echo "Upgrading EspoCRM images..."
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE="backups/espocrm-db-backup-$TIMESTAMP.sql.gz"
    USERNAME="$(db_user)"
    DATABASE="$(db_name)"
    PASSWORD="$(db_password)"
    if [[ -z "$PASSWORD" ]]; then
      echo "Database password is missing in .env"
      exit 1
    fi
    echo "📦 Backing up MariaDB to $FILE..."
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      dc exec -T -e MYSQL_PWD="$PASSWORD" db mariadb-dump -u"$USERNAME" "$DATABASE" | gzip > "$FILE"
      chmod 600 "$FILE"
      cp .env "backups/.env-$TIMESTAMP" 2>/dev/null || true
      chmod 600 "backups/.env-$TIMESTAMP" 2>/dev/null || true
      echo "✅ Backup saved: $FILE"
    else
      echo "❌ Database service 'db' is not running. Run './espocrm.sh start' first."
      exit 1
    fi
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./espocrm.sh restore <backup-file.sql.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    if ! dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      echo "❌ Database service 'db' is not running. Run './espocrm.sh start' first."
      exit 1
    fi
    USERNAME="$(db_user)"
    DATABASE="$(db_name)"
    PASSWORD="$(db_password)"
    echo "⚠️  Restoring database from $RESTORE_FILE will overwrite current EspoCRM data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 backups
    PRE_BACKUP="backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "📦 Creating safety pre-restore backup at $PRE_BACKUP..."
    dc exec -T -e MYSQL_PWD="$PASSWORD" db mariadb-dump -u"$USERNAME" "$DATABASE" 2>/dev/null | gzip > "$PRE_BACKUP" || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping web app & daemon during restore..."
    dc stop app daemon 2>/dev/null || true
    echo "📥 Importing database..."
    gzip -dc "$RESTORE_FILE" | dc exec -T -e MYSQL_PWD="$PASSWORD" db mariadb -u"$USERNAME" "$DATABASE"
    echo "🚀 Restarting services..."
    dc start app daemon 2>/dev/null || true
    echo "✅ Database restored successfully!"
    ;;
  doctor)
    echo "🩺 Running EspoCRM Diagnostics..."
    echo "----------------------------------------"
    echo "1. Container Status:"
    dc ps
    echo ""
    echo "2. Port Listeners:"
    PORT=$(http_port)
    WS_PORT=$(ws_port)
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$PORT" -sTCP:LISTEN -n -P || echo "Port $PORT not listening"
      lsof -iTCP:"$WS_PORT" -sTCP:LISTEN -n -P || echo "Port $WS_PORT not listening"
    fi
    echo ""
    echo "3. Health Check:"
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "✅ Web OK (http://localhost:${PORT})"
    else
      echo "⚠️  Web check warning (http://localhost:${PORT})"
    fi
    echo ""
    echo "4. Database Check:"
    ROOT_PWD=$(read_env MARIADB_ROOT_PASSWORD)
    if dc exec -T -e MYSQL_PWD="$ROOT_PWD" db mariadb-admin ping -h localhost -uroot >/dev/null 2>&1; then
      echo "✅ MariaDB (db) is responsive"
    else
      echo "❌ MariaDB is not responding"
    fi
    echo ""
    echo "5. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  uninstall)
    echo "⚠️  Uninstall EspoCRM"
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
        read -r -p "Are you ABSOLUTELY sure? All contacts, deals, and records will be DELETED forever! (type 'yes'): " uconfirm
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
  db-shell)
    USERNAME="$(db_user)"
    DATABASE="$(db_name)"
    PASSWORD="$(db_password)"
    if [[ -z "$PASSWORD" ]]; then
      echo "Database password is missing in .env"
      exit 1
    fi
    dc exec db mariadb -u"$USERNAME" -p"$PASSWORD" "$DATABASE"
    ;;
  admin)
    echo "Initial admin bootstrap (first run only):"
    grep -E '^(ESPOCRM_ADMIN_USERNAME|ESPOCRM_ADMIN_PASSWORD)=' .env || true
    ;;
  upgrade)
    echo "Upgrading EspoCRM images..."
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  reset)
    echo "WARNING: This will DELETE all EspoCRM data volumes and backups."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      rm -rf backups
      mkdir -p backups
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "EspoCRM Helper"
    echo ""
    echo "Usage: ./espocrm.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start       - Start services"
    echo "  stop        - Stop services"
    echo "  restart     - Restart services"
    echo "  status      - Show service status"
    echo "  logs [svc]  - Follow logs (default: app)"
    echo "  health      - Check web, db and websocket ports"
    echo "  backup      - Safe database & .env backup to ./backups"
    echo "  restore <f> - Safe database restore with pre-restore dump"
    echo "  doctor      - Run diagnostic checks"
    echo "  db-shell    - Open MariaDB shell"
    echo "  admin       - Show bootstrap admin credentials"
    echo "  upgrade     - Pull latest images and restart (alias: update)"
    echo "  uninstall   - Uninstall containers (keep data or full purge)"
    echo "  reset       - Delete all local data"
    ;;
esac
