#!/bin/bash
# fc.sh - FireCrawl management helper
# Usage: ./fc.sh [start|stop|restart|logs|status|test|update]

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PORT=$(grep -E "^PORT=" .env 2>/dev/null | cut -d= -f2 || echo "3002")

case "$1" in
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
    docker compose logs -f api
    ;;
  status)
    echo -e "${CYAN}FireCrawl Container Status:${NC}"
    docker compose ps
    echo ""
    echo -e "${CYAN}Health check:${NC}"
    curl -sf "http://localhost:${PORT}/v1/health" && echo -e " ${GREEN}OK${NC}" || echo " Not ready"
    ;;
  test)
    echo -e "${CYAN}Testing FireCrawl scrape...${NC}"
    curl -X POST "http://localhost:${PORT}/v1/scrape" \
      -H "Content-Type: application/json" \
      -d '{"url": "https://example.com", "formats": ["markdown"]}' | head -200
    ;;
  update)
    echo -e "${YELLOW}Updating FireCrawl...${NC}"
    git -C firecrawl-source pull
    docker compose up -d --build
    echo -e "${GREEN}Update complete!${NC}"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|logs|status|test|update}"
    echo ""
    echo "  start    — Start all containers"
    echo "  stop     — Stop all containers"
    echo "  restart  — Restart all containers"
    echo "  logs     — Follow API logs"
    echo "  status   — Show container status + health"
    echo "  test     — Run a test scrape against example.com"
    echo "  update   — Pull latest source and rebuild"
    ;;
esac
