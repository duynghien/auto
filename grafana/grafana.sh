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

dashboard_uid() {
  echo "prometheus-overview"
}

grafana_url() {
  grep '^GRAFANA_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:3000"
}

http_port() {
  grep '^GRAFANA_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "3000"
}

admin_user() {
  grep '^GRAFANA_ADMIN_USER=' .env 2>/dev/null | cut -d= -f2- || echo "admin"
}

admin_password() {
  grep '^GRAFANA_ADMIN_PASSWORD=' .env 2>/dev/null | cut -d= -f2- || echo "admin"
}

prometheus_display_url() {
  grep '^GRAFANA_PROMETHEUS_DISPLAY_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:9090"
}

use_local_prometheus() {
  grep '^GRAFANA_USE_LOCAL_PROMETHEUS=' .env 2>/dev/null | cut -d= -f2- || echo "false"
}

ensure_prometheus_shared_network() {
  if [[ "$(use_local_prometheus)" != "true" ]]; then
    return 0
  fi

  if docker info >/dev/null 2>&1; then
    docker network inspect prometheus-shared >/dev/null 2>&1 || docker network create prometheus-shared >/dev/null
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker network inspect prometheus-shared >/dev/null 2>&1 || sudo docker network create prometheus-shared >/dev/null
  fi
}

case "${1:-}" in
  start)
    echo "Starting Grafana..."
    ensure_prometheus_shared_network
    dc up -d --pull always
    echo "Started: $(grafana_url)"
    ;;
  stop)
    echo "Stopping Grafana..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting Grafana..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-grafana}"
    ;;
  health)
    PORT=$(http_port)
    curl -fsS "http://localhost:${PORT}/api/health"
    ;;
  datasource)
    PORT=$(http_port)
    curl -fsS -u "$(admin_user):$(admin_password)" "http://localhost:${PORT}/api/datasources/uid/prometheus-main"
    ;;
  dashboard)
    PORT=$(http_port)
    curl -fsS -u "$(admin_user):$(admin_password)" "http://localhost:${PORT}/api/dashboards/uid/$(dashboard_uid)"
    ;;
  credentials)
    echo "Grafana URL: $(grafana_url)"
    echo "Admin user:  $(admin_user)"
    echo "Admin pass:  $(admin_password)"
    echo "Prometheus:  $(prometheus_display_url)"
    ;;
  upgrade|update)
    echo "Upgrading Grafana images..."
    ensure_prometheus_shared_network
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="$BACKUP_DIR/grafana-backup-$TIMESTAMP.tar.gz"
    echo "📦 Backing up Grafana provisioning and config to $ARCHIVE..."
    tar -czf "$ARCHIVE" provisioning dashboards .env 2>/dev/null || tar -czf "$ARCHIVE" provisioning .env 2>/dev/null
    chmod 600 "$ARCHIVE"
    # Also backup named volume if docker is available
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "grafana"; then
      dc run --rm -v "$(pwd)/$BACKUP_DIR:/backup" -v grafana_data:/var/lib/grafana:ro alpine tar -czf "/backup/grafana-data-$TIMESTAMP.tar.gz" -C /var/lib/grafana . 2>/dev/null || true
      chmod 600 "$BACKUP_DIR/grafana-data-$TIMESTAMP.tar.gz" 2>/dev/null || true
    fi
    echo "✅ Grafana backup completed: $ARCHIVE"
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./grafana.sh restore <backup-file.tar.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    echo "⚠️  Restoring Grafana configuration from $RESTORE_FILE will overwrite current configs!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz"
    echo "📦 Creating safety pre-restore backup..."
    tar -czf "$PRE_BACKUP" provisioning .env 2>/dev/null || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping Grafana during restore..."
    dc stop
    tar -xzf "$RESTORE_FILE"
    echo "🚀 Restarting Grafana..."
    dc start
    echo "✅ Configuration restored successfully!"
    ;;
  doctor)
    echo "🩺 Running Grafana Diagnostics..."
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
    if curl -fsS "http://localhost:${PORT}/api/health" >/dev/null 2>&1; then
      echo "✅ Health API OK: http://localhost:${PORT}/api/health"
    else
      echo "⚠️  Health API check warning"
    fi
    echo ""
    echo "4. Datasource Check:"
    if curl -fsS -u "$(admin_user):$(admin_password)" "http://localhost:${PORT}/api/datasources/uid/prometheus-main" >/dev/null 2>&1; then
      echo "✅ Prometheus datasource is configured"
    else
      echo "⚠️  Prometheus datasource check warning"
    fi
    echo ""
    echo "5. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  uninstall)
    echo "⚠️  Uninstall Grafana"
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
        read -r -p "Are you ABSOLUTELY sure? All dashboards, alerts, and settings will be DELETED forever! (type 'yes'): " uconfirm
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
    echo "This will DELETE Grafana data volume."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Grafana Helper"
    echo ""
    echo "Usage: ./grafana.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start/upgrade stack"
    echo "  stop         - Stop services"
    echo "  restart      - Restart services"
    echo "  status       - Show service status"
    echo "  logs [svc]   - Follow logs (default: grafana)"
    echo "  health       - Check /api/health"
    echo "  backup       - Backup provisioning & data volume to ./backups"
    echo "  restore <f>  - Restore configuration from backup"
    echo "  doctor       - Run diagnostic checks"
    echo "  datasource   - Show provisioned Prometheus datasource"
    echo "  dashboard    - Show starter dashboard metadata"
    echo "  credentials  - Show Grafana login and Prometheus target"
    echo "  upgrade      - Pull latest images and restart (alias: update)"
    echo "  uninstall    - Uninstall containers (keep data or full purge)"
    echo "  reset        - Delete Grafana data volume"
    ;;
 esac
