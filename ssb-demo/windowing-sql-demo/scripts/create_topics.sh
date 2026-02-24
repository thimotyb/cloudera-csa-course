#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Errore: docker compose/docker-compose non trovato." >&2
  exit 1
fi

TOPICS=(
  user_behavior_tumbling_out
  user_behavior_hopping_out
  user_behavior_cumulative_out
)

echo "[info] Creo topic Kafka della demo (idempotente)..."
for topic in "${TOPICS[@]}"; do
  "${COMPOSE_CMD[@]}" -f "$ROOT_DIR/docker-compose.yml" exec -T kafka \
    kafka-topics.sh --create --if-not-exists \
    --topic "$topic" \
    --bootstrap-server localhost:9092 \
    --partitions 1 \
    --replication-factor 1 >/dev/null
  echo "[ok] Topic pronto: $topic"
done

echo "[info] Topic correnti (filtro user_behavior_*):"
"${COMPOSE_CMD[@]}" -f "$ROOT_DIR/docker-compose.yml" exec -T kafka \
  kafka-topics.sh --list --bootstrap-server localhost:9092 | grep '^user_behavior_' || true
