#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <topic> [max_messages] [timeout_ms]" >&2
  echo "Esempio: $0 user_behavior_tumbling_out 20 15000" >&2
  exit 1
fi

TOPIC="$1"
MAX_MESSAGES="${2:-20}"
TIMEOUT_MS="${3:-15000}"

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

echo "[info] Consumo topic '$TOPIC' (max: $MAX_MESSAGES)..."
"${COMPOSE_CMD[@]}" -f "$ROOT_DIR/docker-compose.yml" exec -T kafka \
  kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic "$TOPIC" \
  --from-beginning \
  --timeout-ms "$TIMEOUT_MS" \
  --max-messages "$MAX_MESSAGES"
