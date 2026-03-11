#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP_SCRIPT="$REPO_ROOT/supabase/setup.sh"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to run the smoke test."
    exit 1
fi

if ! docker info >/dev/null 2>&1 && (! command -v sudo >/dev/null 2>&1 || ! sudo docker info >/dev/null 2>&1); then
    echo "Docker daemon is not accessible."
    exit 1
fi

find_free_port() {
    python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

HTTP_PORT=${SUPABASE_SMOKE_HTTP_PORT:-$(find_free_port)}
HTTPS_PORT=${SUPABASE_SMOKE_HTTPS_PORT:-$(find_free_port)}
DB_PORT=${SUPABASE_SMOKE_DB_PORT:-$(find_free_port)}
POOLER_PORT=${SUPABASE_SMOKE_POOLER_PORT:-$(find_free_port)}
REAL_HOME=$HOME
REAL_DOCKER_CONFIG=${DOCKER_CONFIG:-$REAL_HOME/.docker}
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/supabase-smoke-home.XXXXXX")
INSTALL_DIR="$TEST_HOME/self-hosted/supabase"

cleanup() {
    if [[ -d "$INSTALL_DIR" ]]; then
        (
            cd "$INSTALL_DIR"
            if [[ -x ./supa.sh ]]; then
                printf 'yes\n' | ./supa.sh reset >/dev/null 2>&1 || true
            fi
        )
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

echo "[smoke] temp HOME: $TEST_HOME"
echo "[smoke] HTTP port: $HTTP_PORT"
echo "[smoke] HTTPS port: $HTTPS_PORT"
echo "[smoke] DB port: $DB_PORT"
echo "[smoke] Pooler port: $POOLER_PORT"

printf '1\n1\n%s\n%s\n%s\n%s\n' \
    "$HTTP_PORT" \
    "$HTTPS_PORT" \
    "$DB_PORT" \
    "$POOLER_PORT" | env HOME="$TEST_HOME" DOCKER_CONFIG="$REAL_DOCKER_CONFIG" bash "$SETUP_SCRIPT"

cd "$INSTALL_DIR"
./supa.sh health >/dev/null

STATUS_OUTPUT=$(./supa.sh status)
echo "$STATUS_OUTPUT"
echo "$STATUS_OUTPUT" | grep -q 'supabase-kong' || {
    echo "supabase-kong container missing from status output"
    exit 1
}
echo "$STATUS_OUTPUT" | grep -q 'supabase-pooler' || {
    echo "supabase-pooler container missing from status output"
    exit 1
}

ROOT_CODE=$(curl -ksS -o /dev/null -w '%{http_code}' -u "$(grep '^DASHBOARD_USERNAME=' .env | cut -d= -f2):$(grep '^DASHBOARD_PASSWORD=' .env | cut -d= -f2)" "http://localhost:${HTTP_PORT}/")
if [[ "$ROOT_CODE" != "200" && "$ROOT_CODE" != "301" && "$ROOT_CODE" != "302" && "$ROOT_CODE" != "307" && "$ROOT_CODE" != "308" ]]; then
    echo "Dashboard did not respond as expected. HTTP $ROOT_CODE"
    exit 1
fi

curl -ksSf "http://localhost:${HTTP_PORT}/auth/v1/settings" \
    -H "apikey: $(grep '^ANON_KEY=' .env | cut -d= -f2-)" \
    -H "Authorization: Bearer $(grep '^ANON_KEY=' .env | cut -d= -f2-)" >/dev/null
curl -ksSf "http://localhost:${HTTP_PORT}/storage/v1/status" >/dev/null
curl -ksSf "http://localhost:${HTTP_PORT}/functions/v1/hello" \
    -H "apikey: $(grep '^ANON_KEY=' .env | cut -d= -f2-)" \
    -H "Authorization: Bearer $(grep '^ANON_KEY=' .env | cut -d= -f2-)" | grep -q 'Hello from Edge Functions'

echo "[smoke] Supabase installer smoke test passed"
