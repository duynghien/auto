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

dr() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    sudo docker "$@"
  else
    echo "Docker daemon is not accessible."
    exit 1
  fi
}

ensure_shared_network() {
  if dr network inspect prometheus-shared >/dev/null 2>&1; then
    return 0
  fi

  dr network create prometheus-shared >/dev/null
}

prometheus_url() {
  grep '^PROMETHEUS_URL=' .env 2>/dev/null | cut -d= -f2- || echo "http://localhost:9090"
}

http_port() {
  grep '^PROMETHEUS_HTTP_PORT=' .env 2>/dev/null | cut -d= -f2- || echo "9090"
}

prometheus_image() {
  grep '^PROMETHEUS_IMAGE=' .env 2>/dev/null | cut -d= -f2- || echo "prom/prometheus:latest"
}

config_check() {
  dr run --rm \
    -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
    -v "$PWD/rules:/etc/prometheus/rules:ro" \
    --entrypoint /bin/promtool \
    "$(prometheus_image)" check config /etc/prometheus/prometheus.yml
}

case "${1:-}" in
  start)
    echo "Starting Prometheus..."
    ensure_shared_network
    dc up -d --pull always
    echo "Started: $(prometheus_url)"
    ;;
  stop)
    echo "Stopping Prometheus..."
    dc stop
    echo "Stopped"
    ;;
  restart)
    echo "Restarting Prometheus..."
    dc restart
    echo "Restarted"
    ;;
  status)
    dc ps
    ;;
  logs)
    dc logs -f "${2:-prometheus}"
    ;;
  health)
    PORT=$(http_port)
    curl -fsS "http://localhost:${PORT}/-/healthy" >/dev/null
    curl -fsS "http://localhost:${PORT}/-/ready" >/dev/null
    echo "Health OK: http://localhost:${PORT}/-/healthy"
    echo "Ready OK:  http://localhost:${PORT}/-/ready"
    ;;
  reload)
    PORT=$(http_port)
    curl -fsS -X POST "http://localhost:${PORT}/-/reload" >/dev/null
    echo "Configuration reloaded"
    ;;
  config-check)
    config_check
    ;;
  upgrade|update)
    echo "Upgrading Prometheus images..."
    ensure_shared_network
    dc pull
    dc up -d
    echo "Upgrade complete"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="$BACKUP_DIR/prometheus-config-$TIMESTAMP.tar.gz"
    echo "📦 Backing up Prometheus configurations to $ARCHIVE..."
    tar -czf "$ARCHIVE" prometheus.yml rules .env 2>/dev/null || tar -czf "$ARCHIVE" prometheus.yml .env 2>/dev/null
    chmod 600 "$ARCHIVE"
    if dc ps --services --filter "status=running" 2>/dev/null | grep -qx "prometheus"; then
      echo "📦 Backing up TSDB data volume..."
      dc run --rm -v "$(pwd)/$BACKUP_DIR:/backup" -v prometheus_data:/prometheus:ro alpine tar -czf "/backup/prometheus-tsdb-$TIMESTAMP.tar.gz" -C /prometheus . 2>/dev/null || true
      chmod 600 "$BACKUP_DIR/prometheus-tsdb-$TIMESTAMP.tar.gz" 2>/dev/null || true
    fi
    echo "✅ Prometheus backup complete: $ARCHIVE"
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./prometheus.sh restore <backup-file.tar.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    echo "⚠️  Restoring Prometheus configuration from $RESTORE_FILE will overwrite current configs!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz"
    echo "📦 Creating safety pre-restore backup..."
    tar -czf "$PRE_BACKUP" prometheus.yml rules .env 2>/dev/null || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping Prometheus during restore..."
    dc stop
    tar -xzf "$RESTORE_FILE"
    echo "🚀 Restarting Prometheus..."
    dc start
    echo "✅ Configuration restored successfully!"
    ;;
  doctor)
    echo "🩺 Running Prometheus Diagnostics..."
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
    if curl -fsS "http://localhost:${PORT}/-/healthy" >/dev/null 2>&1; then
      echo "✅ Healthy: http://localhost:${PORT}/-/healthy"
    else
      echo "❌ Not healthy: http://localhost:${PORT}/-/healthy"
    fi
    if curl -fsS "http://localhost:${PORT}/-/ready" >/dev/null 2>&1; then
      echo "✅ Ready:   http://localhost:${PORT}/-/ready"
    else
      echo "⚠️  Not ready: http://localhost:${PORT}/-/ready"
    fi
    echo ""
    echo "4. Config Check (promtool):"
    config_check || echo "⚠️  Promtool check had warnings"
    echo ""
    echo "5. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  uninstall)
    echo "⚠️  Uninstall Prometheus"
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
        read -r -p "Are you ABSOLUTELY sure? All metrics and rules will be DELETED forever! (type 'yes'): " uconfirm
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
    echo "This will DELETE Prometheus TSDB data volume."
    read -rp "Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
      dc down -v
      echo "Data deleted"
    else
      echo "Cancelled"
    fi
    ;;
  *)
    echo "Prometheus Helper"
    echo ""
    echo "Usage: ./prometheus.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start         - Start/upgrade stack"
    echo "  stop          - Stop services"
    echo "  restart       - Restart services"
    echo "  status        - Show service status"
    echo "  logs [svc]    - Follow logs (default: prometheus)"
    echo "  health        - Check /-/healthy and /-/ready"
    echo "  backup        - Backup config & TSDB volume to ./backups"
    echo "  restore <f>   - Restore configuration from backup"
    echo "  doctor        - Run diagnostic checks"
    echo "  reload        - Reload prometheus.yml without restart"
    echo "  config-check  - Validate prometheus.yml via promtool"
    echo "  upgrade       - Pull latest images and restart (alias: update)"
    echo "  uninstall     - Uninstall containers (keep data or full purge)"
    echo "  reset         - Delete Prometheus data volume"
    ;;
esac
