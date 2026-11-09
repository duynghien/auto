#!/bin/bash
# Twenty CRM Helper Script v1.0

set -euo pipefail

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  echo -e "\n\033[0;31m✖ [ERROR] Command failed at line ${line_no} (exit code: ${exit_code}).\033[0m" >&2
  if [[ -f "docker-compose.yml" ]]; then
    echo -e "  \033[1;33m→ Check container logs:\033[0m docker compose logs --tail=50" >&2
  fi
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

cd "$(dirname "$0")"

DOCKER_COMPOSE_CMD="docker compose"
if command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
fi

CMD="${1:-}"
case "$CMD" in
  start)
    $DOCKER_COMPOSE_CMD up -d
    ;;
  stop)
    $DOCKER_COMPOSE_CMD stop
    ;;
  restart)
    $DOCKER_COMPOSE_CMD restart
    ;;
  logs)
    $DOCKER_COMPOSE_CMD logs -f "${2:-server}"
    ;;
  status)
    $DOCKER_COMPOSE_CMD ps
    ;;
  update)
    $DOCKER_COMPOSE_CMD pull
    $DOCKER_COMPOSE_CMD up -d
    ;;
  health)
    APP_PORT="$(grep -Eo '"[0-9]+:3000"' docker-compose.yml | head -n1 | sed -E 's/"([0-9]+):3000"/\1/' || true)"
    APP_PORT="${APP_PORT:-3020}"
    curl -sf "http://localhost:${APP_PORT}/healthz" >/dev/null && \
      echo "Twenty CRM health: OK (http://localhost:${APP_PORT}/healthz)" || \
      echo "Twenty CRM health: NOT READY"
    ;;
  *)
    echo "Twenty CRM Helper v1.0"
    echo ""
    echo "Usage: ./twenty.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start     - Start all services"
    echo "  stop      - Stop all services"
    echo "  restart   - Restart all services"
    echo "  logs      - View logs (default: server)"
    echo "  status    - Show service status"
    echo "  update    - Pull latest images & restart"
    echo "  health    - Check /healthz endpoint"
    exit 1
    ;;
esac
