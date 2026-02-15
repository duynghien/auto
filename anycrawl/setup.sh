#!/bin/bash

# setup.sh - AnyCrawl Setup for macOS (Apple Silicon)
# Created by vnROM.net

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
PURPLE='\033[0;35m'

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
echo "               AnyCrawl Setup for macOS"
echo "               Optimized for M1/M2/M3 chips"
echo "
echo "================================================================${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo "Please install Docker Desktop for Mac: https://docs.docker.com/desktop/install/mac-install/"
    exit 1
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

# Clone AnyCrawl Source (Required for build)
if [ ! -d "anycrawl-source" ]; then
    echo -e "${YELLOW}Cloning AnyCrawl source code...${NC}"
    git clone https://github.com/any4ai/AnyCrawl.git anycrawl-source
else
    echo -e "${GREEN}✓ AnyCrawl source code already exists${NC}"
    # Optional: git -C anycrawl-source pull
fi

# Create permissions
echo "Creating directory structure..."
mkdir -p storage searxng
# Fix permissions for SearXNG
chmod 777 searxng

# Environment Setup
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    
    # Generate random keys
    API_KEY=$(openssl rand -hex 16)
    MINIO_ROOT_USER="admin"
    MINIO_ROOT_PASSWORD=$(openssl rand -hex 12)
    POSTGRES_PASSWORD=$(openssl rand -hex 12)

    cat <<EOF > .env
# --- General ---
NODE_ENV=production
ANYCRAWL_NAME=AnyCrawl
ANYCRAWL_DOMAIN=http://localhost:8880
ANYCRAWL_API_PORT=8880
ANYCRAWL_API_KEY=${API_KEY}
ANYCRAWL_API_AUTH_ENABLED=true

# --- Engine ---
ANYCRAWL_HEADLESS=true
ANYCRAWL_AVAILABLE_ENGINES=playwright,cheerio
ANYCRAWL_IGNORE_SSL_ERROR=true
# Apple Silicon Playwright specific overrides if needed (usually auto-detected)

# --- Database ---
POSTGRES_USER=anycrawl
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=anycrawl_db
ANYCRAWL_API_DB_TYPE=postgresql

# --- Redis ---
ANYCRAWL_REDIS_URL=redis://redis:6379

# --- MinIO (S3) ---
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
ANYCRAWL_S3_BUCKET=anycrawl-data
# Internal docker network endpoint
ANYCRAWL_S3_ENDPOINT=http://minio:9000

# --- Search ---
ANYCRAWL_SEARCH_DEFAULT_ENGINE=searxng
ANYCRAWL_SEARCH_ENABLED_ENGINES=searxng
ANYCRAWL_SEARXNG_URL=http://searxng:8080

# --- Advanced ---
ANYCRAWL_SCHEDULER_ENABLED=true
ANYCRAWL_WEBHOOKS_ENABLED=true
ANYCRAWL_MAX_CONCURRENCY=20

# --- AI (Optional) ---
# Connect the provider name and the model name with a "/", such as openai:gpt-4o-mini, custom/glm-4.5
DEFAULT_LLM_MODEL=
DEFAULT_EXTRACT_MODEL=
DEFAULT_EMBEDDING_MODEL=
OPENAI_API_KEY=
CUSTOM_BASE_URL=
CUSTOM_API_KEY=

# --- Credits & Performance ---
ANYCRAWL_EXTRACT_JSON_CREDITS=5
ANYCRAWL_PROXY_STEALTH_CREDITS=5
ANYCRAWL_TEMPLATE_EXECUTION_TIMEOUT=600000
ANYCRAWL_REQUEST_HANDLER_TIMEOUT_SECS=600
ANYCRAWL_AC_ENGINE_URL=
EOF
    echo -e "${GREEN}✓ .env created with secure random passwords${NC}"
    echo -e "API Key: ${YELLOW}${API_KEY}${NC}"
    echo -e "MinIO User: ${YELLOW}${MINIO_ROOT_USER}${NC}"
    echo -e "MinIO Password: ${YELLOW}${MINIO_ROOT_PASSWORD}${NC}"
else
    echo -e "${GREEN}✓ .env already exists${NC}"
fi

# Build and Start
echo -e "${YELLOW}Building and starting containers...${NC}"
docker compose up -d --build

# Migration (Wait for DB)
echo "Waiting for database to be ready..."
sleep 10
echo "Running database migrations..."
docker compose exec anycrawl sh -c "cd packages/db && npx drizzle-kit migrate" || echo -e "${YELLOW}Migration might have failed or already run. Check container logs.${NC}"

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "AnyCrawl API: http://localhost:8880"
echo -e "MinIO Console: http://localhost:9001 (User: ${MINIO_ROOT_USER} / Pass: ${MINIO_ROOT_PASSWORD})"
echo -e "SearXNG: http://localhost:8080"
echo -e "MCP Server: Running on port 8889 (Internal/SSE)"
