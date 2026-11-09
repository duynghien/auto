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
  grep '^MATOMO_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:8080"
}

http_port() {
  grep '^MATOMO_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "8080"
}

backup_name() {
  date +"matomo-db-backup-%Y%m%d-%H%M%S.sql"
}

case "${1:-}" in
  start)
    echo "🚀 Starting Matomo..."
    dc up -d --pull always
    echo "✅ Started: $(app_url)"
    ;;
  stop)
    echo "🛑 Stopping Matomo..."
    dc stop
    echo "✅ Stopped"
    ;;
  restart)
    echo "🔄 Restarting Matomo..."
    dc restart
    echo "✅ Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-matomo}"
    ;;
  health)
    PORT=$(http_port)
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "✅ Health OK: http://localhost:${PORT}"
    else
      echo "❌ Health failed: http://localhost:${PORT}"
      exit 1
    fi
    ;;

  upgrade|update)
    echo "⬆️  Upgrading Matomo images..."
    dc pull
    dc up -d
    echo "✅ Upgrade complete"
    ;;
  backup)
    mkdir -p -m 700 backups
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    FILE="backups/matomo-db-backup-$TIMESTAMP.sql.gz"
    echo "📦 Backing up MariaDB database to $FILE..."
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      dc exec -T db sh -c 'exec mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' | gzip > "$FILE"
      chmod 600 "$FILE"
      cp .env "backups/.env-$TIMESTAMP" 2>/dev/null || true
      chmod 600 "backups/.env-$TIMESTAMP" 2>/dev/null || true
      echo "✅ Backup saved: $FILE"
    else
      echo "❌ Database service 'db' is not running. Run './matomo.sh start' first."
      exit 1
    fi
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./matomo.sh restore <backup-file.sql.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    if ! dc ps --services --filter "status=running" 2>/dev/null | grep -qx "db"; then
      echo "❌ Database service 'db' is not running. Run './matomo.sh start' first."
      exit 1
    fi
    echo "⚠️  Restoring database from $RESTORE_FILE will overwrite current Matomo data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 backups
    PRE_BACKUP="backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "📦 Creating safety pre-restore backup at $PRE_BACKUP..."
    dc exec -T db sh -c 'exec mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' 2>/dev/null | gzip > "$PRE_BACKUP" || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping Matomo web app during restore..."
    dc stop matomo 2>/dev/null || true
    echo "📥 Importing database..."
    gzip -dc "$RESTORE_FILE" | dc exec -T db sh -c 'exec mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'
    echo "🚀 Restarting Matomo web service..."
    dc start matomo
    echo "✅ Database restored successfully!"
    ;;
  doctor)
    echo "🩺 Running Matomo Diagnostics..."
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
    if curl -fsS "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo "✅ Web OK (http://localhost:${PORT})"
    else
      echo "⚠️  Web check warning (http://localhost:${PORT})"
    fi
    echo ""
    echo "4. Database Check:"
    if dc exec -T db sh -c 'exec mariadb-admin ping -h localhost -uroot -p"$MARIADB_ROOT_PASSWORD"' >/dev/null 2>&1; then
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
    echo "⚠️  Uninstall Matomo"
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
        read -r -p "Are you ABSOLUTELY sure? All tracking data, goals, and analytics will be DELETED forever! (type 'yes'): " uconfirm
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
    echo "⚠️  This will DELETE all Matomo data volumes."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "✅ Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Matomo Helper"
    echo ""
    echo "Usage: ./matomo.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start       - Start services"
    echo "  stop        - Stop services"
    echo "  restart     - Restart services"
    echo "  status      - Show service status"
    echo "  logs [svc]  - Follow logs (default: matomo)"
    echo "  health      - Check Matomo web endpoint"
    echo "  backup      - Safe database & .env backup to ./backups"
    echo "  restore <f> - Safe database restore with pre-restore dump"
    echo "  doctor      - Run diagnostic checks"
    echo "  upgrade     - Pull latest images and restart (alias: update)"
    echo "  uninstall   - Uninstall containers (keep data or full purge)"
    echo "  reset       - Delete all local data"
    ;;
esac
