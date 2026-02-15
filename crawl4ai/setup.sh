#!/bin/bash

# ============================================
# Crawl4AI Setup for macOS (Apple Silicon + OrbStack)
# Created by vnROM.net
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Banner
echo ""
echo "================================================================"
echo -e "${PURPLE}"
echo "      _                         _     _             "
echo "     | |                       | |   (_)            "
echo "   __| |_   _ _   _ ____   ____| |__  _ _____ ____  "
echo "  / _  | | | | | | |  _ \ / _  |  _ \| | ___ |  _ \ "
echo " ( (_| | |_| | |_| | | | ( (_| | | | | | ____| | | |"
echo "  \____|____/ \__  |_| |_|\___ |_| |_|_|_____)_| |_|"
echo "             (____/      (_____|                    "
echo ""
echo "              Crawl4AI Full-Stack Setup"
echo "              LLM-Friendly Web Crawler"
echo "              Optimized for macOS + OrbStack"
echo ""
echo -e "================================================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ──────────────────────────────────────────────
# 1. Check Prerequisites
# ──────────────────────────────────────────────
echo -e "${BOLD}[1/5] Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed.${NC}"
    echo ""
    echo "  Recommended: Install OrbStack (fast Docker for Mac)"
    echo "  → https://orbstack.dev/"
    echo ""
    echo "  Or install Docker Desktop:"
    echo "  → https://docs.docker.com/desktop/install/mac-install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not available.${NC}"
    echo "  Please update Docker or install Docker Compose plugin."
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Check Docker running
if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running.${NC}"
    echo "  Please start OrbStack or Docker Desktop first."
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Check architecture
ARCH=$(uname -m)
echo -e "${GREEN}✓ Architecture: ${ARCH}${NC}"

# ──────────────────────────────────────────────
# 2. Setup Mode Selection
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[2/5] Select setup mode:${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} ${BOLD}Pull Image${NC} (Recommended)"
echo -e "     Pre-built official image from Docker Hub (~2GB)"
echo -e "     Includes ALL features: Crawling, LLM Extraction, MCP,"
echo -e "     Screenshots, PDF, Deep Crawl, Webhooks, Dashboard"
echo ""
echo -e "  ${YELLOW}2)${NC} ${BOLD}Build from Source${NC}"
echo -e "     Clone repo + build Docker image locally"
echo -e "     Use this if you need to customize the Dockerfile"
echo ""

read -p "Choose [1/2] (default: 1): " SETUP_MODE
SETUP_MODE=${SETUP_MODE:-1}

# ──────────────────────────────────────────────
# 3. Configuration Files
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[3/5] Configuring environment...${NC}"

# Create .env if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env from template${NC}"
else
    echo -e "${GREEN}✓ .env already exists${NC}"
fi

if [ ! -f .llm.env ]; then
    cp .llm.env.example .llm.env
    echo -e "${GREEN}✓ Created .llm.env from template${NC}"
    echo ""
    echo -e "${YELLOW}Optional: Add your LLM API keys for AI-powered extraction.${NC}"
    echo -e "You can skip this and add keys later by editing ${BOLD}.llm.env${NC}"
    echo ""

    read -p "Enter OpenAI API key (or press Enter to skip): " OPENAI_KEY
    if [ -n "$OPENAI_KEY" ]; then
        sed -i '' "s/^OPENAI_API_KEY=.*/OPENAI_API_KEY=${OPENAI_KEY}/" .llm.env
        echo -e "${GREEN}✓ OpenAI API key saved${NC}"
    fi

    read -p "Enter Anthropic API key (or press Enter to skip): " ANTHROPIC_KEY
    if [ -n "$ANTHROPIC_KEY" ]; then
        sed -i '' "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=${ANTHROPIC_KEY}/" .llm.env
        echo -e "${GREEN}✓ Anthropic API key saved${NC}"
    fi

    read -p "Enter DeepSeek API key (or press Enter to skip): " DEEPSEEK_KEY
    if [ -n "$DEEPSEEK_KEY" ]; then
        sed -i '' "s/^DEEPSEEK_API_KEY=.*/DEEPSEEK_API_KEY=${DEEPSEEK_KEY}/" .llm.env
        echo -e "${GREEN}✓ DeepSeek API key saved${NC}"
    fi
