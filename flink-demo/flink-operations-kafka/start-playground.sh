#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLINK_REST_PORT="${FLINK_REST_PORT:-18081}"
READINESS_TIMEOUT_SEC="${READINESS_TIMEOUT_SEC:-90}"
READINESS_INTERVAL_SEC="${READINESS_INTERVAL_SEC:-2}"
SKIP_BUILD="${SKIP_BUILD:-false}"

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

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

wait_rest_readiness() {
  local endpoint="$1"
  local deadline=$((SECONDS + READINESS_TIMEOUT_SEC))

  while (( SECONDS < deadline )); do
    if curl -fsS "$endpoint" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$READINESS_INTERVAL_SEC"
  done
  return 1
}

require_cmd docker
require_cmd curl

COMPOSE="$(compose_cmd)"

cd "$SCRIPT_DIR"

log "Using compose command: $COMPOSE"
log "Flink dashboard host port: $FLINK_REST_PORT"

if [[ "$SKIP_BUILD" != "true" ]]; then
  log "Building operations playground image"
  $COMPOSE build
else
  log "SKIP_BUILD=true, skipping image build"
fi

log "Starting containers"
$COMPOSE up -d --remove-orphans

log "Current container status"
$COMPOSE ps

REST_ENDPOINT="http://127.0.0.1:${FLINK_REST_PORT}/overview"
log "Waiting for Flink REST readiness on $REST_ENDPOINT (timeout ${READINESS_TIMEOUT_SEC}s)"
if wait_rest_readiness "$REST_ENDPOINT"; then
  log "Flink REST is ready"
  log "Dashboard: http://127.0.0.1:${FLINK_REST_PORT}"
else
  echo "[ERR] Flink REST is not ready yet on $REST_ENDPOINT" >&2
  echo "      Inspect logs with: $COMPOSE logs jobmanager taskmanager" >&2
  exit 1
fi
