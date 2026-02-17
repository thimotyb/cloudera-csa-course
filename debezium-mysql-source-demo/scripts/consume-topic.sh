#!/usr/bin/env bash
set -euo pipefail

KAFKA_CONTAINER="${KAFKA_CONTAINER:-cloudera-kafka-1}"
TOPIC="${TOPIC:-mysqlsrc.inventory.customers_live}"
MAX_MESSAGES="${MAX_MESSAGES:-20}"
TIMEOUT_MS="${TIMEOUT_MS:-20000}"

if ! docker ps --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER}$"; then
  echo "[ERR] Container Kafka ${KAFKA_CONTAINER} non in esecuzione"
  exit 1
fi

echo "[INFO] Consumo da topic: $TOPIC"
docker exec "$KAFKA_CONTAINER" bash -lc \
  "kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic '$TOPIC' --from-beginning --max-messages '$MAX_MESSAGES' --timeout-ms '$TIMEOUT_MS'"
