#!/bin/bash
# ==============================================================================
# Postiz Auto-Setup Script (v3.0)
# ==============================================================================
# Supported OS: Ubuntu 22.04+, macOS (Apple Silicon/Intel)
# Author: duynghien
# ==============================================================================

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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
echo "            Postiz Auto Setup v3.0"
echo "            Creating the ultimate content machine..."
echo ""
echo -e "================================================================${NC}"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}\n${BLUE} $1 ${NC}\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"; }

# ── Compatibility Check ──────────────────────────────────────────────────────
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS_TYPE" == "Darwin" ]]; then
    INSTALL_DIR="$HOME/self-hosted/postiz"
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        error "Docker Desktop is not running. Please start it and try again."
    fi
elif [[ "$OS_TYPE" == "Linux" ]]; then
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root on Linux (use sudo)."
    fi
    INSTALL_DIR="$HOME/self-hosted/postiz"
    DOCKER_CMD="docker"
else
    error "Unsupported OS: $OS_TYPE"
fi

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    log "Architecture: $ARCH (ARM64) - Compatible."
elif [[ "$ARCH" == "x86_64" ]]; then
    log "Architecture: $ARCH (AMD64) - Compatible."
else
    warn "Architecture $ARCH might not be fully supported. Proceeding anyway..."
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ── User Input ───────────────────────────────────────────────────────────────
step "1/5 — Configuration"

echo -e "${YELLOW}Enter the domain where Postiz will be accessible.${NC}"
echo -e "A public domain with HTTPS is required for social media OAuth callbacks."
echo -e "Examples: ${CYAN}postiz.example.com${NC}, ${CYAN}post.vnrom.net${NC}"
echo -e "(Use ${CYAN}localhost${NC} for local development/testing only)"
echo ""
read -p "Domain: " DOMAIN_NAME

if [[ -z "$DOMAIN_NAME" ]]; then
    error "Domain is required. Example: postiz.example.com"
fi

