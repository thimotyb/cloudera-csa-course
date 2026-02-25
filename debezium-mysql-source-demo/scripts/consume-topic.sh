#!/usr/bin/env bash
set -euo pipefail

KAFKA_CONTAINER="${KAFKA_CONTAINER:-}"
TOPIC="${TOPIC:-mysqlsrc.inventory.customers_live}"
MAX_MESSAGES="${MAX_MESSAGES:-20}"
TIMEOUT_MS="${TIMEOUT_MS:-20000}"

if [[ -z "$KAFKA_CONTAINER" ]]; then
  KAFKA_CONTAINER="$(docker ps --format '{{.Names}}' | grep -E '(^|[-_])kafka[-_]1$' | head -n1 || true)"
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
  echo "[ERR] Container Kafka non in esecuzione o non rilevato"
  echo "      Imposta KAFKA_CONTAINER=<nome_container> se necessario"
  exit 1
fi

echo "[INFO] Consumo da topic: $TOPIC"
docker exec "$KAFKA_CONTAINER" bash -lc \
  "kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic '$TOPIC' --from-beginning --max-messages '$MAX_MESSAGES' --timeout-ms '$TIMEOUT_MS'"
