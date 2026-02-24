#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOVE_VOLUMES="${REMOVE_VOLUMES:-false}"

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "[ERR] Docker Compose not found (docker compose / docker-compose)" >&2
    exit 1
  fi
}

COMPOSE="$(compose_cmd)"
cd "$PROJECT_DIR"

if [[ "$REMOVE_VOLUMES" == "true" ]]; then
  $COMPOSE down -v --remove-orphans
else
  $COMPOSE down --remove-orphans
fi
