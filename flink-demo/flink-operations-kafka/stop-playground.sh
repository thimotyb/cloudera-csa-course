#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOVE_VOLUMES="${REMOVE_VOLUMES:-false}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERR] Missing required command: $1" >&2
    exit 1
  fi
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi
  echo "[ERR] Docker Compose not found (docker compose / docker-compose)" >&2
  exit 1
}

require_cmd docker
COMPOSE="$(compose_cmd)"

cd "$SCRIPT_DIR"

if [[ "$REMOVE_VOLUMES" == "true" ]]; then
  $COMPOSE down -v --remove-orphans
else
  $COMPOSE down --remove-orphans
fi
