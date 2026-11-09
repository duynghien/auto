#!/usr/bin/env bash
# fc.sh - FireCrawl management helper (Gen 4 Standard)
# Usage: ./fc.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PORT=$(grep -E "^PORT=" .env 2>/dev/null | cut -d= -f2 || echo "3002")
CMD="${1:-help}"

case "$CMD" in
  start)
    echo -e "${GREEN}Starting FireCrawl...${NC}"
    docker compose up -d
    ;;
  stop)
    echo -e "${YELLOW}Stopping FireCrawl...${NC}"
    docker compose stop
    ;;
  restart)
    echo -e "${YELLOW}Restarting FireCrawl...${NC}"
    docker compose restart
    ;;
  logs)
    shift || true
    docker compose logs -f "${@:-api}"
    ;;
  status)
    echo -e "${CYAN}FireCrawl Container Status:${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}Health Diagnostics:${NC}"
    echo -n "  • FireCrawl API: "
    if curl -sf "http://localhost:${PORT}/v1/health" >/dev/null 2>&1; then
      echo -e "${GREEN}Healthy (OK)${NC}"
    else
      echo -e "${RED}Not responding${NC}"
    fi
    echo -n "  • Redis: "
    if docker exec "$(docker compose ps -q redis 2>/dev/null | head -1)" redis-cli ping &>/dev/null; then
      echo -e "${GREEN}Healthy (PONG)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    echo -n "  • PostgreSQL (nuq): "
    if docker exec "$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)" psql -U postgres -d postgres -c 'SELECT 1' &>/dev/null; then
      echo -e "${GREEN}Ready (OK)${NC}"
    else
      echo -e "${YELLOW}Not ready${NC}"
    fi
    ;;
  test)
    echo -e "${CYAN}Testing FireCrawl scrape...${NC}"
    curl -X POST "http://localhost:${PORT}/v1/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url": "https://example.com", "formats": ["markdown"]}' | head -n 30
    ;;
  update)
    echo -e "${YELLOW}Backing up .env...${NC}"
    mkdir -p -m 700 backups
    cp .env "backups/.env.pre-update.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Updating FireCrawl source & rebuilding...${NC}"
    if [ -d "firecrawl-source" ]; then
      git -C firecrawl-source pull || true
    fi
    docker compose pull redis rabbitmq 2>/dev/null || true
    docker compose up -d --build
    echo -e "${GREEN}Update complete!${NC}"
    ;;
  backup)
    BACKUP_DIR="./backups"
    mkdir -p -m 700 "$BACKUP_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    DB_ARCHIVE="$BACKUP_DIR/firecrawl_db_$TIMESTAMP.sql.gz"
    CFG_ARCHIVE="$BACKUP_DIR/firecrawl_cfg_$TIMESTAMP.tar.gz"

    echo -e "${GREEN}Dumping nuq-postgres database...${NC}"
    PG_CONTAINER="$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)"
    if [[ -n "$PG_CONTAINER" ]] && docker exec "$PG_CONTAINER" pg_dump -U postgres postgres | gzip > "$DB_ARCHIVE"; then
      chmod 600 "$DB_ARCHIVE"
      echo -e "  ${GREEN}✓ Database archived to: $DB_ARCHIVE (chmod 600)${NC}"
    else
      echo -e "  ${RED}✗ Database backup failed! Ensure nuq-postgres is running.${NC}"
    fi

    echo -e "${GREEN}Archiving configuration...${NC}"
    tar -czf "$CFG_ARCHIVE" .env docker-compose.yml 2>/dev/null || true
    chmod 600 "$CFG_ARCHIVE"
    echo -e "  ${GREEN}✓ Configuration archived to: $CFG_ARCHIVE (chmod 600)${NC}"
    ;;
  restore)
    shift || true
    FILE="${1:-}"
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo -e "${RED}Usage: ./fc.sh restore <path-to-sql-gz-archive>${NC}"
      exit 1
    fi
    echo -e "${YELLOW}Verifying archive integrity...${NC}"
    gzip -t "$FILE"
    echo -e "${RED}WARNING: Restoring will overwrite existing nuq-postgres database!${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      PG_CONTAINER="$(docker compose ps -q nuq-postgres 2>/dev/null | head -1)"
      gunzip -c "$FILE" | docker exec -i "$PG_CONTAINER" psql -U postgres -d postgres
      echo -e "${GREEN}✓ Database restore completed! Restarting API...${NC}"
      docker compose restart api
    else
      echo "Restore aborted."
    fi
    ;;
  doctor)
    echo -e "${BOLD}=== FireCrawl System Doctor ===${NC}"
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
    echo "Disk space:"
    df -h . | awk 'NR==2 {print "  Available: " $4 " of " $2}'
    echo "Checking .env permissions:"
    if [[ -f .env ]]; then
      PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || echo "unknown")
      echo "  .env: $PERMS (recommended: 600)"
    else
      echo "  [FAIL] .env not found"
    fi
    echo -n "Port ${PORT} status: "
    if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
      echo -e "${GREEN}Listening${NC}"
    else
      echo -e "${YELLOW}Not listening${NC}"
    fi
    echo -n "API /v1/health endpoint: "
    if curl -sf "http://localhost:${PORT}/v1/health" >/dev/null 2>&1; then
      echo -e "${GREEN}Healthy${NC}"
    else
      echo -e "${RED}Not responding${NC}"
    fi
    ;;
  uninstall)
    echo -e "${RED}WARNING: This will completely remove FireCrawl containers, networks, and volumes.${NC}"
    read -rp "Type 'yes' to proceed: " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
      docker compose down -v
      echo -e "${GREEN}✓ FireCrawl containers and volumes removed.${NC}"
    else
      echo "Uninstall canceled."
    fi
    ;;
  help|*)
    echo -e "${BOLD}Usage:${NC} ./fc.sh {start|stop|restart|logs|status|test|update|backup|restore|doctor|uninstall}"
    echo ""
    echo "  start      — Start all containers"
    echo "  stop       — Stop all containers"
    echo "  restart    — Restart all containers"
    echo "  logs [svc] — Follow container logs (default: api)"
    echo "  status     — Show container status + health diagnostics"
    echo "  test       — Run test scrape against example.com"
    echo "  update     — Pull source and rebuild containers"
    echo "  backup     — Dump PostgreSQL and archive configuration"
    echo "  restore    — Restore database from backup archive"
    echo "  doctor     — Run system health diagnostics"
    echo "  uninstall  — Remove containers and data volumes"
    ;;
esac
