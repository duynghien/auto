#!/bin/bash
# mem0.sh — Mem0 OpenMemory management helper

INSTALL_DIR="$HOME/self-hosted/mem0"
COMPOSE_DIR="$INSTALL_DIR/openmemory-source/openmemory"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -d "$COMPOSE_DIR" ]; then
    echo -e "${YELLOW}OpenMemory not found at $COMPOSE_DIR${NC}"
    echo "Run setup.sh first."
    exit 1
fi

cd "$COMPOSE_DIR"

case "${1:-help}" in
    start)
        echo -e "${GREEN}▶ Starting Mem0...${NC}"
        NEXT_PUBLIC_USER_ID="${USER}" NEXT_PUBLIC_API_URL="http://localhost:8765" \
            docker compose up -d
        ;;
    stop)
        echo -e "${YELLOW}■ Stopping Mem0...${NC}"
        docker compose down
        ;;
    restart)
        echo -e "${YELLOW}↻ Restarting Mem0...${NC}"
        docker compose down
        NEXT_PUBLIC_USER_ID="${USER}" NEXT_PUBLIC_API_URL="http://localhost:8765" \
            docker compose up -d
        ;;
    logs)
        docker compose logs -f --tail=50
        ;;
    status)
        echo -e "${CYAN}=== Mem0 Container Status ===${NC}"
        docker compose ps
        echo ""
        echo -n "  API:    "
        curl -sf http://localhost:8765/docs > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  Qdrant: "
        curl -sf http://localhost:6333/healthz > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        echo -n "  UI:     "
        curl -sf http://localhost:3000 > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}DOWN${NC}"
        ;;
    test)
        echo -e "${CYAN}=== Smoke Test ===${NC}"
        echo "  Adding memory..."
        RESULT=$(curl -sf -X POST http://localhost:8765/api/v1/memories/ \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"${USER}\", \"text\": \"My name is OpenClaw test user. I like AI.\"}" 2>&1)
        if [ $? -eq 0 ] && ! echo "$RESULT" | grep -q '"error"'; then
            echo -e "  ${GREEN}✓ Memory added successfully${NC}"
            echo "  $RESULT" | head -5
        else
            echo -e "  ${YELLOW}✗ Failed to add memory (or API error)${NC}"
            echo "  Server response: $RESULT" | head -5
        fi
        ;;
    update)
        echo -e "${CYAN}=== Updating Mem0 ===${NC}"
        cd "$INSTALL_DIR"
        git -C openmemory-source pull
        cd "$COMPOSE_DIR"
        NEXT_PUBLIC_USER_ID="${USER}" NEXT_PUBLIC_API_URL="http://localhost:8765" \
            docker compose up -d --build
        echo -e "${GREEN}✓ Updated!${NC}"
        ;;
    *)
        echo "Mem0 OpenMemory Manager"
        echo ""
        echo "Usage: $0 {start|stop|restart|logs|status|test|update}"
        echo ""
        echo "  start   — Start all containers"
        echo "  stop    — Stop all containers"
        echo "  restart — Restart all containers"
        echo "  logs    — View live logs"
        echo "  status  — Check service health"
        echo "  test    — Run smoke test (add memory)"
        echo "  update  — Pull latest & rebuild"
        ;;
esac
