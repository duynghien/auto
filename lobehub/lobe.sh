#!/bin/bash
# LobeHub Helper Script v4.0

cd "$(dirname "$0")"

case "$1" in
  start)
    echo "🚀 Starting LobeHub..."
    docker compose up -d
    APP=$(grep '^APP_URL=' .env 2>/dev/null | cut -d= -f2- || echo 'http://localhost:3210')
    echo "✅ Started! Access: $APP"
    ;;
  stop)
    echo "🛑 Stopping LobeHub..."
    docker compose stop
    echo "✅ Stopped!"
    ;;
  restart)
    echo "🔄 Restarting LobeHub..."
    docker compose restart
    echo "✅ Restarted!"
    ;;
  logs)
    docker compose logs -f "${2:-lobe}"
    ;;
  status)
    docker compose ps
    ;;
  upgrade|update)
    echo "⬆️  Upgrading LobeHub..."
    docker compose pull
    docker compose up -d
    echo "✅ Upgraded!"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="$BACKUP_DIR/lobehub-backup-$TIMESTAMP.sql.gz"
    echo "📦 Backing up PostgreSQL database to $ARCHIVE..."
    if docker compose ps --services --filter "status=running" 2>/dev/null | grep -q "postgresql"; then
      PG_USER=$(grep '^POSTGRES_USER=' .env 2>/dev/null | cut -d= -f2- || echo 'postgres')
      [ -z "$PG_USER" ] && PG_USER="postgres"
      PG_DB=$(grep '^LOBE_DB_NAME=' .env 2>/dev/null | cut -d= -f2- || echo 'lobechat')
      [ -z "$PG_DB" ] && PG_DB="lobechat"
      docker compose exec -T postgresql pg_dump -U "$PG_USER" "$PG_DB" | gzip > "$ARCHIVE"
      chmod 600 "$ARCHIVE"
      cp .env "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
      chmod 600 "$BACKUP_DIR/.env-$TIMESTAMP" 2>/dev/null || true
      echo "✅ Backup completed: $ARCHIVE"
    else
      echo "❌ PostgreSQL container is not running. Run './lobe.sh start' first."
      exit 1
    fi
    ;;
  restore)
    RESTORE_FILE="${2:-}"
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Usage: ./lobe.sh restore <backup-file.sql.gz>"
      exit 1
    fi
    if ! gzip -t "$RESTORE_FILE" 2>/dev/null; then
      echo "❌ Backup file is not a valid gzip file: $RESTORE_FILE"
      exit 1
    fi
    if ! docker compose ps --services --filter "status=running" 2>/dev/null | grep -q "postgresql"; then
      echo "❌ PostgreSQL container is not running. Run './lobe.sh start' first."
      exit 1
    fi
    echo "⚠️  Restoring database from $RESTORE_FILE will overwrite existing data!"
    read -r -p "Are you sure? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 0
    fi
    mkdir -p -m 700 "./backups"
    PRE_BACKUP="./backups/pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    echo "📦 Creating pre-restore safety dump at $PRE_BACKUP..."
    PG_USER=$(grep '^POSTGRES_USER=' .env 2>/dev/null | cut -d= -f2- || echo 'postgres')
    [ -z "$PG_USER" ] && PG_USER="postgres"
    PG_DB=$(grep '^LOBE_DB_NAME=' .env 2>/dev/null | cut -d= -f2- || echo 'lobechat')
    [ -z "$PG_DB" ] && PG_DB="lobechat"
    docker compose exec -T postgresql pg_dump -U "$PG_USER" "$PG_DB" 2>/dev/null | gzip > "$PRE_BACKUP" || true
    chmod 600 "$PRE_BACKUP" 2>/dev/null || true
    echo "🛑 Stopping web app service during restore..."
    docker compose stop lobe
    echo "📥 Importing database..."
    gzip -dc "$RESTORE_FILE" | docker compose exec -T postgresql psql -U "$PG_USER" -d "$PG_DB"
    echo "🚀 Restarting web service..."
    docker compose start lobe
    echo "✅ Database restored successfully!"
    ;;
  doctor)
    echo "🩺 Running LobeHub Diagnostics..."
    echo "----------------------------------------"
    echo "1. Container Status:"
    docker compose ps
    echo ""
    echo "2. Port Listeners:"
    L_PORT=$(grep '^LOBE_PORT=' .env 2>/dev/null | cut -d= -f2- || echo '3210')
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$L_PORT" -sTCP:LISTEN -n -P || echo "Port $L_PORT not listening"
    fi
    echo ""
    echo "3. Database Connectivity:"
    PG_USER=$(grep '^POSTGRES_USER=' .env 2>/dev/null | cut -d= -f2- || echo 'postgres')
    [ -z "$PG_USER" ] && PG_USER="postgres"
    if docker compose exec -T postgresql pg_isready -U "$PG_USER" 2>/dev/null; then
      echo "✅ PostgreSQL is accepting connections"
    else
      echo "❌ PostgreSQL is not ready"
    fi
    echo ""
    echo "4. S3 Storage Check:"
    S3_EP=$(grep '^S3_ENDPOINT=' .env 2>/dev/null | cut -d= -f2- || echo '')
    if [ -n "$S3_EP" ]; then
      if curl -skf --max-time 5 "$S3_EP" >/dev/null 2>&1 || curl -skf --max-time 5 "$S3_EP/health" >/dev/null 2>&1 || curl -skf --max-time 5 "$S3_EP/minio/health/live" >/dev/null 2>&1; then
        echo "✅ S3 endpoint reachable ($S3_EP)"
      else
        echo "⚠️  S3 endpoint check warning ($S3_EP)"
      fi
    fi
    echo ""
    echo "5. Disk Space:"
    df -h . | awk 'NR==1 || NR==2'
    echo ""
    echo "Doctor check finished."
    ;;
  search-test)
    echo "🔍 Testing SearXNG..."
    QUERY="${2:-test}"
    RESULT=$(docker exec lobe-searxng wget -qO- "http://localhost:8080/search?q=${QUERY}" 2>/dev/null)
    if echo "$RESULT" | grep -qi "<html"; then
      echo "✅ SearXNG OK! Search working."
      echo "Query: $QUERY"
    else
      echo "❌ SearXNG not responding. Check logs: ./lobe.sh logs searxng"
    fi
    ;;
  uninstall)
    echo "⚠️  Uninstall LobeHub"
    echo "Choose uninstall mode:"
    echo "  1) Stop and remove containers and networks (KEEP data volumes)"
    echo "  2) FULL PURGE: Remove containers, networks, data volumes, and installation files"
    echo "  3) Cancel"
    read -r -p "Select [1-3]: " uopt
    case "$uopt" in
      1)
        docker compose down
        echo "✅ Containers removed. Data preserved in ./data."
        ;;
      2)
        read -r -p "Are you ABSOLUTELY sure? All conversations, uploads, and database records will be DELETED forever! (type 'yes'): " uconfirm
        if [[ "$uconfirm" == "yes" ]]; then
          docker compose down -v --remove-orphans
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
    echo "⚠️  This will DELETE ALL data (database, uploads, secrets)..."
    read -r -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" == "yes" ]]; then
      docker compose down -v
      rm -rf ./data
      echo "✅ All data deleted!"
    else
      echo "❌ Cancelled."
    fi
    ;;
  secrets)
    echo "📁 Secrets file: $(pwd)/.env"
    cat .env
    ;;
  s3-login)
    echo "S3 Storage Credentials:"
    grep -E "^(RUSTFS_|S3_)(ACCESS_KEY|SECRET_KEY)=" .env | head -4 | sed 's/=/: /'
    echo ""
    echo "Console: http://localhost:9001"
    ;;
  s3-test)
    echo "🧪 Testing S3 endpoint for browser uploads..."
    APP=$(grep '^APP_URL=' .env 2>/dev/null | cut -d= -f2- || true)
    S3=$(grep '^S3_ENDPOINT=' .env 2>/dev/null | cut -d= -f2- || true)
    SVC=$(grep '^S3_SERVICE=' .env 2>/dev/null | cut -d= -f2- || echo 'rustfs')
    echo "APP_URL: $APP"
    echo "S3_ENDPOINT: $S3"
    if [[ "$APP" =~ ^https:// && "$S3" =~ ^http:// ]]; then
      echo "❌ Mixed content: HTTPS app cannot upload to HTTP S3 endpoint."
      exit 1
    fi
    if [[ "$SVC" == "minio" ]]; then
      PATH_CHECK="/minio/health/live"
    else
      PATH_CHECK="/health"
    fi
    if curl -skf --max-time 8 "${S3}${PATH_CHECK}" >/dev/null 2>&1; then
      echo "✅ S3 endpoint reachable: ${S3}${PATH_CHECK}"
    else
      echo "❌ S3 endpoint not reachable: ${S3}${PATH_CHECK}"
      echo "   Check reverse proxy/TLS for your S3 domain."
      exit 1
    fi
    ORIGIN=$(echo "$APP" | sed 's#/$##')
    CORS=$(curl -skI -X OPTIONS "${S3}/" \
      -H "Origin: ${ORIGIN}" \
      -H "Access-Control-Request-Method: PUT" \
      -H "Access-Control-Request-Headers: content-type" 2>/dev/null | tr -d '\r')
    CORS_ORIGIN=$(echo "$CORS" | sed -n 's/^Access-Control-Allow-Origin: //Ip' | head -n 1)
    if [[ "$CORS_ORIGIN" == "*" || "$CORS_ORIGIN" == "$ORIGIN" ]]; then
      echo "✅ S3 CORS preflight allows origin: ${ORIGIN}"
    else
      echo "❌ S3 CORS preflight does not allow origin: ${ORIGIN}"
      echo "   Check CORS config on S3 service/proxy."
      exit 1
    fi
    ;;
  *)
    echo "LobeHub Helper v4.0"
    echo ""
    echo "Usage: ./lobe.sh {command}"
    echo "       ./lobehub.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start        - Start all services"
    echo "  stop         - Stop all services"
    echo "  restart      - Restart all services"
    echo "  upgrade      - Pull latest images & restart (alias: update)"
    echo "  logs [svc]   - View logs (default: lobe)"
    echo "  status       - Show service status"
    echo "  backup       - Backup PostgreSQL database and .env"
    echo "  restore      - Restore PostgreSQL database from backup"
    echo "  doctor       - Run diagnostic checks"
    echo "  search-test  - Test SearXNG search"
    echo "  s3-test      - Test S3 upload endpoint reachability"
    echo "  secrets      - Show secrets file"
    echo "  s3-login     - Show S3 storage credentials"
    echo "  uninstall    - Uninstall containers (keep data or full purge)"
    echo "  reset        - ⚠️  Stop and DELETE all data"
    echo ""
    echo "Services: lobe, postgresql, redis, searxng, ${S3_SERVICE:-rustfs}"
    ;;
esac
