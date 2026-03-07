#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP_SCRIPT="$REPO_ROOT/prometheus/setup.sh"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This smoke test is intended for Linux / Raspberry Pi hosts."
    exit 1
fi

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
with socket.socket() as s:
    s.bind(('127.0.0.1', 0))
    print(s.getsockname()[1])
PY
}

PORT=${PROMETHEUS_SMOKE_PORT:-$(find_free_port)}
TIMEOUT=${PROMETHEUS_SMOKE_TIMEOUT:-240}
REAL_HOME=$HOME
REAL_DOCKER_CONFIG=${DOCKER_CONFIG:-$REAL_HOME/.docker}
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/prometheus-smoke-home.XXXXXX")
INSTALL_DIR="$TEST_HOME/self-hosted/prometheus"

cleanup() {
    if [[ -d "$INSTALL_DIR" ]]; then
        (
            cd "$INSTALL_DIR"
            if [[ -x ./prometheus.sh ]]; then
                printf 'yes\n' | ./prometheus.sh reset >/dev/null 2>&1 || true
            fi
        )
    fi
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

echo "[smoke] temp HOME: $TEST_HOME"
echo "[smoke] port: $PORT"

printf '1\n1\n%s\n' "$PORT" | env HOME="$TEST_HOME" DOCKER_CONFIG="$REAL_DOCKER_CONFIG" bash "$SETUP_SCRIPT"

cd "$INSTALL_DIR"
./prometheus.sh health >/dev/null
./prometheus.sh config-check >/dev/null

STATUS_OUTPUT=$(./prometheus.sh status)
echo "$STATUS_OUTPUT"
echo "$STATUS_OUTPUT" | grep -q 'prometheus-node-exporter' || {
    echo "node-exporter container not found in status output"
    exit 1
}

ELAPSED=0
NODE_UP_OK=false
while [[ "$ELAPSED" -lt "$TIMEOUT" ]]; do
    RESPONSE=$(curl -fsS --get "http://localhost:${PORT}/api/v1/query" --data-urlencode 'query=max(up{job="node"})' 2>/dev/null || true)
    if [[ -n "$RESPONSE" ]] && printf '%s' "$RESPONSE" | python3 - <<'PY'
import json
import sys
payload = json.load(sys.stdin)
if payload.get('status') != 'success':
    raise SystemExit(1)
result = payload.get('data', {}).get('result', [])
if not result:
    raise SystemExit(1)
value = float(result[0]['value'][1])
if value < 1:
    raise SystemExit(1)
PY
    then
        NODE_UP_OK=true
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [[ "$NODE_UP_OK" != "true" ]]; then
    echo "Timed out waiting for Prometheus to scrape node-exporter successfully"
    exit 1
fi

echo "[smoke] node-exporter scrape verified"
