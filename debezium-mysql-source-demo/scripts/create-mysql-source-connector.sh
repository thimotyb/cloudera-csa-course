#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:28083}"
CONNECTOR_NAME="${CONNECTOR_NAME:-mysql-source-demo}"
MYSQL_HOST="${MYSQL_HOST:-mysql-source}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-debezium}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-dbz}"
MYSQL_SERVER_ID="${MYSQL_SERVER_ID:-184054}"
TOPIC_PREFIX="${TOPIC_PREFIX:-mysqlsrc}"
DB_INCLUDE="${DB_INCLUDE:-inventory}"
TABLE_INCLUDE="${TABLE_INCLUDE:-inventory.customers_live}"
HISTORY_TOPIC="${HISTORY_TOPIC:-schemahistory.mysqlsrc}"

if ! curl -sf "$CONNECT_URL/connector-plugins" >/tmp/connector_plugins.json; then
  echo "[ERR] Kafka Connect non raggiungibile su $CONNECT_URL"
  exit 1
fi

if ! grep -q 'io.debezium.connector.mysql.MySqlConnector' /tmp/connector_plugins.json; then
  echo "[ERR] Plugin Debezium MySQL non trovato in Kafka Connect"
  exit 1
fi

read -r -d '' CONNECTOR_CONFIG <<JSON || true
{
  "connector.class": "io.debezium.connector.mysql.MySqlConnector",
  "tasks.max": "1",
  "database.hostname": "$MYSQL_HOST",
  "database.port": "$MYSQL_PORT",
  "database.user": "$MYSQL_USER",
  "database.password": "$MYSQL_PASSWORD",
  "database.server.id": "$MYSQL_SERVER_ID",
  "database.server.name": "$TOPIC_PREFIX",
  "database.include.list": "$DB_INCLUDE",
  "table.include.list": "$TABLE_INCLUDE",
  "database.history.kafka.bootstrap.servers": "kafka:9092",
  "database.history.kafka.topic": "$HISTORY_TOPIC",
  "include.schema.changes": "false",
  "snapshot.mode": "initial",
  "key.converter": "org.apache.kafka.connect.json.JsonConverter",
  "value.converter": "org.apache.kafka.connect.json.JsonConverter",
  "key.converter.schemas.enable": "false",
  "value.converter.schemas.enable": "false"
}
JSON

if curl -sf "$CONNECT_URL/connectors/$CONNECTOR_NAME" >/dev/null; then
  echo "[INFO] Connector $CONNECTOR_NAME esiste, aggiorno configurazione"
  status=$(curl -sS -o /tmp/connector_response.json -w "%{http_code}" \
    -X PUT "$CONNECT_URL/connectors/$CONNECTOR_NAME/config" \
    -H 'Content-Type: application/json' \
    -d "$CONNECTOR_CONFIG")
else
  echo "[INFO] Creo connector $CONNECTOR_NAME"
  read -r -d '' CREATE_PAYLOAD <<JSON || true
{
  "name": "$CONNECTOR_NAME",
  "config": $CONNECTOR_CONFIG
}
JSON
  status=$(curl -sS -o /tmp/connector_response.json -w "%{http_code}" \
    -X POST "$CONNECT_URL/connectors" \
    -H 'Content-Type: application/json' \
    -d "$CREATE_PAYLOAD")
fi

if [[ "$status" != "200" && "$status" != "201" ]]; then
  echo "[ERR] Errore creazione/aggiornamento connector (HTTP $status)"
  cat /tmp/connector_response.json
  exit 1
fi

echo "[OK] Connector $CONNECTOR_NAME attivo"
echo "[INFO] Topic CDC atteso: $TOPIC_PREFIX.inventory.customers_live"
