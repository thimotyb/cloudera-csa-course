#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLINK_SQL_REST_PORT="${FLINK_SQL_REST_PORT:-18082}"
READINESS_TIMEOUT_SEC="${READINESS_TIMEOUT_SEC:-120}"
READINESS_INTERVAL_SEC="${READINESS_INTERVAL_SEC:-2}"
SKIP_BUILD="${SKIP_BUILD:-false}"

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

wait_rest_ready() {
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

COMPOSE="$(compose_cmd)"
cd "$PROJECT_DIR"

if [[ "$SKIP_BUILD" != "true" ]]; then
  $COMPOSE build sql-client datagen mysql
fi

$COMPOSE up -d --remove-orphans

if ! $COMPOSE ps kafka | grep -q "Up"; then
  echo "[ERR] Kafka is not running" >&2
  echo "      Check logs: $COMPOSE logs kafka" >&2
  exit 1
fi

REST_ENDPOINT="http://127.0.0.1:${FLINK_SQL_REST_PORT}/overview"
if wait_rest_ready "$REST_ENDPOINT"; then
  echo "[OK] Flink SQL standalone ready: http://127.0.0.1:${FLINK_SQL_REST_PORT}"
else
  echo "[ERR] Flink SQL REST not ready on ${REST_ENDPOINT}" >&2
  echo "      Check logs: $COMPOSE logs jobmanager taskmanager" >&2
  exit 1
fi

echo "[INFO] Open SQL Client with:"
echo "       $COMPOSE exec sql-client /opt/sql-client/sql-client.sh"
