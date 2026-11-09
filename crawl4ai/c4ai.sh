#!/bin/bash

# ============================================
# c4ai.sh - Crawl4AI Management Helper
# Created by vnROM.net
# ============================================
# Usage: ./c4ai.sh [command]
#   start    - Start Crawl4AI
#   stop     - Stop Crawl4AI
#   restart  - Restart Crawl4AI
#   status   - Show container status
#   logs     - Follow container logs
#   update   - Pull latest image and restart
#   test     - Run quick health/feature test
#   info     - Show all endpoints and MCP tools
#   shell    - Open shell in container

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PORT=$(grep -E "^C4AI_PORT=" .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-11235}
BASE_URL="http://localhost:${PORT}"

case "${1:-help}" in
    start)
        echo -e "${GREEN}Starting Crawl4AI...${NC}"
        docker compose up -d
        echo -e "${GREEN}✓ Started. Dashboard: ${BASE_URL}/dashboard${NC}"
        ;;

    stop)
        echo -e "${YELLOW}Stopping Crawl4AI...${NC}"
        docker compose down
        echo -e "${GREEN}✓ Stopped${NC}"
        ;;

    restart)
        echo -e "${YELLOW}Restarting Crawl4AI...${NC}"
        docker compose restart
        echo -e "${GREEN}✓ Restarted${NC}"
        ;;

    status)
        echo -e "${BOLD}Container Status:${NC}"
        docker compose ps
        echo ""
        # Health check
        if curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ API: Healthy${NC}"
        else
            echo -e "${RED}✗ API: Not responding${NC}"
        fi
        ;;

    logs)
        docker compose logs -f --tail=100
        ;;

    update)
        echo -e "${YELLOW}Updating Crawl4AI...${NC}"
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}✓ Updated to latest version${NC}"
        ;;

    test)
        echo -e "${BOLD}🧪 Running Crawl4AI Tests...${NC}"
        echo ""
        PASS=0
        FAIL=0

        # Health check
        echo -n "  Health Check... "
        if curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Dashboard
        echo -n "  Dashboard... "
        if curl -sf "${BASE_URL}/dashboard" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Playground
        echo -n "  Playground... "
        if curl -sf "${BASE_URL}/playground" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # MCP Schema
        echo -n "  MCP Schema... "
        MCP_RESULT=$(curl -sf "${BASE_URL}/mcp/schema" 2>/dev/null)
        if [ -n "$MCP_RESULT" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        # Metrics
        echo -n "  Prometheus Metrics... "
        if curl -sf "${BASE_URL}/metrics" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${YELLOW}~ SKIP (may not be enabled)${NC}"
        fi

        # Test crawl
        echo -n "  Test Crawl (example.com)... "
        CRAWL_RESULT=$(curl -sf -X POST "${BASE_URL}/crawl" \
            -H "Content-Type: application/json" \
            -d '{"urls":["https://example.com"],"priority":10}' 2>/dev/null)
        if [ -n "$CRAWL_RESULT" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi

        echo ""
        echo -e "  ${BOLD}Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
        ;;

    info)
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🕷️  Crawl4AI Endpoints${NC}                         ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}API:${NC}         ${BASE_URL}                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Dashboard:${NC}   ${BASE_URL}/dashboard         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Playground:${NC}  ${BASE_URL}/playground        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Health:${NC}      ${BASE_URL}/health            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}Metrics:${NC}     ${BASE_URL}/metrics           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}MCP Endpoints:${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🔌 SSE${NC}          ${BASE_URL}/mcp/sse          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}📡 Streamable${NC}   ${BASE_URL}/mcp/streamable   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}🌐 WebSocket${NC}    ws://localhost:${PORT}/mcp/ws      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}📋 Schema${NC}       ${BASE_URL}/mcp/schema       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}MCP Tools (7):${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   md, html, screenshot, pdf,                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   execute_js, crawl, ask                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}REST API:${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /crawl      - Crawl URLs                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   GET  /task/{id}   - Get task result            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /html       - Extract HTML               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /screenshot  - Capture screenshot        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /pdf        - Generate PDF               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}   POST /execute_js  - Run JavaScript            ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}AI Agent Integration:${NC}"
        echo -e "  ${GREEN}Claude Desktop/Code:${NC}"
        echo "    claude mcp add --transport sse c4ai ${BASE_URL}/mcp/sse"
        echo -e "  ${GREEN}LobeHub (Streamable HTTP):${NC}"
        echo "    URL: ${BASE_URL}/mcp/streamable"
        echo -e "  ${GREEN}Antigravity / OpenClaw:${NC}"
        echo "    SSE: ${BASE_URL}/mcp/sse"
        ;;

    shell)
        echo -e "${YELLOW}Opening shell in Crawl4AI container...${NC}"
        docker compose exec crawl4ai /bin/bash || docker compose exec crawl4ai /bin/sh
        ;;

    backup)
        BACKUP_DIR="./backups"
        mkdir -p -m 700 "$BACKUP_DIR"
        TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
        ARCHIVE="$BACKUP_DIR/crawl4ai_backup_$TIMESTAMP.tar.gz"
        echo -e "${GREEN}Creating Crawl4AI configuration and state backup...${NC}"
        tar -czf "$ARCHIVE" .env .llm.env config.yml docker-compose.yml 2>/dev/null || true
        chmod 600 "$ARCHIVE"
        echo -e "${GREEN}✓ Backup created: $ARCHIVE (chmod 600)${NC}"
        ;;

    restore)
        shift || true
        FILE="${1:-}"
        if [[ -z "$FILE" || ! -f "$FILE" ]]; then
            echo -e "${RED}Usage: ./c4ai.sh restore <path-to-tar-gz-archive>${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Verifying archive integrity...${NC}"
        gzip -t "$FILE"
        echo -e "${YELLOW}WARNING: This will overwrite existing configurations with archive contents!${NC}"
        read -rp "Type 'yes' to proceed: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            tar -xzf "$FILE"
            chmod 600 .env .llm.env 2>/dev/null || true
            echo -e "${GREEN}✓ Restore completed! Restarting stack...${NC}"
            docker compose restart
        else
            echo "Restore aborted."
        fi
        ;;

    doctor)
        echo -e "${BOLD}=== Crawl4AI Diagnostic Doctor ===${NC}"
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
        echo "File permissions:"
        for f in .env .llm.env; do
            if [[ -f "$f" ]]; then
                P=$(stat -c "%a" "$f" 2>/dev/null || stat -f "%Lp" "$f" 2>/dev/null || echo "unknown")
                echo "  $f: $P (recommended: 600)"
            else
                echo "  $f: not found"
            fi
        done
        echo -n "Port ${PORT} status: "
        if command -v lsof &>/dev/null && lsof -i ":${PORT}" -sTCP:LISTEN -Pn &>/dev/null; then
            echo -e "${GREEN}Listening${NC}"
        else
            echo -e "${YELLOW}Not listening${NC}"
        fi
        echo -n "Health endpoint (${BASE_URL}/health): "
        if curl -sf "${BASE_URL}/health" >/dev/null 2>&1; then
            echo -e "${GREEN}Healthy${NC}"
        else
            echo -e "${RED}Not responding${NC}"
        fi
        ;;

    uninstall)
        echo -e "${RED}WARNING: This will stop and remove all Crawl4AI containers and networks.${NC}"
        read -rp "Type 'yes' to confirm: " CONFIRM
        if [[ "$CONFIRM" == "yes" ]]; then
            docker compose down -v
            echo -e "${GREEN}✓ Crawl4AI containers and volumes removed.${NC}"
        else
            echo "Uninstall aborted."
        fi
        ;;

    help|*)
        echo -e "${BOLD}Usage:${NC} ./c4ai.sh [command]"
        echo ""
        echo -e "  ${GREEN}start${NC}      Start Crawl4AI"
        echo -e "  ${GREEN}stop${NC}       Stop Crawl4AI"
        echo -e "  ${GREEN}restart${NC}    Restart Crawl4AI"
        echo -e "  ${GREEN}status${NC}     Show container status + health"
        echo -e "  ${GREEN}logs${NC}       Follow container logs"
        echo -e "  ${GREEN}update${NC}     Pull latest image and restart"
        echo -e "  ${GREEN}test${NC}       Run quick health checks"
        echo -e "  ${GREEN}info${NC}       Show all endpoints and MCP tools"
        echo -e "  ${GREEN}shell${NC}      Open shell in container"
        echo -e "  ${GREEN}backup${NC}     Archive configs to ./backups/"
        echo -e "  ${GREEN}restore${NC}    Restore configs from archive"
        echo -e "  ${GREEN}doctor${NC}     Diagnostic system check"
        echo -e "  ${GREEN}uninstall${NC}  Remove containers and volumes"
        ;;
esac
