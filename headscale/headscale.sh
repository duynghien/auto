#!/usr/bin/env bash
# headscale.sh - Headscale Management Helper (Gen 4 Standard)
# Usage: ./headscale.sh [command]

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CMD="${1:-help}"

case "$CMD" in
    start)
        echo -e "${GREEN}Starting Headscale...${NC}"
        docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}Stopping Headscale...${NC}"
        docker compose stop
        ;;
    restart)
        echo -e "${YELLOW}Restarting Headscale...${NC}"
        docker compose restart
        ;;
    upgrade|update)
        echo -e "${YELLOW}Backing up .env & configs...${NC}"
        mkdir -p -m 700 backups
        cp -r config "backups/config.pre-update.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        echo -e "${YELLOW}Pulling latest images...${NC}"
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}✓ Update complete!${NC}"
        ;;
    logs)
        shift || true
        svc="${1:-headscale}"
        docker compose logs -f "$svc"
        ;;
    status)
        echo -e "${CYAN}=== Headscale Container Status ===${NC}"
        docker compose ps
        echo ""
        echo "Health check:"
        if curl -sf "http://localhost:8080/health" >/dev/null 2>&1 || curl -sf "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
            echo -e "  [OK] Headscale API health: ${GREEN}Healthy${NC}"
        else
            echo -e "  [WARN] Headscale API health: ${YELLOW}Not ready${NC}"
        fi
        ;;
    users)
        docker compose exec headscale headscale users list
        ;;
    nodes)
        docker compose exec headscale headscale nodes list
        ;;
    apikey)
        echo -e "${GREEN}Creating API Key for UI access (expires in 90 days)...${NC}"
        docker compose exec headscale headscale apikeys create --expiration 90d
        ;;
    cmd)
        shift || true
        docker compose exec headscale headscale "$@"
        ;;
    backup)
        BACKUP_DIR="./backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/headscale_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Archiving Headscale configuration, keys, and SQLite database...${NC}"
        tar -czf "$ARCHIVE" config/ .env docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;
    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./headscale.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${YELLOW}Taking pre-restore safety snapshot...${NC}"
        mkdir -p -m 700 backups
        tar -czf "backups/config-pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz" config/ 2>/dev/null || true
        
        echo -e "${RED}WARNING: This will overwrite current Headscale configuration and nodes database!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            echo "Stopping headscale container..."
            docker compose stop headscale 2>/dev/null || true
            tar -xzf "$FILE"
            echo "Restarting stack..."
            docker compose up -d
            echo -e "${GREEN}✓ Restore completed successfully!${NC}"
        else
            echo "Restore aborted."
        fi
        ;;
    doctor)
        echo -e "${BOLD}=== Headscale Diagnostic Doctor ===${NC}"
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
        echo "Configuration files:"
        for f in .env config/config.yaml config/db.sqlite; do
            if [[ -f "$f" ]]; then
                P=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%Lp" "$f" 2>/dev/null || echo "unknown")
                echo "  $f: $P"
            else
                echo "  $f: not found"
            fi
        done
        echo "Port bindings (8080, 9090):"
        for p in 8080 9090; do
            if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
                echo "  [BOUND] Port $p is listening"
            else
                echo "  [OPEN/UNKNOWN] Port $p"
            fi
        done
        ;;
    uninstall)
        echo -e "${RED}WARNING: This will stop Headscale and remove all containers and data volumes.${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ Headscale containers and volumes removed.${NC}"
        else
            echo "Uninstall cancelled."
        fi
        ;;
    help|*)
        echo -e "${BOLD}Headscale Management Helper (Gen 4 Standard)${NC}"
        echo ""
        echo "Usage: ./headscale.sh [command]"
        echo ""
        echo "Service Commands:"
        echo "  start      - Start all services"
        echo "  stop       - Stop all services"
        echo "  restart    - Restart all services"
        echo "  update     - Pull latest images & restart"
        echo "  logs [svc] - View logs"
        echo "  status     - Show container status + health"
        echo ""
        echo "Headscale Commands:"
        echo "  users      - List all Headscale users"
        echo "  nodes      - List all registered nodes"
        echo "  apikey     - Generate API key for Web UI"
        echo "  cmd ...    - Run arbitrary headscale CLI command"
        echo ""
        echo "Maintenance Commands:"
        echo "  backup     - Archive SQLite database and config to ./backups/"
        echo "  restore <f>- Restore database and config from archive"
        echo "  doctor     - Run diagnostic health check"
        echo "  uninstall  - Remove containers and volumes"
        ;;
esac