else
    echo -e "${GREEN}✓ .llm.env already exists${NC}"
fi

# ──────────────────────────────────────────────
# 4. Deploy
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[4/5] Deploying Crawl4AI...${NC}"

if [ "$SETUP_MODE" = "2" ]; then
    # Build from source
    echo -e "${YELLOW}Build from Source: Cloning repo and building Docker image...${NC}"
    echo -e "${YELLOW}This may take 10-20 minutes on first build.${NC}"

    # Clone source if needed
    if [ ! -d "crawl4ai-source" ]; then
        echo "Cloning Crawl4AI source code..."
        git clone https://github.com/unclecode/crawl4ai.git crawl4ai-source
    else
        echo -e "${GREEN}✓ Source code already exists. Pulling latest...${NC}"
        git -C crawl4ai-source pull || true
    fi

    # Build with default install type (stable, avoids upstream model_loader bug with INSTALL_TYPE=all)
    # The pre-built image already includes all features; local build is for customization
    INSTALL_TYPE=default docker compose up -d --build
else
    # Quick mode - use pre-built image (includes all features)
    echo -e "${GREEN}Pulling official pre-built image (all features included)...${NC}"
    docker compose pull
    docker compose up -d
fi

# ──────────────────────────────────────────────
# 5. Health Check & Summary
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[5/5] Waiting for Crawl4AI to start...${NC}"

# Wait for health
MAX_WAIT=90
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf http://localhost:11235/health > /dev/null 2>&1; then
        break
    fi
    sleep 3
    WAITED=$((WAITED + 3))
    echo -ne "\r  Waiting... (${WAITED}s/${MAX_WAIT}s)"
done
echo ""

if curl -sf http://localhost:11235/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Crawl4AI is running!${NC}"
else
    echo -e "${YELLOW}⚠ Crawl4AI is still starting up. Check logs with:${NC}"
    echo "  docker compose logs -f crawl4ai"
fi

# Summary
PORT=$(grep -E "^C4AI_PORT=" .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-11235}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}${BOLD}✅ Setup Complete!${NC}                              ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🌐 API${NC}         http://localhost:${PORT}           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}📊 Dashboard${NC}   http://localhost:${PORT}/dashboard    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🎮 Playground${NC}  http://localhost:${PORT}/playground   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}💚 Health${NC}      http://localhost:${PORT}/health       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}� Metrics${NC}     http://localhost:${PORT}/metrics      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}MCP Endpoints (for AI Agents):${NC}                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🔌 SSE${NC}         /mcp/sse (Claude Desktop, etc.)  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}📡 Streamable${NC}  /mcp/streamable (LobeHub, etc.)  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}🌐 WebSocket${NC}   /mcp/ws                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}📋 Schema${NC}      /mcp/schema                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}MCP Tools (7):${NC} md, html, screenshot, pdf,      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}               execute_js, crawl, ask             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Manage:${NC} ./c4ai.sh [start|stop|logs|test]     ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}AI Agent Integration:${NC}"
echo -e "  ${GREEN}Claude Desktop/Code:${NC}"
echo "    claude mcp add --transport sse c4ai http://localhost:${PORT}/mcp/sse"
echo -e "  ${GREEN}LobeHub (Streamable HTTP):${NC}"
echo "    URL: http://localhost:${PORT}/mcp/streamable"
echo -e "  ${GREEN}Antigravity / OpenClaw:${NC}"
echo "    SSE: http://localhost:${PORT}/mcp/sse"
echo ""