# Determine protocol
if [[ "$DOMAIN_NAME" == "localhost" || "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PROTOCOL="http"
    warn "Using http:// — Social media integrations will NOT work without a public HTTPS domain."
    warn "You can update MAIN_URL in .env later when you have a domain."
else
    PROTOCOL="https"
fi

MAIN_URL="${PROTOCOL}://${DOMAIN_NAME}"
log "MAIN_URL: $MAIN_URL"

# ── Temporal Dynamic Config ──────────────────────────────────────────────────
step "2/5 — Creating Temporal Configuration"

mkdir -p dynamicconfig
cat > dynamicconfig/development-sql.yaml <<'DYNEOF'
system.forceSearchAttributesCacheRefreshOnRead:
  - value: true
    constraints: {}
limit.maxIDLength:
  - value: 255
    constraints: {}
DYNEOF

log "Temporal dynamic config created."

# ── Generate Secrets ─────────────────────────────────────────────────────────
step "3/5 — Generating Secrets"

generate_secret() { openssl rand -hex "$1"; }

JWT_SECRET=$(generate_secret 32)
POSTGRES_PASSWORD=$(generate_secret 16)

log "Secrets generated."

# ── Create Environment File ──────────────────────────────────────────────────
step "4/5 — Creating Docker Compose & Environment"

cat > .env <<EOF
# Postiz Configuration
# Generated: $(date)

# === Core ===
MAIN_URL=${MAIN_URL}
FRONTEND_URL=${MAIN_URL}
NEXT_PUBLIC_BACKEND_URL=${MAIN_URL}/api
BACKEND_INTERNAL_URL=http://localhost:3000

# === Database ===
DATABASE_URL=postgresql://postiz-user:${POSTGRES_PASSWORD}@postiz-postgres:5432/postiz-db-local
REDIS_URL=redis://postiz-redis:6379

# === Auth ===
JWT_SECRET=${JWT_SECRET}
IS_GENERAL=true
DISABLE_REGISTRATION=false

# === Storage (Local) ===
STORAGE_PROVIDER=local
UPLOAD_DIRECTORY=/uploads
NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads

# === Temporal ===
TEMPORAL_ADDRESS=temporal:7233

# === Social Media (Edit manually) ===
# X_API_KEY=
# X_API_SECRET=
# LINKEDIN_CLIENT_ID=
# LINKEDIN_CLIENT_SECRET=
# ... (Add others — see https://docs.postiz.com/platforms/introduction)

# === Developer / Misc ===
NX_ADD_PLUGINS=false
API_LIMIT=300
EOF

log ".env file created."

# ── Docker Compose ───────────────────────────────────────────────────────────

cat > docker-compose.yml <<EOF
services:
  # ── Postiz App ───────────────────────────────────────────────────────────
  postiz:
    image: ghcr.io/gitroomhq/postiz-app:latest
    container_name: postiz
    restart: always
    ports:
      - "5000:5000"
    env_file: .env
    environment:
      NODE_ENV: production
    volumes:
      - postiz-uploads:/uploads/
    networks:
      - postiz-network
      - temporal-network
    depends_on:
      postiz-postgres:
        condition: service_healthy
      postiz-redis:
        condition: service_healthy

  # ── Dependencies ─────────────────────────────────────────────────────────
  postiz-postgres:
    image: postgres:17-alpine
    container_name: postiz-postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: postiz-user
      POSTGRES_DB: postiz-db-local
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - postiz-network
    healthcheck:
      test: pg_isready -U postiz-user -d postiz-db-local
      interval: 10s
      timeout: 3s
      retries: 3

  postiz-redis:
    image: redis:7.2-alpine
    container_name: postiz-redis
    restart: always
    volumes:
      - redis-data:/data
    networks:
      - postiz-network
    healthcheck:
      test: redis-cli ping
      interval: 10s
      timeout: 3s
      retries: 3

  # ── Temporal Stack ───────────────────────────────────────────────────────
  temporal:
    container_name: temporal
    image: temporalio/auto-setup:1.28.1
    ports:
      - "7233:7233"
    environment:
      - DB=postgres12
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=temporal
      - POSTGRES_SEEDS=temporal-postgresql
      - DYNAMIC_CONFIG_FILE_PATH=config/dynamicconfig/development-sql.yaml
      - ENABLE_ES=true
      - ES_SEEDS=temporal-elasticsearch
      - ES_VERSION=v7
    volumes:
      - ./dynamicconfig:/etc/temporal/config/dynamicconfig
    networks:
      - temporal-network
    depends_on:
      - temporal-postgresql
      - temporal-elasticsearch

  temporal-postgresql:
    container_name: temporal-postgresql
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: temporal
      POSTGRES_USER: temporal
    volumes:
      - temporal-postgres-data:/var/lib/postgresql/data
    networks:
      - temporal-network

  temporal-elasticsearch:
    container_name: temporal-elasticsearch
    image: elasticsearch:7.17.27
    environment:
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms256m -Xmx256m
      - xpack.security.enabled=false
    volumes:
      - temporal-es-data:/usr/share/elasticsearch/data
    networks:
      - temporal-network

  temporal-ui:
    container_name: temporal-ui
    image: temporalio/ui:2.34.0
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=http://localhost:3000
    ports:
      - "8080:8080"
    networks:
      - temporal-network

networks:
  postiz-network:
  temporal-network:

volumes:
  postgres-data:
  redis-data:
  postiz-uploads:
  temporal-postgres-data:
  temporal-es-data:
EOF

log "Docker Compose configuration created."

# ── Start ────────────────────────────────────────────────────────────────────
step "5/5 — Starting Services"

log "Cleaning up any previous installation..."
$DOCKER_CMD compose down -v 2>/dev/null || true

$DOCKER_CMD compose up -d

# ── Helper Script ────────────────────────────────────────────────────────────
cat > postiz.sh <<HELPER
#!/bin/bash
# Postiz Helper Script v3.0

cd "\$(dirname "\$0")"

CMD=\$1
case "\$CMD" in
  start) docker compose up -d ;;
  stop) docker compose stop ;;
  restart) docker compose restart ;;
  logs) docker compose logs -f "\${2:-postiz}" ;;
  status) docker compose ps ;;
  update)
    docker compose pull
    docker compose up -d
    ;;
  *)
    echo "Postiz Helper v3.0"
    echo ""
    echo "Usage: ./postiz.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start    - Start all services"
    echo "  stop     - Stop all services"
    echo "  restart  - Restart all services"
    echo "  logs     - View logs (default: postiz)"
    echo "  status   - Show service status"
    echo "  update   - Pull latest images & restart"
    exit 1
    ;;
esac
HELPER
chmod +x postiz.sh

# ── Summary ──────────────────────────────────────────────────────────────────
success "Postiz installation complete!"
echo -e "\n${BLUE}Access:${NC}"
echo -e "  Postiz App:   http://localhost:5000 (direct)"
if [[ "$PROTOCOL" == "https" ]]; then
    echo -e "  Public URL:   ${MAIN_URL} (after reverse proxy setup)"
fi
echo -e "  Temporal UI:  http://localhost:8080"

echo -e "\n${BLUE}Management:${NC}"
echo -e "  Dir:          ${INSTALL_DIR}"
echo -e "  Helper:       ./postiz.sh status"

echo -e "\n${YELLOW}Next Steps:${NC}"
if [[ "$PROTOCOL" == "https" ]]; then
    echo -e "  1. Set up a reverse proxy (Caddy/Nginx/Cloudflare Tunnel) to proxy ${MAIN_URL} → localhost:5000"
    echo -e "  2. Open ${MAIN_URL} to create your admin account."
else
    echo -e "  1. Open http://localhost:5000 to create your admin account."
fi
echo -e "  2. Edit .env to add Social Media API keys."
echo -e "  3. See README for reverse proxy setup guides."
echo "================================================================================"
