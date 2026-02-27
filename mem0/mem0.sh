#!/bin/bash
# mem0.sh — Mem0 OpenMemory management helper
# Stack: Qdrant + Neo4j + FastAPI + Next.js UI

INSTALL_DIR="$HOME/self-hosted/mem0"
COMPOSE_DIR="$INSTALL_DIR/openmemory-source/openmemory"
export UI_PORT=$(cat "$INSTALL_DIR/.ui_port" 2>/dev/null || echo "3000")

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -d "$COMPOSE_DIR" ]; then
    echo -e "${YELLOW}OpenMemory not found at $COMPOSE_DIR${NC}"
    echo "Run setup.sh first."
    exit 1
fi

cd "$COMPOSE_DIR"

# Load env vars from api/.env
export API_KEY=$(grep '^API_KEY=' "$COMPOSE_DIR/api/.env" 2>/dev/null | cut -d= -f2- || echo "")
export OPENAI_API_KEY=$(grep '^OPENAI_API_KEY=' "$COMPOSE_DIR/api/.env" 2>/dev/null | cut -d= -f2- || echo "")
export NEO4J_PASSWORD=$(grep '^NEO4J_PASSWORD=' "$COMPOSE_DIR/api/.env" 2>/dev/null | cut -d= -f2- || echo "mem0_neo4j_pass")
export NEXT_PUBLIC_API_URL="http://localhost:8765"
export NEXT_PUBLIC_USER_ID="${USER}"

case "${1:-help}" in
    start)
        echo -e "${GREEN}▶ Starting Mem0...${NC}"
        docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}■ Stopping Mem0...${NC}"
        docker compose down
        ;;
    restart)
        echo -e "${YELLOW}↻ Restarting Mem0...${NC}"
        docker compose down
        docker compose up -d
        ;;
    purge)
        echo -e "${RED}⚠ This will REMOVE all containers AND volumes (memories, graph data, config)${NC}"
        read -rp "  Are you sure? (y/N): " CONFIRM || true
        if [[ "${CONFIRM:-n}" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}  Purging all data...${NC}"
            docker compose down -v
            echo -e "${GREEN}  ✓ All containers and volumes removed${NC}"
            echo "  Run setup.sh to reinstall."
        else
            echo "  Cancelled."
        fi
        ;;
    logs)
        SERVICE="${2:-}"
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

        echo -n "  API:      "
        curl -sf http://localhost:8765/docs > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  Qdrant:   "
        curl -sf http://localhost:6333/healthz > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  Neo4j:    "
        curl -sf http://localhost:7474 > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  UI:       "
        curl -sf "http://localhost:${UI_PORT}" > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo ""
        echo -n "  API_KEY:         "
        if docker exec openmemory-openmemory-mcp-1 printenv API_KEY 2>/dev/null | grep -q '.'; then
            echo -e "${GREEN}configured${NC}"
        else
            echo -e "${RED}NOT SET${NC}"
        fi
        echo -n "  qdrant-client:   "
        if docker exec openmemory-openmemory-mcp-1 python -c "import qdrant_client" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        echo -n "  neo4j-driver:    "
        if docker exec openmemory-openmemory-mcp-1 python -c "import neo4j" 2>/dev/null; then
            echo -e "${GREEN}available${NC}"
        else
            echo -e "${YELLOW}not installed${NC}"
        fi
        ;;
    test)
        echo -e "${CYAN}=== Smoke Test ===${NC}"
        echo "  Adding memory..."
        RESULT=$(curl -sf -X POST http://localhost:8765/api/v1/memories/ \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"${USER}\", \"text\": \"My name is OpenClaw test user. I like AI and use Claude.\"}" 2>&1)
        if [ $? -eq 0 ] && ! echo "$RESULT" | grep -q '"error"'; then
            echo -e "  ${GREEN}✓ Memory added successfully${NC}"
            echo "  $RESULT" | head -5
        else
            echo -e "  ${YELLOW}✗ Failed to add memory${NC}"
            echo "  Response: $RESULT" | head -5
            echo ""
            echo -e "  ${CYAN}Debugging tips:${NC}"
            echo "  1. Check API_KEY: docker exec openmemory-openmemory-mcp-1 printenv API_KEY"
            echo "  2. Check logs: ./mem0.sh logs openmemory-mcp"
            echo "  3. Verify qdrant: curl http://localhost:6333/healthz"
            echo "  4. Verify neo4j: curl http://localhost:7474"
        fi
        ;;
    update)
        echo -e "${CYAN}=== Updating Mem0 ===${NC}"
        cd "$INSTALL_DIR"
        git -C openmemory-source pull
        cd "$COMPOSE_DIR"
        docker compose up -d --build
        # Re-install dependencies after rebuild
        echo "  Waiting for API container..."
        sleep 15
        docker exec openmemory-openmemory-mcp-1 pip install "qdrant-client>=1.9.1" "neo4j>=5.0.0" --quiet 2>/dev/null || true
        docker compose restart openmemory-mcp 2>/dev/null || true
        echo -e "${GREEN}✓ Updated!${NC}"
        ;;
    *)
        echo "Mem0 OpenMemory Manager"
        echo "Stack: Qdrant + Neo4j + FastAPI + Next.js UI"
        echo ""
        echo "Usage: $0 {start|stop|restart|purge|logs|status|test|update}"
        echo ""
        echo "  start   — Start all containers"
        echo "  stop    — Stop all containers"
        echo "  restart — Restart all containers"
        echo "  purge   — Remove all containers AND volumes (⚠️ deletes all data)"
        echo "  logs    — View live logs (optional: logs <service>)"
        echo "  status  — Check service health"
        echo "  test    — Run smoke test (add memory)"
        echo "  update  — Pull latest & rebuild"
        ;;
esac
