#!/usr/bin/env bash
# mautic.sh - Mautic Management Helper (Gen 4 Standard)
# Usage: ./mautic.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

get_env_val() {
    local key="$1"
    local default_val="${2:-}"
    if [ -f .env ]; then
        grep -E "^${key}=" .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "$default_val"
    else
        echo "$default_val"
    fi
}

PORT=$(get_env_val "MAUTIC_PORT" "8080")
DB_USER=$(get_env_val "MAUTIC_DB_USER" "mautic")
DB_NAME=$(get_env_val "MAUTIC_DB_NAME" "mautic")
DB_PASS=$(get_env_val "MAUTIC_DB_PASSWORD" "")

CMD="${1:-help}"

case "$CMD" in
  start)
    echo -e "${GREEN}Starting Mautic stack...${NC}"
    docker compose up -d
    ;;
  stop)
    echo -e "${YELLOW}Stopping Mautic stack...${NC}"
    docker compose stop
    ;;
  restart)
    echo -e "${YELLOW}Restarting Mautic stack...${NC}"
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-mautic_web}"
    ;;
  status)
    echo -e "${CYAN}=== Mautic Container Status ===${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}=== Health Diagnostics ===${NC}"
    echo -n "  • Web interface (port ${PORT}): "
    if curl -sf "http://localhost:${PORT}" >/dev/null 2>&1; then
      echo -e "${GREEN}Responding (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready or starting${NC}"
    fi
    echo -n "  • MariaDB database: "
    if docker compose exec -T mautic_db mariadb-admin ping -u root -p"${DB_PASS}" --silent &>/dev/null || docker compose exec -T mautic_db mysqladmin ping --silent &>/dev/null; then
      echo -e "${GREEN}Ready (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    echo -n "  • Redis Cache: "
    if docker compose exec -T mautic_redis redis-cli ping &>/dev/null; then
      echo -e "${GREEN}Ready (PONG)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/mautic_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/mautic_cfg_$TIMESTAMP.tar.gz"
    
    echo -e "${GREEN}Dumping MariaDB database...${NC}"
    if MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb-dump -u"$DB_USER" "$DB_NAME" | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo -e "  ${GREEN}✓ Database dump: $DB_ARCHIVE (chmod 600)${NC}"
    else
      echo -e "  ${RED}✗ Database backup failed!${NC}"
    fi

    echo -e "${GREEN}Archiving configurations...${NC}"
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml ofelia_config.ini 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo -e "  ${GREEN}✓ Configurations: $CFG_ARCHIVE (chmod 600)${NC}"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo -e "${RED}Usage: ./mautic.sh restore <path-to-sql-gz-archive>${NC}"
      exit 1
    fi
    echo -e "${YELLOW}Verifying archive integrity...${NC}"
    gzip -t "$FILE"
    echo -e "${YELLOW}Taking pre-restore safety dump...${NC}"
    mkdir -p -m 700 backups
    PRE_RESTORE="backups/db-pre-restore-$(date +%Y%m%d_%H%M%S).sql.gz"
    MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb-dump -u"$DB_USER" "$DB_NAME" | gzip > "$PRE_RESTORE" 2>/dev/null || true
    chmod 600 "$PRE_RESTORE" 2>/dev/null || true
    
    echo -e "${RED}WARNING: Restoring will overwrite existing Mautic database!${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      echo "Stopping web and worker containers..."
      docker compose stop mautic_web mautic_worker mautic_cron 2>/dev/null || true
      echo "Importing database..."
      gzip -dc "$FILE" | MYSQL_PWD="$DB_PASS" docker compose exec -e MYSQL_PWD -T mautic_db mariadb -u"$DB_USER" "$DB_NAME"
      echo "Restarting stack..."
      docker compose up -d
      echo -e "${GREEN}✓ Mautic database restore completed successfully!${NC}"
    else
      echo "Restore aborted."
    fi
    ;;
  update)
    echo -e "${YELLOW}Backing up .env...${NC}"
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Pulling latest images...${NC}"
    docker compose pull
    docker compose up -d --remove-orphans
    echo -e "${GREEN}✓ Update complete!${NC}"
    ;;
  doctor)
    echo -e "${BOLD}=== Mautic Diagnostic Doctor ===${NC}"
    echo -n "Checking Docker... "
    if docker --version >/dev/null 2>&1; then
      echo -e "${GREEN}✓ OK${NC}"
    else
      echo -e "${RED}✗ Docker not found${NC}"
    fi
    echo -n "Checking Docker Compose... "
    if docker compose version >/dev/null 2>&1; then
      echo -e "${GREEN}✓ OK${NC}"
    else
      echo -e "${RED}✗ Docker Compose not found${NC}"
    fi
    echo "Disk Space:"
    df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo -n "Web port ${PORT} status: "
    if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
      echo -e "${GREEN}Listening${NC}"
    else
      echo -e "${YELLOW}Not listening${NC}"
    fi
    ;;
  uninstall)
    echo -e "${RED}WARNING: This will completely destroy Mautic containers and data volumes.${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo -e "${GREEN}✓ Containers and volumes removed.${NC}"
    else
      echo "Uninstall canceled."
    fi
    ;;
  help|*)
    echo -e "${BOLD}Mautic Management Helper (Gen 4 Standard)${NC}"
    echo ""
    echo "Usage: ./mautic.sh {start|stop|restart|logs|status|backup|restore|doctor|update|uninstall}"
    echo ""
    echo "  start       — Start all containers"
    echo "  stop        — Stop all containers"
    echo "  restart     — Restart all containers"
    echo "  logs [svc]  — View live logs (default: mautic_web)"
    echo "  status      — Container status + health diagnostics"
    echo "  backup      — Dump MariaDB database & configs to ./backups/"
    echo "  restore <f> — Verify and restore database from archive"
    echo "  doctor      — Check system health and permissions"
    echo "  update      — Pull latest images and restart"
    echo "  uninstall   — Stop and remove containers and volumes"
    ;;
esac
