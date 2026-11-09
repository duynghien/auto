#!/usr/bin/env bash
# mem0.sh — Mem0 OpenMemory management helper (Gen 4 Standard)
# Stack: Qdrant + Neo4j + FastAPI + Next.js UI
# Usage: ./mem0.sh [command]

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
if command -v getent &>/dev/null; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi
TARGET_HOME="${TARGET_HOME:-$HOME}"
INSTALL_DIR="${INSTALL_DIR:-$TARGET_HOME/self-hosted/mem0}"
COMPOSE_DIR="$INSTALL_DIR/openmemory-source/openmemory"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -d "$COMPOSE_DIR" ]; then
    echo -e "${YELLOW}OpenMemory directory not found at $COMPOSE_DIR${NC}"
    echo "Please run setup.sh first."
    exit 1
fi

cd "$COMPOSE_DIR"

# Export environment variables for docker compose interpolation
set -a
[ -f "$INSTALL_DIR/.env" ] && source "$INSTALL_DIR/.env"
set +a

export API_KEY="${API_KEY:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export NEO4J_PASSWORD="${NEO4J_PASSWORD:-mem0_neo4j_pass}"
export NEXT_PUBLIC_API_URL="http://localhost:8765"
export NEXT_PUBLIC_USER_ID="${TARGET_USER}"
UI_PORT="${UI_PORT:-3000}"

CMD="${1:-help}"

case "$CMD" in
    start)
        echo -e "${GREEN}▶ Starting Mem0 stack...${NC}"
        docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}■ Stopping Mem0 stack...${NC}"
        docker compose stop
        ;;
    restart)
        echo -e "${YELLOW}↻ Restarting Mem0 stack...${NC}"
        docker compose restart
        ;;
    logs)
        shift || true
        SERVICE="${1:-}"
        if [ -n "$SERVICE" ]; then
            docker compose logs -f --tail=50 "$SERVICE"
        else
            docker compose logs -f --tail=50
        fi
        ;;
    status)
        echo -e "${CYAN}=== Mem0 Container Status ===${NC}"
        docker compose ps
        echo ""
        echo -e "${CYAN}=== Service Health Diagnostics ===${NC}"
        echo -n "  • Mem0 API (port 8765):       "
        curl -sf http://localhost:8765/docs > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • Qdrant Vector DB (port 6333): "
        curl -sf http://localhost:6333/healthz > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • Neo4j Graph DB (port 7474):   "
        curl -sf http://localhost:7474 > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  • OpenMemory UI (port ${UI_PORT}): "
        curl -sf "http://localhost:${UI_PORT}" > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo ""
        echo -n "  • API_KEY in container:       "
        if docker exec openmemory-openmemory-mcp-1 printenv API_KEY 2>/dev/null | grep -q '.'; then
            echo -e "${GREEN}configured${NC}"
        else
            echo -e "${RED}NOT SET${NC}"
        fi
        echo -n "  • qdrant-client package:      "
        if docker exec openmemory-openmemory-mcp-1 python -c "import qdrant_client" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        echo -n "  • neo4j driver package:       "
        if docker exec openmemory-openmemory-mcp-1 python -c "import neo4j" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        ;;
    test)
        echo -e "${CYAN}=== Smoke Test (Add Memory) ===${NC}"
        echo "  Adding memory..."
        RESULT=$(curl -sf -X POST http://localhost:8765/api/v1/memories/ \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"${TARGET_USER}\", \"text\": \"My name is OpenClaw test user. I like AI and self-hosted tools.\"}" 2>&1 || true)
        if [ -n "$RESULT" ] && ! echo "$RESULT" | grep -q '"error"'; then
            echo -e "  ${GREEN}✓ Memory added successfully${NC}"
            echo "  $RESULT" | head -n 5
        else
            echo -e "  ${YELLOW}✗ Failed to add memory${NC}"
            echo "  Response: $RESULT" | head -n 5
        fi
        ;;
    update)
        echo -e "${CYAN}=== Updating Mem0 ===${NC}"
        cd "$INSTALL_DIR"
        git -C openmemory-source pull || true
        cd "$COMPOSE_DIR"
        docker compose up -d --build
        echo "  Waiting for API container..."
        sleep 15
        docker exec openmemory-openmemory-mcp-1 pip install "qdrant-client>=1.9.1" "neo4j>=5.0.0" --quiet 2>/dev/null || true
        docker compose restart openmemory-mcp 2>/dev/null || true
        echo -e "${GREEN}✓ Update complete!${NC}"
        ;;
    backup)
        BACKUP_DIR="$INSTALL_DIR/backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/mem0_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Archiving Mem0 configurations and environment...${NC}"
        tar -czf "$ARCHIVE" -C "$INSTALL_DIR" .env -C "$COMPOSE_DIR" docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;
    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./mem0.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${RED}WARNING: This will overwrite existing configurations!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            tar -xzf "$FILE" -C "$INSTALL_DIR"
            chmod 600 "$INSTALL_DIR/.env" 2>/dev/null || true
            echo -e "${GREEN}✓ Configurations restored. Restarting stack...${NC}"
            docker compose restart
        else
            echo "Restore aborted."
        fi
        ;;
    doctor)
        echo -e "${BOLD}=== Mem0 System Doctor ===${NC}"
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
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            PERMS=$(stat -c "%a" "$INSTALL_DIR/.env" 2>/dev/null || stat -f "%Lp" "$INSTALL_DIR/.env" 2>/dev/null || echo "unknown")
            echo "  $INSTALL_DIR/.env: $PERMS (recommended: 600)"
        else
            echo "  [FAIL] .env not found"
        fi
        echo "Port Bindings:"
        for p in 8765 6333 7474 7687 "$UI_PORT"; do
            if command -v lsof &>/dev/null && lsof -i ":$p" -sTCP:LISTEN -Pn &>/dev/null; then
                echo "  [BOUND] Port $p is listening"
            else
                echo "  [OPEN/UNKNOWN] Port $p"
            fi
        done
        ;;
    purge|uninstall)
        echo -e "${RED}WARNING: This will REMOVE all Mem0 containers, volumes, memories, and graph data!${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ All containers and volumes removed.${NC}"
        else
            echo "Uninstall cancelled."
        fi
        ;;
    help|*)
        echo "Mem0 OpenMemory Management CLI (Gen 4 Standard)"
        echo "Stack: Qdrant + Neo4j + FastAPI + Next.js UI"
        echo ""
        echo "Usage: ./mem0.sh {start|stop|restart|logs|status|test|update|backup|restore|doctor|uninstall}"
        echo ""
        echo "  start      — Start all containers"
        echo "  stop       — Stop all containers"
        echo "  restart    — Restart all containers"
        echo "  logs [svc] — View live logs"
        echo "  status     — Check service health & dependencies"
        echo "  test       — Run smoke test (add memory)"
        echo "  update     — Pull latest source & rebuild"
        echo "  backup     — Archive configurations to ./backups/"
        echo "  restore    — Restore configurations from archive"
        echo "  doctor     — Run system health diagnostics"
        echo "  uninstall  — Remove all containers and volumes"
        ;;
esac
