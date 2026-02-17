#!/usr/bin/env bash
set -euo pipefail

CONNECT_CONTAINER="${CONNECT_CONTAINER:-cloudera-kafka-connect-1}"
DRIVER_TARGET="${DRIVER_TARGET:-/opt/connect/plugin/libs/debezium-connector-mysql/mysql-connector-java.jar}"
MYSQL_JDBC_VERSION="${MYSQL_JDBC_VERSION:-8.0.27}"
TMP_FILE="/tmp/mysql-connector-java-${MYSQL_JDBC_VERSION}.jar"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONNECT_CONTAINER}$"; then
  echo "[ERR] Container Kafka Connect non in esecuzione: $CONNECT_CONTAINER"
  exit 1
fi

if docker exec "$CONNECT_CONTAINER" bash -lc "test -f '$DRIVER_TARGET'"; then
  echo "[OK] Driver MySQL già presente: $DRIVER_TARGET"
  if [[ "${RESTART_CONNECT_WHEN_PRESENT:-true}" != "true" ]]; then
    exit 0
  fi
  echo "[INFO] Riavvio Kafka Connect per sicurezza"
  docker restart "$CONNECT_CONTAINER" >/dev/null
  for i in $(seq 1 60); do
    if curl -sf "http://localhost:28083/connectors" >/dev/null; then
      echo "[OK] Kafka Connect tornato disponibile"
      exit 0
    fi
    sleep 2
    if [[ "$i" == "60" ]]; then
      echo "[ERR] Timeout attesa Kafka Connect dopo restart"
      exit 1
    fi
  done
fi

echo "[INFO] Scarico mysql-connector-java:${MYSQL_JDBC_VERSION}"
if ! curl -fsSL "https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_JDBC_VERSION}/mysql-connector-java-${MYSQL_JDBC_VERSION}.jar" -o "$TMP_FILE"; then
  echo "[ERR] Download driver fallito"
  exit 1
fi

echo "[INFO] Copio driver nel container $CONNECT_CONTAINER"
docker cp "$TMP_FILE" "$CONNECT_CONTAINER:/tmp/mysql-connector-java.jar"
docker exec --user root "$CONNECT_CONTAINER" bash -lc "cp /tmp/mysql-connector-java.jar '$DRIVER_TARGET' && chown 3000:1000 '$DRIVER_TARGET'"
docker exec --user root "$CONNECT_CONTAINER" bash -lc "rm -f /tmp/mysql-connector-java.jar"
rm -f "$TMP_FILE"

echo "[INFO] Riavvio Kafka Connect per ricaricare i plugin"
docker restart "$CONNECT_CONTAINER" >/dev/null

for i in $(seq 1 60); do
  if curl -sf "http://localhost:28083/connectors" >/dev/null; then
    echo "[OK] Kafka Connect tornato disponibile"
    exit 0
  fi
  sleep 2
  if [[ "$i" == "60" ]]; then
    echo "[ERR] Timeout attesa Kafka Connect dopo restart"
    exit 1
  fi
done
